import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/voice/speech_input.dart';
import 'package:hey_helpy/features/voice/speech_session.dart';

Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

SpeechChunk fin(String t) => SpeechChunk(t, isFinal: true);
SpeechChunk mid(String t) => SpeechChunk(t, isFinal: false);

void main() {
  group('склейка текста', () {
    test('окончательные куски + текущий промежуточный', () {
      final sn = SpeechSession();
      expect(sn.onResults(s(1), [mid('в переговорной')]), 'в переговорной');
      expect(
          sn.onResults(
              s(2), [fin('в переговорной'), mid('не работает кондиционер')]),
          'в переговорной не работает кондиционер');
    });

    test('после перезапуска браузера текст прошлой сессии сохраняется', () {
      final sn = SpeechSession();
      sn.onResults(s(1), [fin('в переговорной')]);
      expect(sn.onEnd(s(1.5)), SpeechStep.restart);
      expect(sn.onResults(s(2), [mid('жарко')]), 'в переговорной жарко');
    });

    test('Chrome на Android: накопительные куски не дублируются', () {
      expect(joinSpeech(['включи', 'включи свет', 'на кухне']),
          'включи свет на кухне');
      expect(joinSpeech(['не', 'нет света']), 'не нет света',
          reason: 'совпадение — только по целым словам');
      expect(joinSpeech([' ', 'Свет', 'свет']), 'свет');
    });
  });

  group('таймеры', () {
    test('речи нет 8 с — «ничего не услышал»', () {
      final sn = SpeechSession();
      expect(sn.tick(s(7.9)), isFalse);
      expect(sn.tick(s(8)), isTrue);
      expect(sn.outcome!.ok, isFalse);
      expect(sn.outcome!.errorCode, noSpeechTimeout);
      expect(DeviceSpeechInput.problemOf(noSpeechTimeout),
          SpeechProblem.nothingHeard);
    });

    test('3 с тишины после последнего результата — конец', () {
      final sn = SpeechSession();
      sn.onResults(s(5), [mid('свет')]);
      expect(sn.tick(s(7.9)), isFalse);
      sn.onResults(s(7), [mid('свет мигает')]);
      expect(sn.tick(s(9.9)), isFalse);
      expect(sn.tick(s(10)), isTrue);
      expect(sn.outcome!.ok, isTrue);
      expect(sn.outcome!.text, 'свет мигает');
    });

    test('повтор того же текста не продлевает ожидание', () {
      final sn = SpeechSession();
      sn.onResults(s(1), [mid('свет')]);
      sn.onResults(s(3), [mid('свет')]);
      expect(sn.tick(s(4)), isTrue);
    });

    test('общий лимит 30 с, даже если человек говорит', () {
      final sn = SpeechSession();
      for (var t = 1; t < 30; t++) {
        sn.onResults(s(t), [mid('слово ' * t)]);
        expect(sn.tick(s(t + 0.5)), isFalse);
      }
      expect(sn.tick(s(30)), isTrue);
      expect(sn.outcome!.ok, isTrue);
    });
  });

  group('перезапуск и ошибки', () {
    test('браузер закончил сам — тихий перезапуск, не больше 3 раз подряд', () {
      final sn = SpeechSession();
      expect(sn.onEnd(s(0.5)), SpeechStep.restart);
      expect(sn.onEnd(s(1)), SpeechStep.restart);
      expect(sn.onEnd(s(1.5)), SpeechStep.restart);
      expect(sn.onEnd(s(2)), SpeechStep.finish);
      expect(sn.outcome!.ok, isFalse);
    });

    test('результат сбрасывает счётчик перезапусков', () {
      final sn = SpeechSession();
      sn.onEnd(s(0.5));
      sn.onEnd(s(1));
      sn.onEnd(s(1.5));
      sn.onResults(s(2), [fin('кран течёт')]);
      expect(sn.onEnd(s(2.2)), SpeechStep.restart);
    });

    test('no-speech от браузера — мягкая: перезапуск, код запомнен', () {
      final sn = SpeechSession();
      expect(sn.onError('no-speech'), isFalse);
      expect(sn.onEnd(s(5)), SpeechStep.restart);
      expect(sn.tick(s(8)), isTrue);
      expect(sn.outcome!.errorCode, 'no-speech');
    });

    test('ошибка приходит до onend — причина не теряется', () {
      for (final code in ['network', 'not-allowed', 'audio-capture']) {
        final sn = SpeechSession();
        expect(sn.onError(code), isTrue, reason: code);
        expect(sn.onEnd(s(1)), SpeechStep.finish);
        expect(sn.outcome!.errorCode, code);
      }
    });

    test('сеть пропала посреди речи — оставляем сказанное', () {
      final sn = SpeechSession();
      sn.onResults(s(1), [fin('нет воды')]);
      expect(sn.onError('network'), isTrue);
      expect(sn.outcome!.ok, isTrue);
      expect(sn.outcome!.text, 'нет воды');
    });

    test('«Готово»: ждём onend, aborted от нас — не ошибка', () {
      final sn = SpeechSession();
      sn.onResults(s(2), [mid('дверь')]);
      sn.requestStop();
      expect(sn.onError('aborted'), isFalse);
      sn.onResults(s(2.3), [fin('дверь заела')]);
      expect(sn.onEnd(s(2.4)), SpeechStep.finish);
      expect(sn.outcome!.text, 'дверь заела');
    });

    test('после итога события игнорируются', () {
      final sn = SpeechSession();
      sn.onError('network');
      expect(sn.onError('no-speech'), isFalse);
      sn.onResults(s(1), [fin('поздно')]);
      expect(sn.outcome!.errorCode, 'network');
    });
  });

  group('Android: done раньше ошибки', () {
    test('ошибка в течение окна показывается вместо done', () async {
      final events = <String>[];
      final gate = DoneErrorGate<String>(
          onDone: () => events.add('done'), onError: events.add);
      gate.done();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      gate.error('error_network');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(events, ['error_network']);
    });

    test('без ошибки done приходит через ~300 мс', () async {
      final events = <String>[];
      final gate = DoneErrorGate<String>(
          onDone: () => events.add('done'), onError: events.add);
      gate.done();
      expect(events, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(events, ['done']);
      gate.error('late');
      expect(events, ['done'], reason: 'поздняя ошибка уже не важна');
    });

    test('после отмены ничего не приходит', () async {
      final events = <String>[];
      final gate = DoneErrorGate<String>(
          onDone: () => events.add('done'), onError: events.add);
      gate.done();
      gate.close();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(events, isEmpty);
    });
  });

  test('микрофон молчит 3 с — подсказка', () {
    final q = QuietMicDetector();
    expect(q.update(s(0), 0), isFalse);
    expect(q.update(s(2.9), 0.01), isFalse);
    expect(q.update(s(3), 0), isTrue);
    expect(q.update(s(3.1), 0.3), isFalse);
    expect(q.update(s(5), 0), isFalse);
    expect(q.update(s(6.1), 0), isTrue);
  });

  test('браузеры, где лучше открыть Chrome или Edge', () {
    const chrome =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';
    const edge = '$chrome Edg/129.0.0.0';
    expect(isWeakSpeechBrowser(chrome), isFalse);
    expect(isWeakSpeechBrowser(edge), isFalse);
    expect(isWeakSpeechBrowser('$chrome YaBrowser/24.7.0.0'), isTrue);
    expect(isWeakSpeechBrowser('$chrome OPR/113.0.0.0'), isTrue);
    expect(isWeakSpeechBrowser(chrome, brave: true), isTrue);
    expect(
        isWeakSpeechBrowser(
            'Mozilla/5.0 (Windows NT 10.0; rv:131.0) Gecko/20100101 Firefox/131.0'),
        isTrue);
    expect(
        isWeakSpeechBrowser(
            'Mozilla/5.0 (Linux; Android 14) SamsungBrowser/26.0 Chrome/122 Mobile Safari/537.36'),
        isTrue);
    expect(isMobileUserAgent(chrome), isFalse);
    expect(isMobileUserAgent('Mozilla/5.0 (Linux; Android 14) Mobile'), isTrue);
  });
}
