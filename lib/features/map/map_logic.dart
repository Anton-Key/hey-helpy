import 'dart:math' as math;

/// Чистая логика карты объектов: счётчики заявок, цвет маркера, фильтры
/// по области (прямоугольник, круг, видимая часть карты), поиск и группировка
/// маркеров в кластеры. Без Flutter и сети — покрыта тестами
/// (`test/map_logic_test.dart`).

/// Точка на карте (широта, долгота в градусах).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// Прямоугольная область: юг/север — широта, запад/восток — долгота.
class GeoRect {
  const GeoRect(
      {required this.south,
      required this.west,
      required this.north,
      required this.east});

  /// По двум любым углам (как протянули мышью или пальцем).
  factory GeoRect.fromCorners(GeoPoint a, GeoPoint b) => GeoRect(
      south: math.min(a.lat, b.lat),
      north: math.max(a.lat, b.lat),
      west: math.min(a.lng, b.lng),
      east: math.max(a.lng, b.lng));

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(GeoPoint p) =>
      p.lat >= south && p.lat <= north && p.lng >= west && p.lng <= east;

  /// Почти нулевая область — случайный щелчок, а не выделение.
  bool get isTiny => (north - south) < 1e-6 || (east - west) < 1e-6;

  @override
  bool operator ==(Object other) =>
      other is GeoRect &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// Расстояние по поверхности Земли (формула гаверсинусов), метры.
double distanceMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// Радиус поиска «Объекты рядом»: 0,5–20 км.
const nearbyMinKm = 0.5;
const nearbyMaxKm = 20.0;
const nearbyDefaultKm = 3.0;

/// Зум карты: 1 (весь мир — объекты в разных странах) … 19 (здание).
const mapMinZoom = 1.0;
const mapMaxZoom = 19.0;

/// Заявка в том объёме, который нужен карте.
class MapOrder {
  const MapOrder(
      {required this.objectId,
      required this.status,
      required this.priority,
      this.dueAt});
  final String? objectId;
  final String status;
  final String priority;
  final DateTime? dueAt;

  factory MapOrder.fromMap(Map<String, dynamic> m) => MapOrder(
        objectId: m['object_id'] as String?,
        status: (m['status'] ?? 'new') as String,
        priority: (m['priority'] ?? 'normal') as String,
        dueAt: m['due_at'] == null ? null : DateTime.tryParse('${m['due_at']}'),
      );

  /// Открыта: не принята и не отменена.
  bool get isOpen => status != 'done' && status != 'cancelled';

  /// Просрочена: открыта, а срок прошёл (или база уже пометила «просрочена»).
  bool isOverdue(DateTime now) =>
      isOpen && (status == 'overdue' || (dueAt != null && now.isAfter(dueAt!)));
}

/// Счётчики заявок объекта для маркера и карточки.
class ObjectStats {
  const ObjectStats(
      {this.open = 0,
      this.fresh = 0,
      this.inWork = 0,
      this.onReview = 0,
      this.overdue = 0,
      this.critical = 0,
      this.high = 0});

  /// Все открытые (не «принята» и не «отменена»).
  final int open;

  /// Ждут начала работ: новая, назначена, возвращена.
  final int fresh;
  final int inWork;
  final int onReview;
  final int overdue;

  /// Открытые срочные: critical и high.
  final int critical;
  final int high;

  static const empty = ObjectStats();

  /// Счётчики по каждому объекту. Заявки без объекта пропускаются.
  static Map<String, ObjectStats> byObject(
      Iterable<MapOrder> orders, DateTime now) {
    final acc = <String, List<int>>{};
    for (final o in orders) {
      final id = o.objectId;
      if (id == null || !o.isOpen) continue;
      final c = acc.putIfAbsent(id, () => List.filled(7, 0));
      c[0]++;
      switch (o.status) {
        case 'in_progress':
          c[2]++;
        case 'on_review':
          c[3]++;
        default:
          c[1]++;
      }
      if (o.isOverdue(now)) c[4]++;
      if (o.priority == 'critical') c[5]++;
      if (o.priority == 'high') c[6]++;
    }
    return {
      for (final e in acc.entries)
        e.key: ObjectStats(
            open: e.value[0],
            fresh: e.value[1],
            inWork: e.value[2],
            onReview: e.value[3],
            overdue: e.value[4],
            critical: e.value[5],
            high: e.value[6]),
    };
  }
}

/// Цвет маркера — по самому тревожному.
enum MarkerTone {
  /// Красный: есть просроченные или critical.
  alert,

  /// Оранжевый: есть срочные (high) или в работе.
  warning,

  /// Бирюзовый: есть открытые заявки.
  open,

