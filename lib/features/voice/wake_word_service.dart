import 'dart:async';

/// Источник сигнала «пора слушать заявку».
///
/// Реализации:
/// - [PushToTalkWakeWord] — большая кнопка «Нажми и говори» (работает всегда,
///   на ней держится демо);
/// - PorcupineWakeWord — фраза «Эй, Хелпи» на устройстве (шаг 4, позже).
abstract class WakeWordService {
  /// Срабатывает, когда пользователь позвал Hey Helpy.
  Stream<void> get detections;

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// Запасной вариант без распознавания фразы: сигнал даёт кнопка.
class PushToTalkWakeWord implements WakeWordService {
  final _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get detections => _controller.stream;

  /// Вызывается по нажатию кнопки.
  void trigger() {
    if (!_controller.isClosed) _controller.add(null);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _controller.close();
}
