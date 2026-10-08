import 'dart:async';

/// Логика голосового ввода без браузера и без плагинов — чтобы её можно было
/// проверить юнит-тестами. Браузерная обёртка — `web_speech_input.dart`,
/// Android — [DoneErrorGate] в `speech_input.dart`.

/// Один результат распознавания: текст и окончательный ли он
/// (`isFinal` у Web Speech; промежуточный ещё может измениться).
class SpeechChunk {
  const SpeechChunk(this.text, {required this.isFinal});
  final String text;
  final bool isFinal;
}

/// Чем закончилось распознавание: текст или код ошибки браузера.
class SpeechOutcome {
  const SpeechOutcome.ok(this.text) : errorCode = null;
  const SpeechOutcome.error(this.errorCode, {this.text = ''});
  final String text;

  /// Код ошибки браузера (`network`, `not-allowed`, …); null — всё хорошо.
  final String? errorCode;
  bool get ok => errorCode == null;
}

/// Что делать, когда браузер сам закончил сессию распознавания (`onend`).
enum SpeechStep { restart, finish }

/// Наш код «не дождались речи» (браузер такой ошибки не присылал).
const noSpeechTimeout = 'no-speech-timeout';

/// Сессия голосового ввода в браузере: свои таймеры вместо браузерных,
/// склейка текста, тихий перезапуск и порядок «ошибка → конец».
///
/// Время передаётся снаружи ([Duration] от начала), поэтому логика не
/// зависит от часов и проверяется тестами.
class SpeechSession {
  SpeechSession({
    this.waitForSpeech = const Duration(seconds: 8),
    this.silence = const Duration(seconds: 3),
    this.limit = const Duration(seconds: 30),
    this.maxRestarts = 3,
  });

  /// Сколько ждать, пока человек начнёт говорить.
  final Duration waitForSpeech;

  /// Тишина после последнего результата — конец речи.
  final Duration silence;

  /// Общий лимит.
  final Duration limit;

  /// Сколько раз подряд перезапускать браузер без новых результатов.
  final int maxRestarts;

  /// Текст прошлых сессий браузера (до перезапусков).
  final List<String> _committed = [];

  /// Текст текущей сессии браузера: окончательные куски + промежуточный.
  String _current = '';
  Duration? _lastResult;
  String? _error;
  int _restartsInRow = 0;
  bool _stopping = false;
  SpeechOutcome? _outcome;

  /// Весь распознанный текст на сейчас.
  String get text => joinSpeech([..._committed, _current]);

  /// Последний код ошибки браузера (в том числе «мягкой», вроде `no-speech`).
  String? get errorCode => _error;

  /// Итог; null — ещё слушаем.
  SpeechOutcome? get outcome => _outcome;
  bool get finished => _outcome != null;

  /// Человек нажал «Готово»: дожидаемся последнего результата и `onend`.
  void requestStop() => _stopping = true;
  bool get stopping => _stopping;

  /// Пришли результаты текущей сессии браузера (`event.results` целиком).
  /// Возвращает весь текст.
  String onResults(Duration now, List<SpeechChunk> results) {
    if (finished) return text;
    final next = joinSpeech([for (final r in results) r.text]);
    if (next.isNotEmpty && next != _current) {
      _lastResult = now;
      _restartsInRow = 0;
    }
    _current = next;
    return text;
  }

  /// Ошибка браузера (`onerror`). Код запоминается сразу — до `onend`, чтобы
  /// причина не потерялась. true — ошибка окончательная, слушать дальше нельзя.
  bool onError(String code) {
    if (finished) return false;
    // abort() вызвали мы сами — это не ошибка.
    if (code == 'aborted' && _stopping) return false;
    _error = code;
    if (isSoftSpeechError(code)) return false;
    // Связь пропала посреди речи — оставляем то, что успели распознать.
    final said = text;
    _outcome =
        said.isEmpty ? SpeechOutcome.error(code) : SpeechOutcome.ok(said);
    return true;
  }

  /// Не получилось запустить или перезапустить распознавание.
  void fail(String code) {
    if (finished) return;
    _error = code;
    final said = text;
    _outcome =
        said.isEmpty ? SpeechOutcome.error(code) : SpeechOutcome.ok(said);
  }

