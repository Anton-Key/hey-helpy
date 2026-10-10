import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/map/map_logic.dart';

MapItem<String> item(String id, double lat, double lng) =>
    MapItem(id: id, point: GeoPoint(lat, lng), value: id);

void main() {
  final now = DateTime.utc(2026, 10, 9, 12);

  group('distanceMeters', () {
    test('1° широты ≈ 111 км', () {
      final d = distanceMeters(const GeoPoint(44, 20), const GeoPoint(45, 20));
      expect(d, closeTo(111195, 200));
    });
    test('одна точка — 0', () {
      expect(
          distanceMeters(
              const GeoPoint(44.8, 20.4), const GeoPoint(44.8, 20.4)),
          0);
    });
  });

  group('GeoRect', () {
    test('по углам в любом порядке', () {
      final r = GeoRect.fromCorners(
          const GeoPoint(44.9, 20.5), const GeoPoint(44.7, 20.3));
      expect(r.south, 44.7);
      expect(r.north, 44.9);
      expect(r.west, 20.3);
      expect(r.east, 20.5);
      expect(r.contains(const GeoPoint(44.8, 20.4)), isTrue);
      expect(r.contains(const GeoPoint(44.95, 20.4)), isFalse);
      expect(r.contains(const GeoPoint(44.8, 20.2)), isFalse);
      // Граница входит.
      expect(r.contains(const GeoPoint(44.7, 20.3)), isTrue);
    });
    test('щелчок без протягивания — пустая область', () {
      const p = GeoPoint(44.8, 20.4);
      expect(GeoRect.fromCorners(p, p).isTiny, isTrue);
    });
  });

  group('фильтры области', () {
    final items = [
      item('center', 44.8047, 20.4494),
      item('plaza', 44.8030, 20.4040),
      item('log', 44.8590, 20.3800),
      item('park', 44.7700, 20.4800),
    ];

    test('в прямоугольнике — в исходном порядке', () {
      final r = GeoRect.fromCorners(
          const GeoPoint(44.79, 20.39), const GeoPoint(44.82, 20.46));
      expect(itemsInRect(items, r).map((i) => i.id), ['center', 'plaza']);
    });

    test('в круге — по удалённости, с расстоянием', () {
      final res = itemsInCircle(items, const GeoPoint(44.8047, 20.4494), 5000);
      expect(res.map((e) => e.$1.id), ['center', 'plaza', 'park']);
      expect(res.first.$2, 0);
      expect(res[1].$2, closeTo(3590, 100));
      expect(res.every((e) => e.$2 <= 5000), isTrue);
    });

    test('в видимой области (те же границы карты)', () {
      const visible =
          GeoRect(south: 44.76, west: 20.37, north: 44.87, east: 20.42);
      expect(itemsInRect(items, visible).map((i) => i.id), ['plaza', 'log']);
    });

    test('границы всех объектов', () {
      final b = boundsOf(items.map((i) => i.point))!;
      expect(b.south, 44.77);
      expect(b.north, 44.859);
      expect(b.west, 20.38);
      expect(b.east, 20.48);
      expect(boundsOf(const []), isNull);
    });
  });

  group('счётчики и цвет маркера', () {
    MapOrder o(String status,
            {String priority = 'normal', DateTime? due, String obj = 'a'}) =>
        MapOrder(objectId: obj, status: status, priority: priority, dueAt: due);

    test('принятые и отменённые не считаются', () {
      final s = ObjectStats.byObject(
          [o('done'), o('cancelled', priority: 'critical')], now);
      expect(s['a'], isNull);
      expect(markerTone(s['a'] ?? ObjectStats.empty), MarkerTone.idle);
    });

    test('новые / в работе / на проверке / просрочено', () {
      final s = ObjectStats.byObject([
        o('new'),
        o('assigned'),
        o('returned'),
        o('in_progress'),
        o('on_review'),
        o('assigned', due: now.subtract(const Duration(hours: 1))),
        o('new', obj: 'b'),
        const MapOrder(objectId: null, status: 'new', priority: 'critical'),
      ], now);
      final a = s['a']!;
      expect(a.open, 6);
      expect(a.fresh, 4);
      expect(a.inWork, 1);
      expect(a.onReview, 1);
      expect(a.overdue, 1);
      expect(s['b']!.open, 1);
      expect(s.length, 2);
    });

    test('красный: просрочена или critical', () {
      expect(
          markerTone(ObjectStats.byObject(
              [o('new', due: now.subtract(const Duration(minutes: 1)))],
              now)['a']!),
          MarkerTone.alert);
      expect(
          markerTone(ObjectStats.byObject(
              [o('new', priority: 'critical')], now)['a']!),
          MarkerTone.alert);
      // Принятая с прошедшим сроком — не просрочена для карты.
      expect(
          o('done', due: now.subtract(const Duration(days: 1))).isOverdue(now),
          isFalse);
      expect(o('overdue').isOverdue(now), isTrue);
    });

    test('оранжевый: high или в работе', () {
      expect(
          markerTone(
              ObjectStats.byObject([o('new', priority: 'high')], now)['a']!),
          MarkerTone.warning);
      expect(markerTone(ObjectStats.byObject([o('in_progress')], now)['a']!),
          MarkerTone.warning);
    });

    test('бирюзовый: просто открытые; срок в будущем', () {
      expect(
          markerTone(ObjectStats.byObject(
              [o('on_review', due: now.add(const Duration(hours: 2)))],
              now)['a']!),
          MarkerTone.open);
    });

    test('кластер — по самому тревожному', () {
      expect(worstTone([MarkerTone.idle, MarkerTone.open, MarkerTone.warning]),
          MarkerTone.warning);
      expect(worstTone([MarkerTone.open, MarkerTone.alert]), MarkerTone.alert);
      expect(worstTone(const []), MarkerTone.idle);
    });
  });

  group('поиск', () {
    test('по названию и адресу, без регистра и «ё»', () {
      expect(matchesQuery('плаза', 'ТЦ «Демо Плаза»', null), isTrue);
      expect(matchesQuery('земун', 'Склад', 'Белград, Земун (демо)'), isTrue);
      expect(
          matchesQuery('демо зЕмун', 'Склад', 'Белград, Земун (демо)'), isTrue);
      expect(matchesQuery('елка', 'Ёлка', null), isTrue);
      expect(matchesQuery('отель', 'Склад', 'Земун'), isFalse);
      expect(matchesQuery('  ', 'Что угодно', null), isTrue);
    });
  });

  group('кластеры', () {
    final items = [
      item('a', 44.8047, 20.4494),
      item('b', 44.8050, 20.4500), // ~60 м от a
      item('far', 44.8590, 20.3800), // ~8 км
    ];

    test('отдалили — близкие объекты в одном кластере', () {
      final c = clusterByGrid(items, 10);
      final big = c.firstWhere((g) => !g.isSingle);
      expect(big.items.map((i) => i.id), containsAll(['a', 'b']));
      expect(big.center.lat, closeTo(44.80485, 1e-6));
      expect(c.length, 2);
    });

    test('совсем далеко — все вместе', () {
      final c = clusterByGrid(items, 4);
      expect(c.length, 1);
      expect(c.single.items.length, 3);
    });

    test('с зума 15 — каждый отдельно', () {
      final c = clusterByGrid(items, 15);
      expect(c.length, 3);
      expect(c.every((g) => g.isSingle), isTrue);
      expect(c.first.key, 'o:a');
    });

    test('дробный зум — как целый (кластеры не мигают)', () {
      final a = clusterByGrid(items, 10.2).map((c) => c.key).toList();
      final b = clusterByGrid(items, 10.9).map((c) => c.key).toList();
      expect(a, b);
    });

    test('пустой список', () {
      expect(clusterByGrid(<MapItem<String>>[], 10), isEmpty);
    });
  });

  group('clusterMap — города на мелком масштабе', () {
    const moscowA =
        MapItem(id: 'm1', point: GeoPoint(55.749, 37.537), value: 'Москва');
    const moscowB =
        MapItem(id: 'm2', point: GeoPoint(55.697, 37.359), value: 'Москва');
    const dubai =
        MapItem(id: 'd1', point: GeoPoint(25.186, 55.265), value: 'Дубай');
    const none = MapItem(id: 'x', point: GeoPoint(10, 10), value: '');
    final items = [moscowA, moscowB, dubai, none];
    String city(String v) => v;

    test('мир: один кластер на город с подписью, даже из одного объекта', () {
      final c = clusterMap(items, 3, cityOf: city);
      final byKey = {for (final x in c) x.key: x};
      expect(byKey['city:Москва']!.items.length, 2);
      expect(byKey['city:Москва']!.label, 'Москва');
      expect(byKey['city:Дубай']!.items.single.id, 'd1');
      // Без города — по сетке, без подписи.
      expect(c.where((x) => x.label == null).single.items.single.id, 'x');
      final center = byKey['city:Москва']!.center;
      expect(center.lat, closeTo((55.749 + 55.697) / 2, 1e-9));
    });

    test('город и крупнее — обычная сетка', () {
      final c = clusterMap(items, cityClusterMaxZoom, cityOf: city);
      expect(c.every((x) => x.label == null), isTrue);
      expect(clusterMap(items, 3).every((x) => x.label == null), isTrue,
          reason: 'без cityOf — как раньше');
    });
  });

  test('clusterMap: города вплотную — один кластер «Белград +1»', () {
    const bg =
        MapItem(id: 'b', point: GeoPoint(44.80, 20.45), value: 'Белград');
    const bg2 =
        MapItem(id: 'b2', point: GeoPoint(44.81, 20.46), value: 'Белград');
    const ist =
        MapItem(id: 'i', point: GeoPoint(41.08, 29.01), value: 'Стамбул');
    const bj = MapItem(id: 'p', point: GeoPoint(39.90, 116.46), value: 'Пекин');
    String city(String v) => v;
    final far = clusterMap([ist, bg, bg2, bj], 1, cityOf: city);
    final merged = far.firstWhere((c) => c.items.length == 3);
    // Главный — где больше объектов.
    expect(merged.label, 'Белград');
    expect(merged.moreCities, 1);
    expect(far.firstWhere((c) => c.label == 'Пекин').items.single.id, 'p');
    // Ближе — города отдельно.
    final near = clusterMap([bg, ist, bj], 5, cityOf: city);
    expect(near.map((c) => c.label).toSet(), {'Белград', 'Стамбул', 'Пекин'});
    expect(near.every((c) => c.moreCities == 0), isTrue);
  });

  group('Весь мир на телефоне (шаг 13e)', () {
    // Города демо-объектов (demo_history.sql), по одному объекту.
    const cities = {
      'Белград': GeoPoint(44.80, 20.45),
      'Москва': GeoPoint(55.73, 37.50),
      'Стамбул': GeoPoint(41.05, 29.00),
      'Дубай': GeoPoint(25.18, 55.26),
      'Абиджан': GeoPoint(5.32, -4.02),
      'Шэньчжэнь': GeoPoint(22.54, 114.05),
      'Пекин': GeoPoint(39.90, 116.46),
    };
    final items = [
      for (final e in cities.entries)
        MapItem(id: e.key, point: e.value, value: e.key),
    ];
    final bounds = boundsOf(cities.values)!;

    // Высота карты: окно минус шапка (~135) и нижнее меню (56).
    for (final (w, h) in [(360.0, 590.0), (412.0, 725.0)]) {
      test('$w px: масштаб «показать всё» и не меньше 5 отдельных городов', () {
        final pad = mapFitPadding(wide: false, height: h);
        final z = fitZoom(bounds, w, h, pad);
        expect(z, greaterThan(1.3), reason: 'мир виден крупнее минимального');
        final c = clusterMap(items, z, cityOf: (String v) => v);
        expect(c.length, greaterThanOrEqualTo(5),
            reason: 'зум ${z.toStringAsFixed(2)}: ${c.map((x) => x.label)}');
        // Все точки — внутри окна с отступами.
        final (x0, y0) = mercatorPixels(GeoPoint(bounds.north, bounds.west), z);
        final (x1, y1) = mercatorPixels(GeoPoint(bounds.south, bounds.east), z);
        expect(x1 - x0, lessThanOrEqualTo(w - pad.left - pad.right + 0.5));
        expect(y1 - y0, lessThanOrEqualTo(h - pad.top - pad.bottom + 0.5));
      });
    }

    test('отступы: на телефоне снизу — место под панель списка', () {
      final p = mapFitPadding(wide: false, height: 800);
      expect(p.bottom, closeTo(272 + 44, 0.1));
      expect(mapFitPadding(wide: true, height: 800).bottom, 64);
    });
  });
}
