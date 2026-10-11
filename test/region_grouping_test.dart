import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/city.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/directory/object_picker.dart';
import 'package:hey_helpy/features/map/map_logic.dart';
import 'package:hey_helpy/features/regions/region.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Obj o(String id, String name,
        {String? address, String? city, String? cc, String? region}) =>
    Obj(
        id: id,
        name: name,
        address: address,
        type: 'office',
        city: city,
        countryCode: cc,
        regionId: region);

const europe = Region(id: 'eu', name: 'Европа', sort: 1);
const cis = Region(id: 'cis', name: 'СНГ', sort: 2);
const asia = Region(id: 'as', name: 'Азия', sort: 3);

final objects = [
  o('b1', 'Хаб 1', city: 'Белград', cc: 'RS', region: 'eu'),
  o('b2', 'Skyline', city: 'Белград', cc: 'RS', region: 'eu'),
  o('b3', 'БЦ «Демо»',
      address: 'Белград, Савски венац', cc: 'RS', region: 'eu'),
  for (var i = 1; i <= 5; i++)
    o('m$i', 'Офис $i', city: 'Москва', cc: 'RU', region: 'cis'),
  o('p1', 'Офис 1', city: 'Пекин', cc: 'CN', region: 'as'),
  o('s1', 'Офис 1', city: 'Шэньчжэнь', cc: 'CN', region: 'as'),
  o('s2', 'Офис 2', city: 'Шэньчжэнь', cc: 'CN', region: 'as'),
  o('x', 'Склад'),
];

void main() {
  test('cityName: поле города, иначе адрес', () {
    expect(objects[0].cityName, 'Белград');
    expect(objects[2].cityName, 'Белград');
    expect(objects.last.cityName, '');
    expect(objectDisplayName(objects[2]), 'Белград · БЦ «Демо»');
  });

  test('регион → страна → город; «Без региона» в конце', () {
    final g = groupObjectsByRegion(objects, [asia, cis, europe], 'ru')!;
    expect(
        [for (final r in g) r.region?.name], ['Европа', 'СНГ', 'Азия', null]);
    expect(g.first.count, 3);
    expect(g.first.countries.single.code, 'RS');
    expect(g.first.countries.single.cities.single.city, 'Белград');
    final asiaG = g[2];
    expect(asiaG.countries.single.code, 'CN');
    expect([for (final c in asiaG.countries.single.cities) c.city],
        ['Пекин', 'Шэньчжэнь']);
    expect(g.last.countries.single.code, '');
  });

  test('без регионов — null (группировка по городам, как раньше)', () {
    expect(groupObjectsByRegion(objects, const [], 'ru'), isNull);
    expect(
        groupObjectsByRegion(
            [o('a', 'A', city: 'Москва')], const [europe], 'ru'),
        isNull);
    final cities = groupObjectsByCity(objects);
    expect(cities.first.city, 'Белград');
    expect(cities.first.items.length, 3);
  });

  group('Подпись выбора объектов с регионами', () {
    final l = lookupAppLocalizations(const Locale('ru'));
    const regions = [europe, cis, asia];
    String? label(Set<String> ids) =>
        objectsSelectionLabel(l, ids, objects, regions: regions);

    test('весь регион / город со страной / вся страна / один', () {
      expect(label({'b1', 'b2', 'b3'}), 'Европа (3)');
      expect(label({'m1', 'm2', 'm3', 'm4', 'm5'}), 'СНГ (5)');
      expect(label({'s1', 's2'}), 'Китай · Шэньчжэнь (2)');
      expect(label({'p1', 's1', 's2'}), 'Азия (3)');
      expect(label({'m1'}), 'Москва · Офис 1');
      expect(label({'m1', 'b1'}), 'Белград · Хаб 1 +1');
    });

    test('страна без региона целиком', () {
      final objs = [
        o('a', 'A', city: 'Москва', cc: 'RU', region: 'cis'),
        o('b', 'B', city: 'Казань', cc: 'RU', region: 'cis'),
        o('c', 'C', city: 'Алматы', cc: 'KZ', region: 'cis'),
      ];
      expect(objectsSelectionLabel(l, {'a', 'b'}, objs, regions: regions),
          'Россия (2)');
    });
  });

  test('объединение регионов: план переезда объектов', () {
    final plan = planRegionMerge(asia, europe, objects,
        regionOf: (Obj x) => x.regionId, idOf: (Obj x) => x.id);
    expect(plan.objectIds, ['p1', 's1', 's2']);
    expect(plan.count, 3);
    expect(plan.into.id, 'eu');
    expect(
        () => planRegionMerge(asia, asia, objects,
            regionOf: (Obj x) => x.regionId, idOf: (Obj x) => x.id),
        throwsArgumentError);
    expect(regionObjectCounts(objects, (Obj x) => x.regionId),
        {'eu': 3, 'cis': 5, 'as': 3});
  });

  test('порядок регионов: sort, затем название', () {
    final list = sortRegions(const [
      Region(id: '1', name: 'Б', sort: 2),
      Region(id: '2', name: 'А', sort: 2),
      Region(id: '3', name: 'Я', sort: 1),
    ]);
    expect([for (final r in list) r.id], ['3', '2', '1']);
  });

  test('чипы карты: регионы с объектами; без регионов — null', () {
    final chips =
        regionChips(objects, regionOf: (Obj x) => x.regionId, regions: [
      (id: 'eu', name: 'Европа'),
      (id: 'af', name: 'Африка'),
      (id: 'as', name: 'Азия'),
    ])!;
    expect([for (final c in chips) c.name], ['Европа', 'Азия']);
    expect(chips.first.items.length, 3);
    expect(regionChips(objects, regionOf: (Obj x) => x.regionId, regions: []),
        isNull);
    expect(
        regionChips([o('a', 'A')],
            regionOf: (Obj x) => x.regionId,
            regions: [(id: 'eu', name: 'Европа')]),
        isNull);
  });
}