  /// Серо-зелёный: открытых нет.
  idle,
}

MarkerTone markerTone(ObjectStats s) {
  if (s.open == 0) return MarkerTone.idle;
  if (s.overdue > 0 || s.critical > 0) return MarkerTone.alert;
  if (s.high > 0 || s.inWork > 0) return MarkerTone.warning;
  return MarkerTone.open;
}

/// Самый тревожный из нескольких (для кластера).
MarkerTone worstTone(Iterable<MarkerTone> tones) {
  var best = MarkerTone.idle;
  for (final t in tones) {
    if (t.index < best.index) best = t;
  }
  return best;
}

/// Объект с координатами на карте.
class MapItem<T> {
  const MapItem({required this.id, required this.point, required this.value});
  final String id;
  final GeoPoint point;
  final T value;
}

/// Объекты внутри прямоугольника (в исходном порядке).
List<MapItem<T>> itemsInRect<T>(Iterable<MapItem<T>> items, GeoRect rect) => [
      for (final i in items)
        if (rect.contains(i.point)) i
    ];

/// Объекты внутри круга, от ближних к дальним, с расстоянием в метрах.
List<(MapItem<T>, double)> itemsInCircle<T>(
    Iterable<MapItem<T>> items, GeoPoint center, double radiusM) {
  final out = <(MapItem<T>, double)>[
    for (final i in items)
      if (distanceMeters(center, i.point) case final d when d <= radiusM)
        (i, d),
  ];
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

/// Описывающий прямоугольник точек; null — точек нет.
GeoRect? boundsOf(Iterable<GeoPoint> points) {
  GeoRect? r;
  for (final p in points) {
    r = r == null
        ? GeoRect(south: p.lat, west: p.lng, north: p.lat, east: p.lng)
        : GeoRect(
            south: math.min(r.south, p.lat),
            west: math.min(r.west, p.lng),
            north: math.max(r.north, p.lat),
            east: math.max(r.east, p.lng));
  }
  return r;
}

/// Текст для поиска без регистра и «ё».
String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е').trim();

/// Подходит ли объект под поиск: все слова запроса есть в названии или адресе.
bool matchesQuery(String query, String name, String? address) {
  final q = _norm(query);
  if (q.isEmpty) return true;
  final hay = _norm('$name ${address ?? ''}');
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// Группа маркеров на карте: один объект или кластер из нескольких.
class MapCluster<T> {
  const MapCluster(
      {required this.items,
      required this.center,
      required this.key,
      this.label,
      this.moreCities = 0});
  final List<MapItem<T>> items;

  /// Город — у кластера «весь город» на мелком масштабе ([clusterMap]).
  /// У слитых городов — главный (больше объектов), остальные — [moreCities].
  final String? label;

  /// Сколько ещё городов в кластере: подпись «Белград +2».
  final int moreCities;

  /// Средняя точка группы.
  final GeoPoint center;

  /// Номер клетки сетки — устойчивый ключ для виджета.
  final String key;

  bool get isSingle => items.length == 1;
}

/// С этого зума маркеры не группируются: видно каждое здание.
const clusterMaxZoom = 15.0;

/// Размер клетки сетки, экранные пиксели. Маркеры ближе — в одну группу.
const clusterCellPx = 72.0;

/// Точка в пикселях карты Web Mercator (как у плиток) при зуме [zoom].
(double, double) mercatorPixels(GeoPoint p, double zoom) {
  final scale = 256.0 * math.pow(2, zoom);
  final lat = p.lat.clamp(-85.05112878, 85.05112878);
  final x = (p.lng + 180) / 360 * scale;
  final s = math.sin(lat * math.pi / 180);
  final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale;
  return (x, y);
}

/// Группировка маркеров по квадратной сетке на экране: точки в одной клетке
/// [cellPx]×[cellPx] при текущем зуме — один кластер. Зум
/// ≥ [clusterMaxZoom] — каждый объект отдельно. Порядок групп — по первому
/// объекту в исходном списке.
List<MapCluster<T>> clusterByGrid<T>(List<MapItem<T>> items, double zoom,
    {double cellPx = clusterCellPx, double maxZoom = clusterMaxZoom}) {
  if (zoom >= maxZoom) {
    return [
      for (final i in items)
        MapCluster(items: [i], center: i.point, key: 'o:${i.id}'),
    ];
  }
  // Целый зум — чтобы кластеры не перескакивали при плавном приближении.
  final z = zoom.floorToDouble();
  final cells = <String, List<MapItem<T>>>{};
  for (final i in items) {
    final (x, y) = mercatorPixels(i.point, z);
    final key = '${(x / cellPx).floor()}:${(y / cellPx).floor()}';
    cells.putIfAbsent(key, () => []).add(i);
  }
  return [
    for (final e in cells.entries)
      MapCluster(
          items: e.value,
          key: e.value.length == 1 ? 'o:${e.value.first.id}' : 'c:$z:${e.key}',
          center: e.value.length == 1
              ? e.value.first.point
              : GeoPoint(
                  e.value.map((i) => i.point.lat).reduce((a, b) => a + b) /
                      e.value.length,
                  e.value.map((i) => i.point.lng).reduce((a, b) => a + b) /
                      e.value.length)),
  ];
}

/// Мельче этого зума объекты одного города собираются в один кластер
/// с подписью города (страна, континент, весь мир).
const cityClusterMaxZoom = 9.0;

/// Кластеры для карты: на мелком масштабе (зум < [cityClusterMaxZoom]) —
/// по городам ([cityOf] возвращает город объекта, `''` — без города: такие
/// группируются по сетке); крупнее — по сетке ([clusterByGrid]).
List<MapCluster<T>> clusterMap<T>(List<MapItem<T>> items, double zoom,
    {String Function(T value)? cityOf}) {
  if (cityOf == null || zoom >= cityClusterMaxZoom) {
    return clusterByGrid(items, zoom);
  }
  final byCity = <String, List<MapItem<T>>>{};
  final noCity = <MapItem<T>>[];
  for (final i in items) {
    final c = cityOf(i.value);
    if (c.isEmpty) {
      noCity.add(i);
    } else {
      byCity.putIfAbsent(c, () => []).add(i);
    }
  }
  final cities = [
    for (final e in byCity.entries)
      MapCluster(
        items: e.value,
        key: 'city:${e.key}',
        label: e.key,
        center: _mean([for (final i in e.value) i.point]),
      ),
  ];
  return [..._mergeClose(cities, zoom), ...clusterByGrid(noCity, zoom)];
}

GeoPoint _mean(List<GeoPoint> p) => GeoPoint(
    p.map((x) => x.lat).reduce((a, b) => a + b) / p.length,
    p.map((x) => x.lng).reduce((a, b) => a + b) / p.length);

/// Кластеры городов, чьи кружки на экране почти совпадают (центры ближе
/// [cityMergePx]), — в один: подпись «Белград +1». Порог меньше кружка
/// (50 px): на телефоне при показе всего мира Белград, Москва, Дубай и
/// Стамбул не сливаются в один кружок — сливаются только соседи вплотную.
const cityMergePx = 40.0;

List<MapCluster<T>> _mergeClose<T>(List<MapCluster<T>> list, double zoom) {
  // Дробный зум: «весь мир» на телефоне — 1,8–2,0, округление вниз до 1
  // слило бы полмира.
  final px = [for (final c in list) mercatorPixels(c.center, zoom)];
  bool near(int a, int b) {
    final dx = px[a].$1 - px[b].$1, dy = px[a].$2 - px[b].$2;
    return dx * dx + dy * dy < cityMergePx * cityMergePx;
  }

  final out = <MapCluster<T>>[];
  final used = List.filled(list.length, false);
  for (var i = 0; i < list.length; i++) {
    if (used[i]) continue;
    used[i] = true;
    final group = [i];
    // Цепочкой: город рядом с любым уже собранным — в ту же группу.
    for (var k = 0; k < group.length; k++) {
      for (var j = 0; j < list.length; j++) {
        if (used[j] || !near(group[k], j)) continue;
        used[j] = true;
        group.add(j);
      }
    }
    if (group.length == 1) {
      out.add(list[i]);
      continue;
    }
    final cs = [for (final g in group) list[g]]
      // Главный город — где больше объектов, при равенстве — по алфавиту.
      ..sort((a, b) {
        final c = b.items.length.compareTo(a.items.length);
        return c != 0 ? c : a.label!.compareTo(b.label!);
      });
    final items = [for (final c in cs) ...c.items];
    out.add(MapCluster(
      items: items,
      key: 'cities:${([for (final c in cs) c.label!]..sort()).join('|')}',
      label: cs.first.label,
      moreCities: cs.length - 1,
      center: _mean([for (final i in items) i.point]),
    ));
  }
  return out;
}

/// Где подпись города у кластера: под кружком, над ним или скрыта
/// (места нет ни снизу, ни сверху — город остаётся в подсказке и для
/// диктора).
enum CityLabelPos { below, above, hidden }

/// Размеры для [cityLabelPlacement] (как у ClusterMarker в map_parts.dart).
const _circlePx = 50.0;
const _labelH = 18.0;
const _labelGap = 4.0;
const _labelMaxW = 150.0;

/// Ширина подписи на экране — оценка по числу букв (шрифт 12, жирный).
double cityLabelWidth(String text) =>
    math.min(_labelMaxW, text.length * 7.2 + 16);

/// Подписи городов не должны наезжать на соседние кружки и подписи (на
/// телефоне 360 px «Москва» закрывала «Белград +1»). Сначала размещаются
/// большие кластеры; подпись — под кружком, если там занято — над ним,
/// если и там — скрыта. [text] — текст подписи кластера (с «+N»).
Map<String, CityLabelPos> cityLabelPlacement<T>(
    List<MapCluster<T>> clusters, double zoom,
    {required String Function(MapCluster<T> c) text}) {
  final px = {
    for (final c in clusters) c.key: mercatorPixels(c.center, zoom),
  };
  // Занятые прямоугольники: все кружки сразу, подписи — по мере размещения.
  final taken = <(String, double, double, double, double)>[
    for (final c in clusters)
      (
        c.key,
        px[c.key]!.$1 - _circlePx / 2,
        px[c.key]!.$2 - _circlePx / 2,
        px[c.key]!.$1 + _circlePx / 2,
        px[c.key]!.$2 + _circlePx / 2,
      ),
  ];
  bool free(String own, (double, double, double, double) r) {
    for (final t in taken) {
      if (t.$1 == own) continue;
      if (r.$1 < t.$4 && r.$3 > t.$2 && r.$2 < t.$5 && r.$4 > t.$3) {
        return false;
      }
    }
    return true;
  }

  final order = [
    for (final c in clusters)
      if (c.label != null) c
  ]..sort((a, b) => b.items.length.compareTo(a.items.length));
  final out = <String, CityLabelPos>{};
  for (final c in order) {
    final (x, y) = px[c.key]!;
    final w = cityLabelWidth(text(c));
    final top = y + _circlePx / 2 + _labelGap;
    final below = (x - w / 2, top, x + w / 2, top + _labelH);
    final bottom = y - _circlePx / 2 - _labelGap;
    final above = (x - w / 2, bottom - _labelH, x + w / 2, bottom);
    final CityLabelPos pos;
    final (double, double, double, double)? rect;
    if (free(c.key, below)) {
      pos = CityLabelPos.below;
      rect = below;
    } else if (free(c.key, above)) {
      pos = CityLabelPos.above;
      rect = above;
    } else {
      pos = CityLabelPos.hidden;
      rect = null;
    }
    out[c.key] = pos;
    if (rect != null) {
      taken.add(('${c.key}#label', rect.$1, rect.$2, rect.$3, rect.$4));
    }
  }
  return out;
}

/// Отступы «показать всё» на карте (лево, верх, право, низ), px — до
/// центра крайнего маркера: сверху — чипы городов (до 56 px), справа —
/// кнопки зума (до 56 px), снизу на телефоне — выдвижная панель списка
/// (~⅓ высоты); плюс радиус кружка (25) и подпись города под ним. На ПК
/// список слева — отдельной колонкой.
({double left, double top, double right, double bottom}) mapFitPadding(
        {required bool wide, required double height}) =>
    wide
        ? (left: 56, top: 88, right: 100, bottom: 64)
        : (left: 40, top: 88, right: 92, bottom: height * 0.34 + 44);

/// Зум, при котором [bounds] целиком помещается в окно [width]×[height]
/// с отступами [pad] (как CameraFit.bounds у flutter_map), от [mapMinZoom]
/// до [maxZoom].
double fitZoom(GeoRect bounds, double width, double height,
    ({double left, double top, double right, double bottom}) pad,
    {double maxZoom = 15}) {
  final (x0, y0) = mercatorPixels(GeoPoint(bounds.north, bounds.west), 0);
  final (x1, y1) = mercatorPixels(GeoPoint(bounds.south, bounds.east), 0);
  final w = math.max(1.0, width - pad.left - pad.right);
  final h = math.max(1.0, height - pad.top - pad.bottom);
  final sx = w / math.max(1e-9, (x1 - x0).abs());
  final sy = h / math.max(1e-9, (y1 - y0).abs());
  final z = math.log(math.min(sx, sy)) / math.ln2;
  return z.clamp(mapMinZoom, maxZoom).toDouble();
}

/// Чип над картой (шаг 16): регион и его объекты.
class RegionChip<T> {
  const RegionChip(this.id, this.name, this.items);

  /// id региона.
  final String id;
  final String name;
  final List<T> items;
}

/// Чипы регионов над картой — в порядке [regions] (id, название), только
/// регионы с объектами. null — регионов нет или ни один объект к ним не
/// привязан: тогда чипы, как раньше, по городам. Объекты без региона в чипы
/// не попадают (их видно в «Все»).
List<RegionChip<T>>? regionChips<T>(List<T> items,
    {required String? Function(T value) regionOf,
    required List<({String id, String name})> regions}) {
  if (regions.isEmpty) return null;
  final by = <String, List<T>>{};
  for (final i in items) {
    final r = regionOf(i);
    if (r != null) by.putIfAbsent(r, () => []).add(i);
  }
  final out = [
    for (final r in regions)
      if (by.containsKey(r.id)) RegionChip(r.id, r.name, by[r.id]!),
  ];
  return out.isEmpty ? null : out;
}
