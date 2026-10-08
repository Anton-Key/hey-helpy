import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'speech_input.dart';
import 'speech_session.dart';

SpeechInput createWebSpeechInput() => WebSpeechInput();

/// Распознавание речи в браузере напрямую через Web Speech API
/// (`SpeechRecognition` / `webkitSpeechRecognition`), без сторонних JS.
///
/// Браузер в непрерывном режиме всё равно сам заканчивает сессию на паузах,
/// поэтому таймеры свои ([SpeechSession]): до 8 с ждём начала речи, 3 с
/// тишины после последнего результата — конец, 30 с — общий лимит. Если
/// браузер закончил раньше — тихо перезапускаем. Код ошибки запоминается
/// в `onerror`, до `onend`, и показывается на экране.
///
/// На компьютере параллельно открывается поток микрофона
/// (`getUserMedia` + `AnalyserNode`) — для индикатора громкости и подсказки
/// «микрофон не слышит звук».
class WebSpeechInput implements SpeechInput {
  static const _tickEvery = Duration(milliseconds: 100);

  web.SpeechRecognition? _rec;
  SpeechSession? _session;
  final _clock = Stopwatch();
  Timer? _tick;

  /// Номер запуска: события от прошлого запуска не обрабатываем.
  int _run = 0;

  void Function(String)? _onText;
  void Function()? _onDone;
  void Function(SpeechProblem, String)? _onError;
  void Function(double)? _onLevel;
  void Function(bool)? _onMicSilent;

  web.MediaStream? _stream;
  web.AudioContext? _audio;
  web.AnalyserNode? _analyser;
  JSUint8Array? _samples;
  QuietMicDetector? _quiet;
  bool _silent = false;

  static String get _userAgent => web.window.navigator.userAgent;

  static JSFunction? get _recognitionClass {
    for (final name in const ['SpeechRecognition', 'webkitSpeechRecognition']) {
      final c = globalContext[name];
      if (c != null && c.typeofEquals('function')) return c as JSFunction;
    }
    return null;
  }

