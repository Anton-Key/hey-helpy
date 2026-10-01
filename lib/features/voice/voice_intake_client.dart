import 'dart:io';

import 'voice_draft.dart';

/// Превращает запись в черновик заявки: речь → текст → поля.
/// Заявку не создаёт.
abstract class VoiceIntakeClient {
  Future<VoiceDraft> process(File audio);
}

/// Текущая реализация. На шаге 2 здесь будет вызов Edge Function voice-intake.
VoiceIntakeClient createVoiceIntakeClient() => MockVoiceIntake();

/// Заглушка без сети: делает вид, что распознаёт, и возвращает
/// заготовленный ответ. Нужна, пока нет серверной функции и ключей Yandex.
class MockVoiceIntake implements VoiceIntakeClient {
  @override
  Future<VoiceDraft> process(File audio) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return const VoiceDraft(
      transcript: 'Эй, Хелпи, в переговорной на третьем этаже не работает кондиционер, очень жарко',
      title: 'Не работает кондиционер',
      description: 'В переговорной на третьем этаже не работает кондиционер, очень жарко.',
      layer: 'Климат',
      locationHint: 'переговорная, 3 этаж',
      priority: 'high',
    );
  }
}
