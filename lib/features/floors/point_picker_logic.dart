import 'dart:math' as math;
import 'dart:ui';

import 'floor_models.dart';
import 'plan_logic.dart';

// =====================================================================
// Выбор точки оборудования на плане (шаг 27, блок 6) — чистые функции:
// куда приблизить план, перевод экран ↔ доли 0..1 при масштабе и сдвиге,
// начальная точка, «точка в другом помещении». Тесты —
// test/plan_point_picker_test.dart.
// =====================================================================

/// Область плана (пиксели), к которой приближаем экран выбора точки:
/// контур помещения ([shape], доли) с полями; иначе квадрат вокруг
/// [point] (четверть меньшей стороны плана); иначе весь план.
Rect pickerFocusRect(Size plan,
    {List<(double, double)>? shape, (double, double)? point}) {
  if (shape != null && shape.length >= 3) {
    final xs = shape.map((p) => p.$1 * plan.width);
    final ys = shape.map((p) => p.$2 * plan.height);
    final r = Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min),
        xs.reduce(math.max), ys.reduce(math.max));
    // Поля: 15 % стороны, но не меньше 3 % ширины плана (видны соседи).
    final pad = math.max(math.max(r.width, r.height) * 0.15, plan.width * 0.03);
    return r.inflate(pad);
  }
  if (point != null) {
    final side = math.min(plan.width, plan.height) * 0.25;
    return Rect.fromCenter(
        center: fractionToPixels(point.$1, point.$2, plan),
        width: side,
        height: side);
  }
  return Offset.zero & plan;
}

/// Масштаб, при котором [focus] целиком помещается в окно [viewport] с
/// полями [margin]; в пределах [minScale]..[maxScale].
double pickerScale(Rect focus, Size viewport,
    {double margin = 24, double minScale = 0, double maxScale = 100}) {
  final w = math.max(1.0, viewport.width - 2 * margin);
  final h = math.max(1.0, viewport.height - 2 * margin);
  final s =
      math.min(w / math.max(1.0, focus.width), h / math.max(1.0, focus.height));
  return s.clamp(minScale, math.max(minScale, maxScale)).toDouble();
}

/// Сдвиг, при котором центр [focus] (пиксели плана) при масштабе [scale]
/// оказывается в центре окна [viewport].
Offset pickerTranslation(Rect focus, double scale, Size viewport) =>
    planCenterOn(focus.center, scale, viewport);

/// Доли 0..1 → точка на экране при сдвиге [translation] и масштабе [scale].
Offset fractionToScreen(
        (double, double) f, Size plan, Offset translation, double scale) =>
    fractionToPixels(f.$1, f.$2, plan) * scale + translation;

/// Точка на экране → доли 0..1 (за краем плана — к краю).
(double, double) screenToFraction(
        Offset screen, Size plan, Offset translation, double scale) =>
    pixelsToFraction((screen - translation) / scale, plan);

/// Сдвиг точки на экране на [screenDelta] (палец / мышь) → новые доли.
(double, double) moveFraction(
    (double, double) f, Offset screenDelta, Size plan, double scale) {
  final p = fractionToPixels(f.$1, f.$2, plan) + screenDelta / scale;
  return pixelsToFraction(p, plan);
}

/// Начальная точка маркера на этаже [floorId]: своя точка оборудования
/// (если на этом этаже) → точка помещения → центр контура помещения →
/// центр плана.
(double, double) initialPickerPoint(String floorId,
    {(String, double, double)? own, PlanItem? room}) {
  if (own != null && own.$1 == floorId) return (own.$2, own.$3);
  if (room != null && room.floorId == floorId) {
    if (room.placed) return (room.x!, room.y!);
    if (room.hasAreaOn(floorId)) return polygonCentroid(room.shape!);
  }
  return (0.5, 0.5);
}

/// Этаж, который показать сначала: этаж точки → этаж помещения → первый
/// этаж с картинкой плана. Только этажи с планом ([Floor.hasPlan]).
Floor? initialPickerFloor(List<Floor> floors,
    {String? ownFloorId, String? roomFloorId}) {
  final withPlan = [
    for (final f in sortFloors(floors))
      if (f.hasPlan) f
  ];
  for (final id in [ownFloorId, roomFloorId]) {
    if (id == null) continue;
    for (final f in withPlan) {
      if (f.id == id) return f;
    }
  }
  return withPlan.firstOrNull;
}

/// Точка попала в контур другого помещения (не [currentLocationId]) —
/// его и предложить («сменить помещение?»). Внутри своего помещения,
/// вне всех контуров — null.
PlanItem? otherRoomAt(Iterable<PlanItem> items, String floorId, double fx,
    double fy, Size plan, String? currentLocationId) {
  final hit = areaAt(items, floorId, fx, fy, plan);
  // Вложенные области: берётся самая маленькая ([areaAt]) — кабинет
  // внутри open space предлагается, open space вокруг кабинета — нет.
  if (hit == null || hit.id == currentLocationId) return null;
  return hit;
}
