import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/access/zone_logic.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/regions/region.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Obj obj(String id, String name, String city, String country, String? region) =>
    Obj(
        id: id,
        name: name,
        type: 'office',
        city: city,
        countryCode: country,
        regionId: region);

final objects = [
  obj('m1', 'Офис 1', 'Москва', 'RU', 'cis'),
  obj('m2', 'Офис 2', 'Москва', 'RU', 'cis'),
  obj('b1', 'Офис 1', 'Пекин', 'CN', 'asia'),
  obj('s1', 'Офис 1', 'Шэньчжэнь', 'CN', 'asia'),
  obj('s2', 'Офис 2', 'Шэньчжэнь', 'CN', 'asia'),
  obj('bg', 'БЦ', 'Белград', 'RS', 'eu'),
];
const regions = [
  Region(id: 'eu', name: 'Европа', sort: 1),
  Region(id: 'cis', name: 'СНГ', sort: 2),
  Region(id: 'asia', name: 'Азия', sort: 3),
];
const layers = [
  Layer(id: 'hvac', name: 'Климат'),
  Layer(id: 'plumb', name: 'Сантехника'),
  Layer(id: 'elec', name: 'Электрика'),
];

ZoneNames names(AppLocalizations l) => ZoneNames(
      locale: l.localeName,
      allSystems: l.zoneAllSystems,
      wholeCompany: l.zoneWholeCompany,
      objectsCount: l.objectsCount,
      layers: layers,
      regions: regions,
      objects: objects,
      floorNames: const {'f3': '3 этаж'},
      floorObject: const {'f3': 'm1'},
      assetNames: const {'a1': 'ИБП серверной'},
      assetObject: const {'a1': 'bg'},
    );

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));

  group('Строки базы ↔ правила', () {
    test('из строки и обратно', () {
      final r = ZoneRow.fromMap({
        'layer_ids': ['plumb', 'hvac'],
        'scope_kind': 'city',
        'scope_ref': 'Москва'
      })!;
      expect(r.place, const ZonePlace(ZoneScope.city, 'Москва'));
      expect(r.toMap(), {
        'layer_ids': ['hvac', 'plumb'],
        'scope_kind': 'city',
        'scope_ref': 'Москва'
      });
      final c = ZoneRow.fromMap(
          {'layer_ids': [], 'scope_kind': 'company', 'scope_ref': 'x'})!;
      expect(c.place.ref, isNull);
      expect(c.toMap()['scope_ref'], isNull);
      expect(ZoneRow.fromMap({'scope_kind': 'planet'}), isNull);
    });

    test('одинаковые системы — одно правило; обратно — без дублей', () {
      final rows = [
        const ZoneRow(
            place: ZonePlace(ZoneScope.object, 'm1'),
            layerIds: {'hvac', 'plumb'}),
        const ZoneRow(
            place: ZonePlace(ZoneScope.object, 'm2'),
            layerIds: {'plumb', 'hvac'}),
        const ZoneRow(place: ZonePlace(ZoneScope.region, 'asia')),
      ];
      final rules = groupRules(rows);
      expect(rules.length, 2);
      expect(rules.first.places.length, 2);
      expect(rulesToRows([...rules, rules.first]).length, 3);
    });

    test('«вся компания»', () {
      expect(isWholeCompany(const []), isTrue);
      expect(
          isWholeCompany([const ZoneRow(place: ZonePlace.company())]), isTrue);
      expect(
          isWholeCompany([
            const ZoneRow(place: ZonePlace.company(), layerIds: {'hvac'})
          ]),
          isFalse);
      expect(
          isWholeCompany(
              [const ZoneRow(place: ZonePlace(ZoneScope.city, 'Москва'))]),
          isFalse);
    });

    test('шаблоны', () {
      expect(templateWholeCompany(), isEmpty);
      final s = templateOneSystem('hvac').single;
      expect(s.layerIds, {'hvac'});
      expect(s.places, [const ZonePlace.company()]);
      final r = templateRegion('asia').single;
      expect(r.allLayers, isTrue);
      expect(r.places, [const ZonePlace(ZoneScope.region, 'asia')]);
    });
  });

  group('Места', () {
    test('выбор объектов → регион, страна, город, объект', () {
      // Регион «Азия» = страна CN, «СНГ» = город Москва: берётся более
      // узкое место (шаг 18: «Весь город: Москва» не становится регионом).
      expect(placesFromSelection({'b1', 's1', 's2'}, objects, regions),
          [const ZonePlace(ZoneScope.country, 'CN')]);
      expect(placesFromSelection({'m1', 'm2'}, objects, regions),
          [const ZonePlace(ZoneScope.city, 'Москва')]);
      // Регион из двух стран — регион.
      final me = [
        ...objects,
        obj('d1', 'Офис 1', 'Дубай', 'AE', 'me'),
        obj('i1', 'Офис 1', 'Стамбул', 'TR', 'me'),
      ];
      expect(
          placesFromSelection({'d1', 'i1'}, me,
              [...regions, const Region(id: 'me', name: 'Ближний Восток', sort: 4)]),
          [const ZonePlace(ZoneScope.region, 'me')]);
      expect(placesFromSelection({'s1', 's2'}, objects, regions),
          [const ZonePlace(ZoneScope.city, 'Шэньчжэнь')]);
      expect(placesFromSelection({'s1', 'b1'}, objects, regions), [
        const ZonePlace(ZoneScope.object, 'b1'),
        const ZonePlace(ZoneScope.object, 's1'),
      ]);
      expect(
          placesFromSelection(
              {for (final o in objects) o.id}, objects, regions),
          [const ZonePlace.company()]);
      // Без регионов — страна целиком.
      expect(placesFromSelection({'b1', 's1', 's2'}, objects, const []),
          [const ZonePlace(ZoneScope.country, 'CN')]);
      expect(placesFromSelection(const {}, objects, regions), isEmpty);
    });

    test('места → выбранные объекты и покрытие', () {
      expect(
          selectionFromPlaces(
              [const ZonePlace(ZoneScope.city, 'шэньчжэнь')], objects),
          {'s1', 's2'});
      expect(
          coveredObjects([
            const ZonePlace(ZoneScope.region, 'cis'),
            const ZonePlace(ZoneScope.object, 'bg'),
          ], objects),
          3);
      expect(
          placeCovers(const ZonePlace(ZoneScope.floor, 'f3'), objects.first,
              floorObject: const {'f3': 'm1'}),
          isTrue);
    });
  });

  group('Сводка словами', () {
    final n = names(ru);

    test('системы × места (число объектов)', () {
      const rule = ZoneRule(
          layerIds: {'hvac', 'plumb'},
          places: [ZonePlace(ZoneScope.region, 'cis')]);
      expect(ruleSummary(rule, n), 'Климат, Сантехника · СНГ (2 объекта)');
      const city = ZoneRule(places: [ZonePlace(ZoneScope.city, 'Москва')]);
      expect(ruleSummary(city, n), 'Все системы · Москва (2 объекта)');
      const company =
          ZoneRule(layerIds: {'elec'}, places: [ZonePlace.company()]);
      expect(ruleSummary(company, n), 'Электрика · Вся компания');
    });

    test('страна, объект, этаж, оборудование', () {
      expect(placeText(const ZonePlace(ZoneScope.country, 'CN'), n), 'Китай');
      expect(placeText(const ZonePlace(ZoneScope.object, 'b1'), n),
          'Пекин · Офис 1');
      expect(placeText(const ZonePlace(ZoneScope.floor, 'f3'), n),
          'Москва · Офис 1 · 3 этаж');
      expect(placeText(const ZonePlace(ZoneScope.asset, 'a1'), n),
          'ИБП серверной');
    });

    test('таблетка роли: коротко; вся компания — null', () {
      expect(
          zonesShortText([
            const ZoneRow(
                place: ZonePlace(ZoneScope.city, 'Москва'), layerIds: {'hvac'}),
          ], n),
          'Климат, Москва');
      expect(
          zonesShortText(
              [const ZoneRow(place: ZonePlace(ZoneScope.region, 'asia'))], n),
          'Азия');
      expect(zonesShortText(const [], n), isNull);
    });
  });
}