  /// Браузер закончил сессию (`onend`): перезапустить или закончить.
  SpeechStep onEnd(Duration now) {
    if (finished) return SpeechStep.finish;
    // Промежуточный текст закончившейся сессии больше не изменится.
    if (_current.isNotEmpty) _committed.add(_current);
    _current = '';
    if (_stopping || tick(now)) return _finishQuiet();
    if (_restartsInRow >= maxRestarts) return _finishQuiet();
    _restartsInRow++;
    return SpeechStep.restart;
  }

  /// Проверка таймеров — вызывать часто (раз в 100–250 мс).
  /// true — пора заканчивать (итог в [outcome]).
  bool tick(Duration now) {
    if (finished) return true;
    final last = _lastResult;
    final over = now >= limit ||
        (last == null && now >= waitForSpeech) ||
        (last != null && now - last >= silence);
    if (over) _finishQuiet();
    return over;
  }

  SpeechStep _finishQuiet() {
    final said = text;
    _outcome = said.isNotEmpty
        ? SpeechOutcome.ok(said)
        : SpeechOutcome.error(_error ?? noSpeechTimeout);
    return SpeechStep.finish;
  }
}

/// Ошибки, после которых можно тихо перезапустить распознавание:
/// браузер не услышал речь или сам прервал сессию.
bool isSoftSpeechError(String code) => code == 'no-speech' || code == 'aborted';

/// Склейка кусков текста через пробел. Chrome на Android в непрерывном
/// режиме иногда присылает каждый следующий кусок вместе с предыдущим
/// («включи» → «включи свет») — такой кусок заменяет предыдущий, а не
/// дописывается.
String joinSpeech(Iterable<String> parts) {
  final out = <String>[];
  for (final raw in parts) {
    final p = raw.trim();
    if (p.isEmpty) continue;
    if (out.isNotEmpty) {
      final prev = out.last.toLowerCase();
      final cur = p.toLowerCase();
      if (cur == prev || cur.startsWith('$prev ')) {
        out[out.length - 1] = p;
        continue;
      }
      if (prev.startsWith('$cur ')) continue;
    }
    out.add(p);
  }
  return out.join(' ');
}

/// «Микрофон молчит»: громкость всё время около нуля [quietFor] —
/// скорее всего, выбран не тот микрофон.
class QuietMicDetector {
  QuietMicDetector(
      {this.quietFor = const Duration(seconds: 3), this.threshold = 0.02});
  final Duration quietFor;
  final double threshold;
  Duration? _since;

  /// [level] — громкость 0…1. true — микрофон молчит.
  bool update(Duration now, double level) {
    if (level > threshold || _since == null) _since = now;
    return now - _since! >= quietFor && level <= threshold;
  }
}

/// Браузер, где голосовой ввод обычно не работает или работает плохо:
/// Яндекс Браузер, Opera, Brave, Firefox, Samsung Internet. Попытку не
/// запрещаем — только советуем Chrome или Edge.
bool isWeakSpeechBrowser(String userAgent, {bool brave = false}) {
  if (brave) return true;
  return RegExp(r'YaBrowser|OPR/|Opera|Firefox/|FxiOS|SamsungBrowser')
      .hasMatch(userAgent);
}

/// Телефон или планшет. На них браузер отдаёт микрофон только одному
/// потребителю, поэтому индикатор громкости там не включаем.
bool isMobileUserAgent(String userAgent) =>
    RegExp(r'Android|iPhone|iPad|iPod|Mobile').hasMatch(userAgent);

/// Android (speech_to_text): статус «done» иногда приходит раньше ошибки.
/// «done» ждёт [window]; если за это время пришла ошибка — показываем её,
/// а не «Ничего не услышал».
class DoneErrorGate<E> {
  DoneErrorGate(
      {required this.onDone,
      required this.onError,
      this.window = const Duration(milliseconds: 300)});
  final void Function() onDone;
  final void Function(E error) onError;
  final Duration window;
  Timer? _pending;
  bool _closed = false;

  bool get closed => _closed;

  void done() {
    if (_closed || _pending != null) return;
    _pending = Timer(window, () {
      if (_closed) return;
      _closed = true;
      onDone();
    });
  }

  void error(E e) {
    if (_closed) return;
    _pending?.cancel();
    _closed = true;
    onError(e);
  }

  /// Больше ничего не сообщать (отмена).
  void close() {
    _pending?.cancel();
    _closed = true;
  }
}