  @override
  bool get weakBrowser {
    try {
      return isWeakSpeechBrowser(_userAgent,
          brave: web.window.navigator.has('brave'));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SpeechProblem?> init() async =>
      _recognitionClass == null ? SpeechProblem.unsupported : null;

  @override
  Future<void> start({
    required String localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(String text) onText,
    required void Function() onDone,
    required void Function(SpeechProblem problem, String code) onError,
    void Function(double level)? onLevel,
    void Function(bool silent)? onMicSilent,
  }) async {
    _cleanup();
    final run = ++_run;
    _onText = onText;
    _onDone = onDone;
    _onError = onError;
    _onLevel = onLevel;
    _onMicSilent = onMicSilent;
    final session =
        _session = SpeechSession(silence: pauseFor, limit: listenFor);

    // Сначала микрофон для индикатора: заодно браузер спросит разрешение,
    // и отказ виден сразу как not-allowed.
    if (onLevel != null && !isMobileUserAgent(_userAgent)) {
      final code = await _openMeter(run);
      if (run != _run) return;
      if (code != null) {
        session.fail(code);
        return _complete(run);
      }
    }

    final cls = _recognitionClass;
    if (cls == null) {
      session.fail('not supported');
      return _complete(run);
    }
    final rec = _rec = cls.callAsConstructor<web.SpeechRecognition>()
      ..lang = localeId
      ..continuous = true
      ..interimResults = true
      ..maxAlternatives = 1;
    rec.onresult = ((web.SpeechRecognitionEvent e) {
      if (run != _run) return;
      final list = e.results;
      final chunks = <SpeechChunk>[
        for (var i = 0; i < list.length; i++)
          if (list.item(i).length > 0)
            SpeechChunk(list.item(i).item(0).transcript,
                isFinal: list.item(i).isFinal),
      ];
      _onText?.call(session.onResults(_clock.elapsed, chunks));
    }).toJS;
    rec.onerror = ((web.SpeechRecognitionErrorEvent e) {
      if (run != _run) return;
      if (session.onError(e.error)) _complete(run);
    }).toJS;
    rec.onend = ((web.Event _) {
      if (run != _run) return;
      if (session.onEnd(_clock.elapsed) == SpeechStep.finish) {
        return _complete(run);
      }
      try {
        rec.start();
      } catch (_) {
        session.fail('start-failed');
        _complete(run);
      }
    }).toJS;

    _clock
      ..reset()
      ..start();
    try {
      rec.start();
    } catch (_) {
      session.fail('start-failed');
      return _complete(run);
    }
    _tick = Timer.periodic(_tickEvery, (_) => _onTick(run));
  }

  void _onTick(int run) {
    if (run != _run) return;
    final now = _clock.elapsed;
    if (_analyser != null) {
      final level = _readLevel();
      _onLevel?.call(level);
      final silent = _quiet!.update(now, level);
      if (silent != _silent) {
        _silent = silent;
        _onMicSilent?.call(silent);
      }
    }
    if (_session?.tick(now) ?? false) _complete(run);
  }

  /// Закончили: всё закрыть и сообщить экрану итог.
  void _complete(int run) {
    if (run != _run) return;
    final outcome = _session?.outcome;
    final onText = _onText, onDone = _onDone, onError = _onError;
    _run++;
    _cleanup();
    if (outcome == null || outcome.ok) {
      onText?.call(outcome?.text ?? '');
      onDone?.call();
    } else {
      final code = outcome.errorCode!;
      onError?.call(
          DeviceSpeechInput.problemOf(code) ?? SpeechProblem.nothingHeard,
          code);
    }
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null || session.finished) return;
    session.requestStop();
    final rec = _rec;
    if (rec == null) return _complete(_run);
    try {
      // Браузер пришлёт последние результаты и onend → _complete.
      rec.stop();
    } catch (_) {
      _complete(_run);
    }
  }

  @override
  Future<void> cancel() async {
    _run++;
    // Экран мог уже закрыться — ему больше ничего не сообщаем.
    _onText = _onDone = _onLevel = _onMicSilent = null;
    _onError = null;
    _cleanup();
  }

  void _cleanup() {
    _tick?.cancel();
    _tick = null;
    _clock.stop();
    final rec = _rec;
    _rec = null;
    if (rec != null) {
      rec
        ..onresult = null
        ..onerror = null
        ..onend = null;
      try {
        rec.abort();
      } catch (_) {}
    }
    _closeMeter();
  }

  /// Открыть микрофон для индикатора громкости. Возвращает код ошибки,
  /// если дальше слушать бессмысленно (нет доступа или нет микрофона);
  /// прочие сбои — просто без индикатора.
  Future<String?> _openMeter(int run) async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      if (run != _run) {
        // Пока браузер спрашивал разрешение, нажали «Готово» или ушли.
        for (final t in stream.getTracks().toDart) {
          t.stop();
        }
        return null;
      }
      _stream = stream;
      final audio = _audio = web.AudioContext();
      final analyser = audio.createAnalyser()..fftSize = 1024;
      audio.createMediaStreamSource(stream).connect(analyser);
      _analyser = analyser;
      _samples = Uint8List(analyser.fftSize).toJS;
      _quiet = QuietMicDetector();
      _silent = false;
      unawaited(audio.resume().toDart.catchError((_) => null));
      return null;
    } catch (e) {
      if (run == _run) _closeMeter();
      final name = e.toString();
      if (name.contains('NotAllowedError') || name.contains('SecurityError')) {
        return 'not-allowed';
      }
      if (name.contains('NotFoundError') || name.contains('NotReadableError')) {
        return 'audio-capture';
      }
      return null;
    }
  }

  /// Громкость 0…1: среднеквадратичное отклонение сигнала от тишины.
  double _readLevel() {
    final samples = _samples!;
    _analyser!.getByteTimeDomainData(samples);
    final data = samples.toDart;
    if (data.isEmpty) return 0;
    var sum = 0.0;
    for (final v in data) {
      final x = (v - 128) / 128;
      sum += x * x;
    }
    return (math.sqrt(sum / data.length) * 5).clamp(0.0, 1.0);
  }

  void _closeMeter() {
    final stream = _stream;
    if (stream != null) {
      for (final t in stream.getTracks().toDart) {
        t.stop();
      }
    }
    _stream = null;
    final audio = _audio;
    if (audio != null) {
      try {
        unawaited(audio.close().toDart.catchError((_) => null));
      } catch (_) {}
    }
    _audio = null;
    _analyser = null;
    _samples = null;
    _quiet = null;
    if (_silent) _onMicSilent?.call(false);
    _silent = false;
  }
}
