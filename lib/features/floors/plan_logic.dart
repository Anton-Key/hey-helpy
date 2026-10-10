import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../map/map_logic.dart';
import 'floor_models.dart';

// =====================================================================
// Чистые функции планов этажей (тесты — test/plan_logic_test.dart).
// =====================================================================

/// Размер «сетки» этажа без картинки: маркеры всё равно ставятся.
const kDefaultPlanSize = Size(2000, 1400);

/// Самый большой файл плана (как у бакета floor-plans в 0013).
const kPlanMaxBytes = 15 * 1024 * 1024;

/// Размер плана этажа в пикселях: картинка или сетка по умолчанию.
Size planSize(Floor f) => f.hasPlan
    ? Size(f.planW!.toDouble(), f.planH!.toDouble())
    : kDefaultPlanSize;

/// Доли 0..1 → пиксели плана.
Offset fractionToPixels(double fx, double fy, Size plan) =>
    Offset(fx * plan.width, fy * plan.height);

/// Пиксели плана → доли 0..1 (за краем — к краю: точка не уходит с плана).
(double, double) pixelsToFraction(Offset p, Size plan) => (
      (p.dx / plan.width).clamp(0.0, 1.0).toDouble(),
      (p.dy / plan.height).clamp(0.0, 1.0).toDouble(),
    );

/// Ближайшее к точке ([fx], [fy] — доли) помещение на плане этажа
/// [floorId]. Расстояние — в пикселях плана (доли у вытянутой картинки
/// неравноценны). null — на этаже нет помещений с точкой.
PlanItem? nearestPlace(
    Iterable<PlanItem> items, String floorId, double fx, double fy, Size plan) {
  PlanItem? best;
  var bestD = double.infinity;
  final p = fractionToPixels(fx, fy, plan);
  for (final i in items) {
    if (!i.isPlace || !i.isOn(floorId)) continue;
    final d = (fractionToPixels(i.x!, i.y!, plan) - p).distanceSquared;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// Этажи по порядку: [Floor.sort], затем номер этажа, затем название.
List<Floor> sortFloors(Iterable<Floor> floors) => floors.toList()
  ..sort((a, b) {
    final s = a.sort.compareTo(b.sort);
    if (s != 0) return s;
    final l = (a.level ?? 0).compareTo(b.level ?? 0);
    return l != 0 ? l : a.name.compareTo(b.name);
  });

/// «Выше» ([delta] = −1) / «Ниже» (+1): новый порядок — номера 0..n−1.
/// Возвращает только этажи, у которых номер поменялся (их и сохранять).
Map<String, int> moveFloor(List<Floor> floors, String id, int delta) {
  final list = sortFloors(floors);
  final i = list.indexWhere((f) => f.id == id);
  final j = i + delta;
  if (i < 0 || j < 0 || j >= list.length) return const {};
  final moved = list.removeAt(i);
  list.insert(j, moved);
  return {
    for (var k = 0; k < list.length; k++)
      if (list[k].sort != k) list[k].id: k,
  };
}

/// Порядок нового этажа — в конце списка.
int nextFloorSort(Iterable<Floor> floors) =>
    floors.fold(-1, (m, f) => math.max(m, f.sort)) + 1;

/// Название этажа свободно в объекте (база требует уникальности, 0013).
bool floorNameFree(Iterable<Floor> floors, String name, {String? exceptId}) {
  final n = name.trim().toLowerCase();
  return !floors
      .any((f) => f.id != exceptId && f.name.trim().toLowerCase() == n);
}

/// Что не так с названием этажа: null — подходит.
enum FloorNameProblem { empty, tooLong, taken }

FloorNameProblem? checkFloorName(Iterable<Floor> floors, String name,
    {String? exceptId}) {
  final t = name.trim();
  if (t.isEmpty) return FloorNameProblem.empty;
  if (t.length > 60) return FloorNameProblem.tooLong;
  if (!floorNameFree(floors, t, exceptId: exceptId)) {
    return FloorNameProblem.taken;
  }
  return null;
}

// ---------------------------------------------------------------------
// Заявки на плане
// ---------------------------------------------------------------------

/// Счётчики открытых заявок по маркерам ([PlanItem.key]): у помещения —
/// все заявки помещения (в том числе на его оборудовании), у оборудования —
/// только его заявки. Цвет маркера — [markerTone], как на карте.
Map<String, ObjectStats> planStats(Iterable<PlanOrder> orders, DateTime now) {
  final mapped = <MapOrder>[
    for (final o in orders) ...[
      if (o.locationId != null)
        MapOrder(
            objectId: 'place:${o.locationId}',
            status: o.status,
            priority: o.priority,
            dueAt: o.dueAt),
      if (o.assetId != null)
        MapOrder(
            objectId: 'asset:${o.assetId}',
            status: o.status,
            priority: o.priority,
            dueAt: o.dueAt),
    ],
  ];
  return ObjectStats.byObject(mapped, now);
}

/// Заявки маркера (открытые, сначала просроченные и срочные).
List<PlanOrder> ordersOf(
    PlanItem item, Iterable<PlanOrder> orders, DateTime now) {
  const rank = {'critical': 0, 'high': 1, 'normal': 2, 'low': 3};
  final list = [
    for (final o in orders)
      if (o.isOpen &&
          (item.isPlace ? o.locationId == item.id : o.assetId == item.id))
        o
  ];
  list.sort((a, b) {
    final od = (b.isOverdue(now) ? 1 : 0) - (a.isOverdue(now) ? 1 : 0);
    if (od != 0) return od;
    return (rank[a.priority] ?? 2).compareTo(rank[b.priority] ?? 2);
  });
  return list;
}

/// Фильтр над планом.
enum PlanFilter { all, places, assets, withOrders }

bool planFilterShows(
        PlanFilter f, PlanItem item, Map<String, ObjectStats> stats) =>
    switch (f) {
      PlanFilter.all => true,
      PlanFilter.places => item.isPlace,
      PlanFilter.assets => !item.isPlace,
      PlanFilter.withOrders => (stats[item.key]?.open ?? 0) > 0,
    };

/// Список «Не размещены» для этажа [floorId]: помещения и оборудование
/// объекта без точки на плане — на этом этаже или без этажа. Стоящие на
/// плане другого этажа сюда не попадают (они уже размещены).
List<PlanItem> unplacedFor(String floorId, Iterable<PlanItem> items) => [
      for (final i in items)
        if (!i.placed && (i.floorId == null || i.floorId == floorId)) i
    ];

/// Подписи названий видны, когда план приближен заметно сильнее, чем
/// «вписать» ([fitScale]).
bool labelsVisible(double scale, double fitScale) => scale >= fitScale * 1.6;

/// Масштаб «вписать»: план целиком в окне [viewport] с полями [margin].
double planFitScale(Size viewport, Size plan, {double margin = 24}) {
  final w = math.max(1.0, viewport.width - 2 * margin);
  final h = math.max(1.0, viewport.height - 2 * margin);
  return math.min(w / plan.width, h / plan.height);
}

/// Сдвиг плана, при котором точка [p] (пиксели плана) при масштабе
/// [scale] оказывается в центре окна [viewport].
Offset planCenterOn(Offset p, double scale, Size viewport) => Offset(
    viewport.width / 2 - p.dx * scale, viewport.height / 2 - p.dy * scale);

// ---------------------------------------------------------------------
// Файл плана
// ---------------------------------------------------------------------

/// Картинка плана: формат и размер в пикселях (из заголовка файла).
class PlanImageInfo {
  const PlanImageInfo(this.mime, this.ext, this.width, this.height);
  final String mime;
  final String ext;
  final int width;
  final int height;
}

/// Что не так с файлом плана.
enum PlanFileProblem { tooBig, pdf, badType, unreadable }

/// Проверка файла плана: PNG / JPEG / WebP до 15 МБ. Возвращает формат
/// и размер или проблему (PDF — отдельно: для него есть совет).
(PlanImageInfo?, PlanFileProblem?) checkPlanFile(Uint8List bytes) {
  if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46])) {
    return (null, PlanFileProblem.pdf); // %PDF
  }
  final info = readImageInfo(bytes);
  if (info == null) {
    final known = _isPng(bytes) || _isJpeg(bytes) || _isWebp(bytes);
    return (null, known ? PlanFileProblem.unreadable : PlanFileProblem.badType);
  }
  if (bytes.length > kPlanMaxBytes) return (null, PlanFileProblem.tooBig);
  return (info, null);
}

