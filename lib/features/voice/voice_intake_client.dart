import 'dart:io';

import 'voice_draft.dart';

/// Превращает запись в черновик заявки: речь → текст → поля.
/// Заявку не создаёт.
abstract class VoiceIntakeClient {
  /// [locale] — язык интерфейса (ru / en): на нём распознаётся речь
  /// и возвращаются поля заявки.
  Future<VoiceDraft> process(File audio, {required String locale});
}

/// Текущая реализация. На шаге 2 здесь будет вызов Edge Function voice-intake.
VoiceIntakeClient createVoiceIntakeClient() => MockVoiceIntake();

/// Заглушка без сети: делает вид, что распознаёт, и возвращает
/// заготовленный ответ на нужном языке. Нужна, пока нет серверной
/// функции и ключей Yandex. Тексты ниже — имитация ответа сервера,
/// а не строки интерфейса, поэтому они не в файлах перевода.
class MockVoiceIntake implements VoiceIntakeClient {
  static const _answers = {
    'ru': VoiceDraft(
      transcript: 'Эй, Хелпи, в переговорной на третьем этаже не работает кондиционер, очень жарко',
      title: 'Не работает кондиционер',
      description: 'В переговорной на третьем этаже не работает кондиционер, очень жарко.',
      layer: 'Климат',
      locationHint: 'переговорная, 3 этаж',
      priority: 'high',
    ),
    'en': VoiceDraft(
      transcript: "Hey, Helpy, the air conditioning in the third-floor meeting room isn't working, it's really hot",
      title: 'Air conditioning not working',
      description: "The air conditioning in the third-floor meeting room isn't working, it's really hot.",
      layer: 'HVAC',
      locationHint: 'meeting room, 3rd floor',
      priority: 'high',
    ),
  };

  @override
  Future<VoiceDraft> process(File audio, {required String locale}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return _answers[locale] ?? _answers['en']!;
  }
}
