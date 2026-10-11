import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/floors/floor_models.dart';
import 'package:hey_helpy/features/floors/plan_logic.dart';
import 'package:hey_helpy/features/map/map_logic.dart';
import 'package:hey_helpy/features/requests/work_order.dart';

Floor floor(String id, {int sort = 0, int? level, String? name}) => Floor(
    id: id,
    objectId: 'o',
    companyId: 'c',
    name: name ?? id,
    level: level,
    sort: sort);

PlanItem place(String id, {String? floor = 'f1', double? x, double? y}) =>
    PlanItem(
        kind: PlanKind.place, id: id, name: id, floorId: floor, x: x, y: y);

PlanItem asset(String id, {String? floor = 'f1', double? x, double? y}) =>
    PlanItem(
        kind: PlanKind.asset,
        id: id,
        name: id,
        floorId: floor,
        x: x,
        y: y,
        locationId: 'r1');

Uint8List bytes(List<int> b, {int pad = 0}) =>
    Uint8List.fromList([...b, ...List.filled(pad, 0)]);

void main() {
  group('Точка помещения при сохранении области (шаг 18)', () {
    final square = rectShape((0.5, 0.6), (0.7, 0.9));
    test('точка внутри области — не трогаем', () {
      expect(pointForShape(place('r', x: 0.6, y: 0.7), 'f1', square), isNull);
    });
    test('точка снаружи области — в центр области', () {
      final p = pointForShape(place('r', x: 0.5, y: 0.5), 'f1', square)!;
      expect(p.$1, closeTo(0.6, 1e-9));
      expect(p.$2, closeTo(0.75, 1e-9));
    });
    test('без точки или на другом этаже — в центр области', () {
      expect(pointForShape(place('r', floor: null), 'f1', square), isNotNull);
      expect(pointForShape(place('r', floor: 'f2', x: 0.6, y: 0.7), 'f1', square),
          isNotNull);
    });
  });

  group('Доли ↔ пиксели плана', () {
    const plan = Size(2400, 1600);

    test('туда и обратно', () {
      final p = fractionToPixels(0.25, 0.5, plan);
      expect(p, const Offset(600, 800));
      final (x, y) = pixelsToFraction(p, plan);
      expect((x, y), (0.25, 0.5));
    });

    test('за краем — к краю', () {
      expect(pixelsToFraction(const Offset(-50, 2000), plan), (0.0, 1.0));
    });

    test('этаж без картинки — сетка 2000×1400', () {
      expect(planSize(floor('f')), kDefaultPlanSize);
      const f = Floor(
          id: 'f',
          objectId: 'o',
          companyId: 'c',
          name: 'f',
          planPath: 'x.png',
          planW: 2400,
          planH: 1600);
      expect(planSize(f), plan);
    });

    test('вписать и центрировать', () {
      expect(planFitScale(const Size(448, 348), plan, margin: 24), 400 / 2400);
      final off =
          planCenterOn(const Offset(1200, 800), 0.5, const Size(400, 300));
      expect(off, const Offset(200 - 600, 150 - 400));
      expect(labelsVisible(0.2, 0.15), isFalse);
      expect(labelsVisible(0.3, 0.15), isTrue);
    });
  });

  group('Ближайшее помещение', () {
    test('по пикселям, только своего этажа и с точкой', () {
      final items = [
        place('a', x: 0.1, y: 0.1),
        place('b', x: 0.5, y: 0.5),
        place('other', floor: 'f2', x: 0.31, y: 0.31),
        place('nopoint'),
        asset('eq', x: 0.3, y: 0.3),
      ];
      expect(
          nearestPlace(items, 'f1', 0.3, 0.3, const Size(1000, 1000))!.id, 'a');
      // По долям ближе «b»; на широком плане по пикселям — «a».
      final wide = [place('a', x: 0.1, y: 0.5), place('b', x: 0.5, y: 0.9)];
      expect(
          nearestPlace(wide, 'f1', 0.25, 0.8, const Size(4000, 400))!.id, 'a');
      expect(
          nearestPlace(wide, 'f1', 0.25, 0.8, const Size(400, 4000))!.id, 'b');
      expect(nearestPlace(const [], 'f1', 0.5, 0.5, kDefaultPlanSize), isNull);
    });
  });

  group('Этажи', () {
    test('порядок и «Выше / Ниже»', () {
      final fs = [
        floor('3', sort: 2),
        floor('1', sort: 0),
        floor('2', sort: 1),
      ];
      expect(sortFloors(fs).map((f) => f.id), ['1', '2', '3']);
      expect(moveFloor(fs, '3', -1), {'3': 1, '2': 2});
      expect(moveFloor(fs, '1', -1), isEmpty, reason: 'выше некуда');
      expect(moveFloor(fs, '3', 1), isEmpty, reason: 'ниже некуда');
      expect(nextFloorSort(fs), 3);
      expect(nextFloorSort(const []), 0);
    });

    test('название: пустое, длинное, занятое', () {
      final fs = [floor('a', name: '1 этаж')];
      expect(checkFloorName(fs, '  '), FloorNameProblem.empty);
      expect(checkFloorName(fs, 'x' * 61), FloorNameProblem.tooLong);
      expect(checkFloorName(fs, '1 ЭТАЖ '), FloorNameProblem.taken);
      expect(checkFloorName(fs, '1 этаж', exceptId: 'a'), isNull,
          reason: 'переименование в то же название');
      expect(checkFloorName(fs, 'Парковка −2'), isNull);
    });
  });

  group('Заявки на плане', () {
    final now = DateTime(2026, 10, 10, 12);
    final orders = [
      const PlanOrder(
          id: '1',
          title: 'a',
          status: 'new',
          priority: 'normal',
          locationId: 'r1',
          assetId: 'eq'),
      PlanOrder(
          id: '2',
          title: 'b',
          status: 'in_progress',
          priority: 'high',
          locationId: 'r1',
          dueAt: DateTime(2026, 10, 9)),
      const PlanOrder(
          id: '3',
          title: 'c',
          status: 'done',
          priority: 'critical',
          locationId: 'r2'),
    ];

    test('счётчики и цвет: помещение — с заявками оборудования', () {
      final s = planStats(orders, now);
      expect(s['place:r1']!.open, 2);
      expect(s['place:r1']!.overdue, 1);
      expect(markerTone(s['place:r1']!), MarkerTone.alert);
      expect(s['asset:eq']!.open, 1);
      expect(markerTone(s['asset:eq']!), MarkerTone.open);
      expect(s['place:r2'], isNull, reason: 'принятые не считаются');
    });

    test('заявки маркера: просроченные первыми', () {
      expect(ordersOf(place('r1'), orders, now).map((o) => o.id), ['2', '1']);
      expect(ordersOf(asset('eq'), orders, now).map((o) => o.id), ['1']);
    });

    test('фильтр над планом и «Не размещены»', () {
      final s = planStats(orders, now);
      final r1 = place('r1', x: .1, y: .1), eq = asset('eq', x: .2, y: .2);
      final r3 = place('r3', x: .3, y: .3);
      expect(planFilterShows(PlanFilter.places, eq, s), isFalse);
      expect(planFilterShows(PlanFilter.assets, eq, s), isTrue);
      expect(planFilterShows(PlanFilter.withOrders, r1, s), isTrue);
      expect(planFilterShows(PlanFilter.withOrders, r3, s), isFalse);
      final items = [
        r1,
        place('free', floor: null),
        place('here', floor: 'f1'),
        place('other', floor: 'f2'),
        place('elsewhere', floor: 'f2', x: .5, y: .5),
      ];
      expect(unplacedFor('f1', items).map((i) => i.id), ['free', 'here']);
    });
  });

  group('Файл плана', () {
    final png = bytes([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, //
      0, 0, 0x09, 0x60, 0, 0, 0x06, 0x40, // 2400 × 1600
    ], pad: 16);

    test('PNG: размер из заголовка', () {
      final (info, problem) = checkPlanFile(png);
      expect(problem, isNull);
      expect((info!.mime, info.ext, info.width, info.height),
          ('image/png', 'png', 2400, 1600));
    });

    test('JPEG: размер из SOF0', () {
      final jpg = bytes([
        0xFF, 0xD8, //
        0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, длина 4
        0xFF, 0xC0, 0x00, 0x11, 0x08, 0x02, 0x58, 0x03, 0x20, // 800 × 600
      ], pad: 16);
      final (info, _) = checkPlanFile(jpg);
      expect((info!.ext, info.width, info.height), ('jpg', 800, 600));
    });

    test('WebP (VP8X): размер', () {
      final webp = bytes([
        ...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, //
        ...'VP8X'.codeUnits, 10, 0, 0, 0, 0, 0, 0, 0, //
        0x5F, 0x09, 0x00, 0x3F, 0x06, 0x00, // 2400 − 1, 1600 − 1
      ], pad: 8);
      final (info, _) = checkPlanFile(webp);
      expect((info!.mime, info.width, info.height), ('image/webp', 2400, 1600));
    });

    test('PDF, не картинка, обрезанный файл', () {
      expect(checkPlanFile(bytes('%PDF-1.7'.codeUnits, pad: 20)).$2,
          PlanFileProblem.pdf);
      expect(checkPlanFile(bytes('GIF89a'.codeUnits, pad: 20)).$2,
          PlanFileProblem.badType);
      expect(
          checkPlanFile(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
              .$2,
          PlanFileProblem.unreadable);
    });

    test('больше 15 МБ — нельзя', () {
      final big = Uint8List(kPlanMaxBytes + 1)..setAll(0, png);
      expect(checkPlanFile(big).$2, PlanFileProblem.tooBig);
      final ok = Uint8List(kPlanMaxBytes)..setAll(0, png);
      expect(checkPlanFile(ok).$2, isNull);
    });

    test('путь файла: компания / объект / этаж / plan-<время>', () {
      final f = floor('f1');
      expect(planStoragePath(f, 'png', DateTime.fromMillisecondsSinceEpoch(42)),
          'c/o/f1/plan-42.png');
    });
  });

  test('строка заявки: этаж без повтора', () {
    expect(placeWithFloor('Лобби', '1 этаж', '1 эт.'), 'Лобби · 1 эт.');
    expect(placeWithFloor('Холл, 1 этаж', '1 этаж', '1 эт.'), 'Холл, 1 этаж');
    expect(placeWithFloor('Лобби', null, null), 'Лобби');
    expect(placeWithFloor('Парковка', 'Парковка −2', null), 'Парковка · Парковка −2');
  });
}