/// Путь файла плана в бакете floor-plans:
/// `<company_id>/<object_id>/<floor_id>/plan-<время>.<расширение>`.
String planStoragePath(Floor f, String ext, DateTime now) =>
    '${f.companyId}/${f.objectId}/${f.id}/plan-${now.millisecondsSinceEpoch}.$ext';

bool _startsWith(Uint8List b, List<int> sig, [int at = 0]) {
  if (b.length < at + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[at + i] != sig[i]) return false;
  }
  return true;
}

bool _isPng(Uint8List b) =>
    _startsWith(b, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
bool _isJpeg(Uint8List b) => _startsWith(b, const [0xFF, 0xD8]);
bool _isWebp(Uint8List b) =>
    _startsWith(b, 'RIFF'.codeUnits) && _startsWith(b, 'WEBP'.codeUnits, 8);

/// Формат и размер картинки по заголовку (PNG, JPEG, WebP); null — не
/// картинка этих форматов или файл обрезан.
PlanImageInfo? readImageInfo(Uint8List b) {
  int u16be(int i) => (b[i] << 8) | b[i + 1];
  int u32be(int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  int u16le(int i) => b[i] | (b[i + 1] << 8);
  int u24le(int i) => b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);

  PlanImageInfo? ok(String mime, String ext, int w, int h) =>
      w > 0 && h > 0 ? PlanImageInfo(mime, ext, w, h) : null;

  if (_isPng(b)) {
    if (b.length < 24 || !_startsWith(b, 'IHDR'.codeUnits, 12)) return null;
    return ok('image/png', 'png', u32be(16), u32be(20));
  }
  if (_isJpeg(b)) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) return null;
      final m = b[i + 1];
      if (m == 0xFF) {
        i++;
        continue;
      }
      // Маркеры без длины.
      if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
        i += 2;
        continue;
      }
      final len = u16be(i + 2);
      final sof = m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC;
      if (sof) return ok('image/jpeg', 'jpg', u16be(i + 7), u16be(i + 5));
      i += 2 + len;
    }
    return null;
  }
  if (_isWebp(b)) {
    if (b.length < 30) return null;
    if (_startsWith(b, 'VP8 '.codeUnits, 12)) {
      return ok('image/webp', 'webp', u16le(26) & 0x3FFF, u16le(28) & 0x3FFF);
    }
    if (_startsWith(b, 'VP8L'.codeUnits, 12)) {
      final w = 1 + (((b[22] & 0x3F) << 8) | b[21]);
      final h =
          1 + (((b[24] & 0x0F) << 10) | (b[23] << 2) | ((b[22] & 0xC0) >> 6));
      return ok('image/webp', 'webp', w, h);
    }
    if (_startsWith(b, 'VP8X'.codeUnits, 12)) {
      return ok('image/webp', 'webp', 1 + u24le(24), 1 + u24le(27));
    }
    return null;
  }
  return null;
}
