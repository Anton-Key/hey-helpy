import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/requests/order_form_place.dart';

// Белград: «БЦ «Демо»» и объект в ~1,1 км от него.
final demo = Obj(
    id: 'o1',
    name: 'БЦ «Демо»',
    address: 'Белград, Савски венац',
    type: 'office',
    lat: 44.80471,
    lng: 20.44942);
final far = Obj(
    id: 'o2',
    name: 'Офис «Демо Сити»',
    address: 'Белград, Дорчол',
    type: 'office',
    lat: 44.8150,
    lng: 20.4500);
final noCoords =
    Obj(id: 'o3', name: 'Склад', address: 'Белград', type: 'warehouse');
final objects = [demo, far, noCoords];

void main() {
  group('Место новой заявки', () {
    test('без контекста и GPS — пусто (прошлая заявка не подставляется)', () {
      final p = initialOrderPlace(objects: objects);
      expect(p.objectId, isNull);
      expect(p.locationId, isNull);
      expect(p.source, PlaceSource.none);
    });

    test('контекст важнее GPS', () {
      final near = nearestObject(objects, 44.80471, 20.44942)!;
      final p = initialOrderPlace(
          objects: objects,
          contextObjectId: 'o2',
          contextLocationId: 'room-1',
          origin: PlaceOrigin.plan,
          nearby: near);
      expect(p.objectId, 'o2');
      expect(p.locationId, 'room-1');
      expect(p.source, PlaceSource.context);
      expect(p.origin, PlaceOrigin.plan);
    });

    test('чужой / невидимый объект контекста не подставляется', () {
      final p = initialOrderPlace(objects: objects, contextObjectId: 'x');
      expect(p.source, PlaceSource.none);
    });

    test('GPS ≤ 200 м — ближайший объект, без помещения', () {
      // ~40 м к северу от «БЦ «Демо»».
      final near = nearestObject(objects, 44.80507, 20.44942);
      expect(near?.object.id, 'o1');
      expect(near!.distanceM, inInclusiveRange(35, 45));
      final p = initialOrderPlace(objects: objects, nearby: near);
      expect(p.objectId, 'o1');
      expect(p.locationId, isNull);
      expect(p.source, PlaceSource.gps);
      expect(p.distanceM, near.distanceM);
    });

    test('GPS дальше 200 м — не подставляется', () {
      // ~330 м от «БЦ «Демо»», далеко от остальных.
      expect(nearestObject(objects, 44.80771, 20.44942), isNull);
      // Подсунутый «далёкий» результат тоже отбрасывается.
      final p = initialOrderPlace(
          objects: objects, nearby: NearbyObject(demo, 350));
      expect(p.source, PlaceSource.none);
    });

    test('отказ в геопозиции (нет точки) — форма пустая, без ошибок', () {
      final p = initialOrderPlace(objects: objects, nearby: null);
      expect(p, same(InitialPlace.empty));
    });

    test('объекты без координат не участвуют', () {
      expect(nearestObject([noCoords], 44.80471, 20.44942), isNull);
    });

    test('«Недавние» — до 3 разных видимых объектов, новые первыми', () {
      final r = recentObjects(['o2', 'o2', null, 'x', 'o1', 'o3', 'o1'],
          objects);
      expect([for (final o in r) o.id], ['o2', 'o1', 'o3']);
      expect(recentObjects(const [], objects), isEmpty);
    });
  });
}
