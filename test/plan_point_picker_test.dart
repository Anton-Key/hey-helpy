import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/floors/floor_models.dart';
import 'package:hey_helpy/features/floors/plan_logic.dart';
import 'package:hey_helpy/features/floors/point_picker_logic.dart';

PlanItem room(String id, List<(double, double)>? shape,
        {String floor = 'f1', double? x, double? y}) =>
    PlanItem(
        kind: PlanKind.place,
        id: id,
        name: 'Помещение $id',
        code: id,
        floorId: floor,
        x: x,
        y: y,
        shape: shape);

Floor floor(String id, {bool plan = true, int sort = 0}) => Floor(
    id: id,
    objectId: 'o',
    companyId: 'c',
    name: '$id этаж',
    sort: sort,
    planPath: plan ? 'c/o/$id/plan.png' : null,
    planW: plan ? 2400 : null,
    planH: plan ? 1600 : null);

void main() {
  const plan = Size(2400, 1600);

  group('точка в контуре помещения', () {
    // Демо-схема (tools/demo_plans/plans.json): rect [x, y, w, h] в пикселях
    // 2400×1600 → plan_shape «polygon» долями.
    final r301 = room(
        '301',
        rectShape((120 / 2400, 120 / 1600),
            ((120 + 480) / 2400, (120 + 420) / 1600)));
    final r302 = room(
        '302',
        rectShape((600 / 2400, 120 / 1600),
            ((600 + 480) / 2400, (120 + 420) / 1600)));
    // Open space с кабинетом внутри.
    final open = room('305', rectShape((0.5, 0.4), (0.95, 0.95)));
    final cab = room('306', rectShape((0.6, 0.5), (0.7, 0.6)));
    // Треугольник — не прямоугольник.
    final tri = room('t', [(0.1, 0.9), (0.3, 0.6), (0.4, 0.9)]);
    final items = [r301, r302, open, cab, tri];

    test('pointInPolygon: прямоугольник plan_shape и треугольник', () {
      expect(pointInPolygon(0.1, 0.2, r301.shape!), isTrue);
      expect(pointInPolygon(0.3, 0.2, r301.shape!), isFalse);
      expect(pointInPolygon(0.3, 0.85, tri.shape!), isTrue);
      expect(pointInPolygon(0.15, 0.65, tri.shape!), isFalse);
    });

    test('точка в другом помещении — предложить его', () {
      // Точка в 302, оборудование числится в 301.
      final hit = otherRoomAt(items, 'f1', 0.35, 0.2, plan, '301');
      expect(hit?.id, '302');
    });

    test('точка в своём помещении или вне всех — ничего', () {
      expect(otherRoomAt(items, 'f1', 0.1, 0.2, plan, '301'), isNull);
      expect(otherRoomAt(items, 'f1', 0.02, 0.02, plan, '301'), isNull);
    });

    test('вложенные: кабинет в open space предлагается, наоборот — нет', () {
      expect(otherRoomAt(items, 'f1', 0.65, 0.55, plan, '305')?.id, '306');
      expect(otherRoomAt(items, 'f1', 0.65, 0.55, plan, '306'), isNull);
    });

    test('другой этаж не считается', () {
      expect(otherRoomAt(items, 'f2', 0.35, 0.2, plan, '301'), isNull);
    });
  });

  group('экран ↔ доли при приближении и сдвиге', () {
    test('туда и обратно — та же точка', () {
      const t = Offset(-350, 120);
      const s = 0.75;
      final screen = fractionToScreen((0.25, 0.5), plan, t, s);
      expect(screen, const Offset(0.25 * 2400 * 0.75 - 350, 800 * 0.75 + 120));
      final back = screenToFraction(screen, plan, t, s);
      expect(back.$1, closeTo(0.25, 1e-9));
      expect(back.$2, closeTo(0.5, 1e-9));
    });

    test('за краем плана — к краю', () {
      final f =
          screenToFraction(const Offset(-1000, 99999), plan, Offset.zero, 1);
      expect(f, (0.0, 1.0));
    });

    test('сдвиг пальцем делится на масштаб', () {
      // При масштабе 2 палец на 48 px сдвигает точку на 24 px плана = 1 %.
      final f = moveFraction((0.5, 0.5), const Offset(48, 0), plan, 2);
      expect(f.$1, closeTo(0.51, 1e-9));
      expect(f.$2, closeTo(0.5, 1e-9));
    });

    test('приближение к контуру помещения: контур целиком в окне, по центру',
        () {
      final shape = rectShape((0.25, 0.25), (0.45, 0.5));
      final focus = pickerFocusRect(plan, shape: shape);
      // Поля вокруг контура.
      expect(focus.left, lessThan(0.25 * 2400));
      expect(focus.right, greaterThan(0.45 * 2400));
      const vp = Size(400, 700);
      final s = pickerScale(focus, vp, margin: 24, minScale: 0.1, maxScale: 5);
      final t = pickerTranslation(focus, s, vp);
      // Углы контура на экране — внутри окна.
      for (final p in shape) {
        final o = fractionToScreen(p, plan, t, s);
        expect(o.dx, inInclusiveRange(0, vp.width));
        expect(o.dy, inInclusiveRange(0, vp.height));
      }
      // Центр контура — в центре окна.
      final c = fractionToScreen((0.35, 0.375), plan, t, s);
      expect(c.dx, closeTo(200, 1e-6));
      expect(c.dy, closeTo(350, 1e-6));
    });

    test('масштаб в пределах', () {
      final r = pickerFocusRect(plan, point: (0.5, 0.5));
      expect(pickerScale(r, const Size(4000, 4000), maxScale: 2), 2);
      expect(
          pickerScale(const Rect.fromLTWH(0, 0, 10, 10), const Size(100, 100),
              minScale: 0.5, maxScale: 3),
          3);
      // Без контура и точки — весь план.
      expect(pickerFocusRect(plan), Offset.zero & plan);
    });
  });

  group('начальный этаж и точка', () {
    test('этаж: своей точки → помещения → первый с планом', () {
      final floors = [
        floor('f0', plan: false),
        floor('f1', sort: 1),
        floor('f2', sort: 2)
      ];
      expect(
          initialPickerFloor(floors, ownFloorId: 'f2', roomFloorId: 'f1')?.id,
          'f2');
      expect(initialPickerFloor(floors, roomFloorId: 'f1')?.id, 'f1');
      expect(initialPickerFloor(floors, roomFloorId: 'f0')?.id, 'f1',
          reason: 'этаж без картинки плана не подходит');
      expect(initialPickerFloor([floor('x', plan: false)]), isNull);
    });

    test('точка: своя → помещения → центр контура → центр плана', () {
      final r = room('301', rectShape((0.2, 0.2), (0.4, 0.4)), x: 0.3, y: 0.25);
      final noPoint = room('302', rectShape((0.2, 0.2), (0.4, 0.4)));
      expect(
          initialPickerPoint('f1', own: ('f1', 0.1, 0.2), room: r), (0.1, 0.2));
      expect(initialPickerPoint('f1', own: ('f2', 0.1, 0.2), room: r),
          (0.3, 0.25));
      final c = initialPickerPoint('f1', room: noPoint);
      expect(c.$1, closeTo(0.3, 1e-9));
      expect(c.$2, closeTo(0.3, 1e-9));
      expect(initialPickerPoint('f9', room: r), (0.5, 0.5));
    });
  });
}
