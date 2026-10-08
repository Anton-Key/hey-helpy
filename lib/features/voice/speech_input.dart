import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Режим без микрофона — для скриншотов (/screens, в Playwright микрофона нет)
/// и показа без звука: `--dart-define=VOICE_MOCK=true`.
const voiceMock = bool.fromEnvironment('VOICE_MOCK');

/// Почему не получилось распознать речь.
enum SpeechProblem {
  /// Браузер или телефон не умеет распознавать речь (Firefox, нет сервиса).
  unsupported,

  /// Нет доступа к микрофону.
  noPermission,

  /// Нет связи с сервисом распознавания (Web Speech работает через интернет).
  network,

  /// Микрофон не включился.
  micFailed,

  /// Ничего не услышали.
  nothingHeard,

  /// Прочая ошибка.
  failed,
}

/// Распознавание речи в текст. Слушает до паузы, до лимита времени или до
/// [stop]; распознанный текст приходит по ходу речи.
abstract class SpeechInput {
  /// Готовит распознаватель. null — можно слушать, иначе — причина отказа.
  Future<SpeechProblem?> init();

  /// [localeId] — язык речи (ru-RU, en-US). [onText] — весь распознанный
  /// текст на сейчас (промежуточный), [onDone] — распознаватель остановился
  /// (пауза, лимит или [stop]), [onError] — ошибка, [onLevel] — громкость 0…1.
  Future<void> start({
    required String localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(String text) onText,
    required void Function() onDone,
    required void Function(SpeechProblem problem) onError,
    void Function(double level)? onLevel,
  });

  /// Остановить и дождаться последнего результата (придёт [onDone]).
  Future<void> stop();

  /// Остановить без результата.
  Future<void> cancel();
}

SpeechInput createSpeechInput() =>
    voiceMock ? MockVoiceIntake() : DeviceSpeechInput();

/// Язык распознавания по языку интерфейса.
String speechLocaleId(String localeCode) =>
    localeCode == 'ru' ? 'ru-RU' : 'en-US';

/// Распознавание средствами платформы через пакет speech_to_text:
/// Web Speech API в браузере, системный распознаватель на Android.
/// Ключей и своего сервера не нужно.
class DeviceSpeechInput implements SpeechInput {
  final SpeechToText _stt = SpeechToText();
  void Function(String)? _onText;
  void Function()? _onDone;
  void Function(SpeechProblem)? _onError;
  bool _active = false;

  @override
  Future<SpeechProblem?> init() async {
    bool ok;
    try {
      // Bluetooth-гарнитуры не используем — лишних разрешений не просим.
      ok = await _stt.initialize(
          onError: _handleError,
          onStatus: _handleStatus,
          options: [SpeechToText.androidNoBluetooth]);
    } catch (_) {
      ok = false;
    }
    // SpeechToText — один на приложение и запоминает слушателей только при
    // первом initialize: подключаем их к этому экрану заново.
    _stt.errorListener = _handleError;
    _stt.statusListener = _handleStatus;
    if (ok) return null;
    // На Android initialize сам спрашивает доступ к микрофону.
    if (!kIsWeb) {
      try {
        if (!await _stt.hasPermission) return SpeechProblem.noPermission;
      } catch (_) {}
    }
    return SpeechProblem.unsupported;
  }

  @override
  Future<void> start({
    required String localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(String text) onText,
    required void Function() onDone,
    required void Function(SpeechProblem problem) onError,
    void Function(double level)? onLevel,
  }) async {
    _onText = onText;
    _onDone = onDone;
    _onError = onError;
    _active = true;
    try {
      await _stt.listen(
        onResult: (r) {
          if (_active) _onText?.call(r.recognizedWords);
        },
        // Android сообщает громкость примерно от −2 до 10 дБ; браузер — нет.
        onSoundLevelChange: onLevel == null
            ? null
            : (db) => onLevel(((db + 2) / 12).clamp(0.0, 1.0)),
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {
      _active = false;
      onError(SpeechProblem.micFailed);
    }
  }

  void _handleStatus(String status) {
    if (_active && status == SpeechToText.doneStatus) {
      _active = false;
      _onDone?.call();
    }
  }

  void _handleError(SpeechRecognitionError e) {
    if (!_active) return;
    final problem = problemOf(e.errorMsg);
    if (problem == null) return;
    _active = false;
    _onError?.call(problem);
  }

  /// Код ошибки браузера (Web Speech) или Android → понятная причина.
  /// null — ошибку можно не показывать (сами остановили).
  @visibleForTesting
  static SpeechProblem? problemOf(String code) => switch (code) {
        'aborted' => null,
        'not-allowed' ||
        'service-not-allowed' ||
        'error_permission' ||
        'error_insufficient_permissions' =>
          SpeechProblem.noPermission,
        'network' ||
        'error_network' ||
        'error_network_timeout' ||
        'error_server' ||
        'error_server_disconnected' =>
          SpeechProblem.network,
        'audio-capture' || 'error_audio_error' => SpeechProblem.micFailed,
        'no-speech' ||
        'error_no_match' ||
        'error_speech_timeout' =>
          SpeechProblem.nothingHeard,
        'not supported' ||
        'speech_not_supported' ||
        'language-not-supported' ||
        'error_language_not_supported' ||
        'error_language_unavailable' =>
          SpeechProblem.unsupported,
        _ => SpeechProblem.failed,
      };

  @override
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    _active = false;
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}

/// Имитация распознавания без микрофона (флаг [voiceMock]): «произносит»
/// заготовленную фразу по словам и ждёт «Готово». Фразы — пример того, что
/// мог сказать пользователь, а не строки интерфейса, поэтому они не в
/// файлах перевода. Разбор дальше — настоящий ([TextIntake]).
class MockVoiceIntake implements SpeechInput {
  static const phrases = {
    'ru':
        'Эй, Хелпи, в переговорной на третьем этаже не работает кондиционер, очень жарко',
    'en':
        "Hey Helpy, the air conditioner in the meeting room on the third floor isn't working, it's really hot",
  };

  Timer? _timer;
  void Function()? _onDone;

  @override
  Future<SpeechProblem?> init() async => null;

  @override
  Future<void> start({
    required String localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required void Function(String text) onText,
    required void Function() onDone,
    required void Function(SpeechProblem problem) onError,
    void Function(double level)? onLevel,
  }) async {
    _onDone = onDone;
    final words = phrases[localeId.substring(0, 2)]!.split(' ');
    var shown = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      shown++;
      onText(words.take(shown).join(' '));
      onLevel?.call(shown.isEven ? 0.7 : 0.3);
      if (shown >= words.length) {
        t.cancel();
        onLevel?.call(0);
      }
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _onDone?.call();
    _onDone = null;
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _onDone = null;
  }
}
