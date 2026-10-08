import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/voice/speech_input.dart';
import 'package:hey_helpy/features/voice/voice_intake_client.dart';

void main() {
  test('коды ошибок браузера и Android → понятная причина', () {
    expect(
        DeviceSpeechInput.problemOf('not-allowed'), SpeechProblem.noPermission);
    expect(DeviceSpeechInput.problemOf('service-not-allowed'),
        SpeechProblem.noPermission);
    expect(DeviceSpeechInput.problemOf('error_permission'),
        SpeechProblem.noPermission);
    expect(DeviceSpeechInput.problemOf('network'), SpeechProblem.network);
    expect(DeviceSpeechInput.problemOf('error_network'), SpeechProblem.network);
    expect(
        DeviceSpeechInput.problemOf('no-speech'), SpeechProblem.nothingHeard);
    expect(DeviceSpeechInput.problemOf('error_no_match'),
        SpeechProblem.nothingHeard);
    expect(
        DeviceSpeechInput.problemOf('audio-capture'), SpeechProblem.micFailed);
    expect(DeviceSpeechInput.problemOf('not supported'),
        SpeechProblem.unsupported);
    expect(DeviceSpeechInput.problemOf('aborted'), isNull);
    expect(DeviceSpeechInput.problemOf('что-то новое'), SpeechProblem.failed);
  });

  test('язык распознавания по языку интерфейса', () {
    expect(speechLocaleId('ru'), 'ru-RU');
    expect(speechLocaleId('en'), 'en-US');
  });

  test('мок «произносит» фразу, разбор — настоящий', () async {
    final mock = MockVoiceIntake();
    expect(await mock.init(), isNull);
    var text = '';
    var done = false;
    await mock.start(
      localeId: 'ru-RU',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onText: (t) => text = t,
      onDone: () => done = true,
      onError: (_, __) {},
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(text, MockVoiceIntake.phrases['ru']);
    expect(done, isFalse, reason: 'мок ждёт «Готово»');
    await mock.stop();
    expect(done, isTrue);

    final draft = await const LocalVoiceIntake()
        .process(text, locale: 'ru', catalog: const IntakeCatalog());
    expect(
        draft.title, 'В переговорной на третьем этаже не работает кондиционер');
    expect(draft.layer, 'Климат');
    expect(draft.priority, 'high');
  });
}
