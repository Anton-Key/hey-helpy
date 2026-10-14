import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/camera/camera_logic.dart';
import 'package:hey_helpy/features/photo_identify/identify_client.dart';
import 'package:hey_helpy/features/photo_identify/identify_models.dart';

IdentifyCandidate _c(String id, String name) => IdentifyCandidate(
    assetId: id,
    name: name,
    locationId: 'l1',
    locationLabel: '301 Переговорная');

PhotoIdentification _r(List<IdentifyCandidate> c) =>
    PhotoIdentification(kind: 'ac', confidence: 0.95, candidates: c);

Map<String, dynamic> _o(String id,
        {String status = 'new',
        String? plan,
        String? end,
        String? created,
        String? accepted,
        String? asset = 'a1',
        String? contractor}) =>
    {
      'id': id,
      'title': 'Заявка $id',
      'status': status,
      'plan_id': plan,
      'period_end': end,
      'created_at': created ?? '2026-10-0${id.length}T10:00:00Z',
      'accepted_at': accepted,
      'asset_id': asset,
      'assigned_contractor_id': contractor,
    };

void main() {
  group('карточка поверх кадра', () {
    test('ждём ответ — «Смотрю…»', () {
      expect(cameraCard(busy: true).kind, CameraCardKind.looking);
    });

    test('0 кандидатов или ошибка — «Не узнал»', () {
      expect(cameraCard(busy: false, result: _r(const [])).kind,
          CameraCardKind.notRecognized);
      expect(
          cameraCard(
                  busy: false,
                  result: _r([_c('a1', 'КД-301')]),
                  problem: IdentifyProblem.failed)
              .kind,
          CameraCardKind.notRecognized);
      expect(cameraCard(busy: false).kind, CameraCardKind.notRecognized);
    });

    test('1 кандидат: «Не тот» сразу ведёт к выбору вручную', () {
      final r = _r([_c('a1', 'Кондиционер КД-301')]);
      final first = cameraCard(busy: false, result: r);
      expect(first.kind, CameraCardKind.recognized);
      expect(first.candidate!.assetId, 'a1');
      expect(first.hasNext, isFalse);
      expect(cameraCard(busy: false, result: r, index: 1).kind,
          CameraCardKind.manual);
    });

    test('3 кандидата: «Не тот» листает 2-го и 3-го, затем вручную', () {
      final r = _r([_c('a1', 'КД-301'), _c('a2', 'КД-302'), _c('a3', 'КД-1')]);
      final ids = [
        for (var i = 0; i < 3; i++)
          cameraCard(busy: false, result: r, index: i).candidate!.assetId
      ];
      expect(ids, ['a1', 'a2', 'a3']);
      expect(cameraCard(busy: false, result: r, index: 1).hasNext, isTrue);
      expect(cameraCard(busy: false, result: r, index: 2).hasNext, isFalse);
      expect(cameraCard(busy: false, result: r, index: 3).kind,
          CameraCardKind.manual);
    });

    test('подпись рамки «КД-301 · 95 %»', () {
      expect(frameLabel('Кондиционер КД-301', 95), 'КД-301 · 95 %');
      expect(frameLabel('Кондиционер КД-301', null), 'КД-301');
      expect(shortAssetLabel('Щит освещения'), 'Щит освещения');
      expect(shortAssetLabel('Очень длинное название оборудования без номера'),
          endsWith('…'));
    });
  });

  group('сводка по оборудованию', () {
    test('нет заявок и ТО — пусто', () {
      final f = buildAssetFacts(const []);
      expect(f.openOrders, isEmpty);
      expect(f.openCount, 0);
      expect(f.next, isNull);
      expect(f.lastDone, isNull);
    });

    test('открытые — без принятых, отменённых и задач ППР, не больше 3', () {
      final f = buildAssetFacts([
        _o('1', created: '2026-10-01T10:00:00Z'),
        _o('2', status: 'in_progress', created: '2026-10-05T10:00:00Z'),
        _o('3', status: 'done', accepted: '2026-10-06T10:00:00Z'),
        _o('4', status: 'cancelled'),
        _o('5', plan: 'p1', end: '2026-10-31'),
        _o('6', status: 'assigned', created: '2026-10-03T10:00:00Z'),
        _o('7', status: 'on_review', created: '2026-10-02T10:00:00Z'),
      ]);
      expect(f.openCount, 4);
      expect([for (final o in f.openOrders) o['id']], ['2', '6', '7']);
    });

    test('ТО: своё раньше системного, ближайший срок', () {
      final f = buildAssetFacts([
        _o('1', plan: 'p1', end: '2026-12-31'),
        _o('2', plan: 'p1', end: '2026-10-31'),
        _o('3', plan: 'p1', end: '2026-09-30', status: 'done'),
      ], systemPprRows: [
        _o('9', plan: 'p2', end: '2026-10-20', asset: null),
      ]);
      expect(f.next!.row['id'], '2');
      expect(f.next!.forAsset, isTrue);
      expect(f.next!.overdue(DateTime(2026, 10, 14)), isFalse);
      expect(f.next!.overdue(DateTime(2026, 11, 1)), isTrue);
    });

    test('нет своего ТО — системы на объекте', () {
      final f = buildAssetFacts(const [], systemPprRows: [
        _o('9', plan: 'p2', end: '2026-10-28', asset: null),
      ]);
      expect(f.next!.row['id'], '9');
      expect(f.next!.forAsset, isFalse);
    });

    test('последняя работа — принятая с самой поздней приёмкой', () {
      final f = buildAssetFacts([
        _o('1',
            status: 'done', accepted: '2026-09-01T10:00:00Z', contractor: 'c1'),
        _o('2',
            status: 'done', accepted: '2026-10-03T10:00:00Z', contractor: 'c2'),
        _o('3', status: 'on_review'),
      ]);
      expect(f.lastDone!.row['id'], '2');
      expect(f.lastDone!.contractorId, 'c2');
    });
  });

  group('автоскан', () {
    test('1,5 с покоя → один запрос; не чаще раза в 6 с; движение сбрасывает',
        () {
      final g = AutoScanGate();
      final t0 = DateTime(2026, 10, 14, 10);
      DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
      expect(g.onFrame(0.01, at(0)), isFalse);
      expect(g.onFrame(0.01, at(1000)), isFalse);
      expect(g.onFrame(0.01, at(1600)), isTrue);
      // Сразу снова неподвижно — но 6 с не прошло.
      expect(g.onFrame(0.01, at(2000)), isFalse);
      expect(g.onFrame(0.01, at(4000)), isFalse);
      // Движение сбрасывает отсчёт покоя.
      expect(g.onFrame(0.5, at(7000)), isFalse);
      expect(g.onFrame(0.01, at(7100)), isFalse);
      expect(g.onFrame(0.01, at(8700)), isTrue);
      expect(g.sent, 2);
    });

    test('не больше 20 за экран', () {
      final g = AutoScanGate();
      var t = DateTime(2026, 10, 14, 10);
      var sent = 0;
      for (var i = 0; i < 400; i++) {
        t = t.add(const Duration(milliseconds: 500));
        if (g.onFrame(0, t)) sent++;
      }
      expect(sent, 20);
      expect(g.exhausted, isTrue);
    });

    test('ручной «Что это?» тоже даёт паузу 6 с', () {
      final g = AutoScanGate();
      final t0 = DateTime(2026, 10, 14, 10);
      g.onManual(t0);
      g.onFrame(0, t0);
      expect(g.onFrame(0, t0.add(const Duration(seconds: 2))), isFalse);
      expect(g.onFrame(0, t0.add(const Duration(seconds: 6))), isTrue);
    });

    test('разница кадров', () {
      expect(frameDiff([0, 0], [0, 0]), 0);
      expect(frameDiff([0, 255], [255, 0]), 1);
      expect(frameDiff([1], [1, 2]), 1);
    });
  });
}
