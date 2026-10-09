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
      this.label});
  final List<MapItem<T>> items;

  /// Город — у кластера «весь город» на мелком масштабе ([clusterMap]).
  final String? label;

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
  return [
    for (final e in byCity.entries)
      MapCluster(
        items: e.value,
        key: 'city:${e.key}',
        label: e.key,
        center: GeoPoint(
            e.value.map((i) => i.point.lat).reduce((a, b) => a + b) /
                e.value.length,
            e.value.map((i) => i.point.lng).reduce((a, b) => a + b) /
                e.value.length),
      ),
    ...clusterByGrid(noCity, zoom),
  ];
}
