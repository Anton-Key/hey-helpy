import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/voice/voice_draft.dart';
import 'package:hey_helpy/features/voice/voice_intake_client.dart';

final _catalog = IntakeCatalog(
  layers: const [
    Layer(id: 'hvac', name: 'Климат', names: {'ru': 'Климат', 'en': 'HVAC'}),
    Layer(id: 'lift', name: 'Лифты'),
  ],
  places: [
    Place(
        id: 'meet',
        objectId: 'bc',
        name: 'Переговорная, 3 этаж',
        objectName: 'БЦ'),
  ],
  objects: [Obj(id: 'bc', name: 'БЦ', type: 'office')],
);

const _text = 'Эй, Хелпи, в переговорной опять ад, жара, невозможно работать';

Future<VoiceDraft> _run(IntakeCall call,
        {Duration timeout = const Duration(seconds: 10)}) =>
    ServerVoiceIntake(call: call, timeout: timeout)
        .process(_text, locale: 'ru', catalog: _catalog);

void main() {
  test('ответ ИИ — поля ИИ, пометка «ИИ»; запрос с языком и объектом',
      () async {
    Map<String, dynamic>? sent;
    final d = await _run((body) async {
      sent = body;
      return {
        'source': 'ai',
        'title': 'Жарко в переговорной',
        'description': 'В переговорной очень жарко, невозможно работать.',
        'layer_id': 'hvac',
        'layer': 'Климат',
        'location_id': 'meet',
        'location_hint': 'переговорная',
        'priority': 'high',
        'confidence': 0.9,
        'transcript': _text,
      };
    });
    expect(sent, {'text': _text, 'locale': 'ru', 'objectId': 'bc'});
    expect(d.source, DraftSource.ai);
    expect(d.title, 'Жарко в переговорной');
    expect(d.layerId, 'hvac');
    expect(d.locationId, 'meet');
    expect(d.objectId, 'bc');
    expect(d.priority, 'high');
    expect(d.transcript, _text);
  });

  test('ИИ не нашёл слой и место — подставляются из словаря', () async {
    final d = await _run((_) async => {
          'source': 'ai',
          'title': 'Жарко в переговорной',
          'layer_id': null,
          'location_id': null,
          'priority': null,
        });
    expect(d.source, DraftSource.ai);
    expect(d.title, 'Жарко в переговорной');
    expect(d.layerId, 'hvac'); // «жара» — Климат по словарю
    expect(d.locationId, 'meet');
    expect(d.priority, 'normal');
  });

  test('ошибка функции — молча словарь', () async {
    final d = await _run((_) async => throw Exception('502 ai_unavailable'));
    expect(d.source, DraftSource.dictionary);
    expect(d.layerId, 'hvac');
    expect(d.title, isNotEmpty);
  });

  test('ответ не от ИИ (not_configured, пусто) — словарь', () async {
    expect((await _run((_) async => {'error': 'not_configured'})).source,
        DraftSource.dictionary);
    expect((await _run((_) async => null)).source, DraftSource.dictionary);
  });

  test('таймаут — словарь', () async {
    final d = await _run((_) => Completer<Object?>().future,
        timeout: const Duration(milliseconds: 50));
    expect(d.source, DraftSource.dictionary);
  });
}
