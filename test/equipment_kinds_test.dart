import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/equipment/equipment_import.dart';
import 'package:hey_helpy/features/equipment/equipment_kinds.dart';
import 'package:hey_helpy/features/equipment/equipment_models.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Каталог видов в `_shared/kinds.ts` (по нему модель выбирает вид на фото):
/// код, подпись RU, подпись EN, система по умолчанию.
List<(String, String, String, String?)> _tsKinds() {
  final src = File('supabase/functions/_shared/kinds.ts').readAsStringSync();
  final re = RegExp(
      r'code: "([a-z_]+)",\s*ru: "([^"]+)",\s*en: "([^"]+)",\s*layer: (null|"[^"]+")');
  return [
    for (final m in re.allMatches(src))
      (
        m[1]!,
        m[2]!,
        m[3]!,
        m[4] == 'null' ? null : m[4]!.substring(1, m[4]!.length - 1)
      )
  ];
}

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('каталог видов: приложение = функция', () {
    final ts = _tsKinds();

    test('те же коды в том же порядке', () {
      expect(ts, isNotEmpty);
      expect([for (final k in kEquipmentKinds) k.code],
          [for (final k in ts) k.$1]);
    });

    test('подписи RU / EN совпадают с .arb', () {
      for (final (code, r, e, _) in ts) {
        expect(equipmentKindLabel(ru, code), r, reason: code);
        expect(equipmentKindLabel(en, code), e, reason: code);
      }
    });

    test('система по умолчанию совпадает', () {
      for (final (code, _, _, layer) in ts) {
        expect(equipmentKind(code)!.layerEn, layer, reason: code);
      }
    });

    test('все виды из задания есть, у каждого свой значок', () {
      const required = [
        'ac', 'ac_outdoor', 'vent_grille', 'radiator', 'panel', 'light',
        'socket', 'smoke', 'extinguisher', 'camera', 'access_reader',
        'door_lock', 'faucet', 'toilet', 'water_heater', 'ups', 'server',
        'lift_panel', 'other' //
      ];
      for (final c in required) {
        expect(equipmentKind(c), isNotNull, reason: c);
      }
      expect(kEquipmentKinds.last.code, 'other');
    });
  });

  test('старые коды и подписи → код каталога', () {
    expect(equipmentKind('vent')!.code, 'vent_grille');
    expect(equipmentKind('lift')!.code, 'lift_panel');
    expect(equipmentKind('generator')!.code, 'panel');
    expect(equipmentKind(' AC ')!.code, 'ac');
    expect(equipmentKind('nonsense'), isNull);
    expect(kindFromText('Датчик дыма', [ru, en]), 'smoke');
    expect(kindFromText('fire extinguisher', [ru, en]), 'extinguisher');
    expect(kindFromText('Вентиляционная решетка', [ru, en]), 'vent_grille',
        reason: 'ё = е');
    expect(kindFromText('чайник', [ru, en]), isNull);
  });

  test('система по умолчанию — слой компании по английскому названию', () {
    const layers = [
      Layer(id: 'l1', name: 'Климат', names: {'ru': 'Климат', 'en': 'HVAC'}),
      Layer(id: 'l2', name: 'Электрика', names: {'en': 'Electrical'}),
    ];
    expect(defaultLayerForKind('ac', layers)?.id, 'l1');
    expect(defaultLayerForKind('ups', layers)?.id, 'l2');
    expect(defaultLayerForKind('smoke', layers), isNull);
    expect(defaultLayerForKind('other', layers), isNull);
  });

  test('значок: по виду, иначе по категории', () {
    expect(assetIcon('ac', 'equipment'), AppIcons.eqAirCon);
    expect(assetIcon('vent', 'equipment'), AppIcons.eqVent);
    expect(assetIcon('extinguisher', 'infra'), AppIcons.eqExtinguisher);
    expect(assetIcon('other', 'furniture'), AppIcons.eqFurniture);
    expect(assetIcon(null, 'equipment'), AppIcons.wrench);
  });

  test('вид пишется в meta, остальные ключи сохраняются', () {
    const d = AssetDraft(
        name: 'КД-301',
        locationId: 'loc',
        kind: 'ac',
        baseMeta: {'demo': true, 'kind': 'fancoil'});
    expect(d.toRow()['meta'], {'demo': true, 'kind': 'ac'});
    const cleared =
        AssetDraft(name: 'x', locationId: 'loc', baseMeta: {'kind': 'ac'});
    expect(cleared.toRow()['meta'], <String, dynamic>{});
  });

  group('импорт: колонка «Вид»', () {
    final places = [
      Place(id: 'p1', objectId: 'o', name: 'Переговорная', code: '301'),
    ];
    final names = kindNamesFor([
      (c) => equipmentKindLabel(ru, c),
      (c) => equipmentKindLabel(en, c),
    ]);

    test('подпись RU / EN или код; неизвестный — ошибка строки', () {
      final p = validateImport(
          [
            ['Название*', 'Помещение*', 'Вид'],
            ['КД-301', '301', 'Кондиционер, внутренний блок'],
            ['Огнетушитель', '301', 'Fire extinguisher'],
            ['Датчик', '301', 'smoke'],
            ['Чайник', '301', 'чайник'],
            ['Без вида', '301', ''],
          ],
          places: places,
          layers: const [],
          kindNames: names);
      expect([for (final r in p.rows) r.kind],
          ['ac', 'extinguisher', 'smoke', null, null]);
      expect(p.rows[3].issues, {ImportIssue.unknownKind});
      expect(p.rows[3].kindText, 'чайник');
      expect(p.rows[4].issues, isEmpty);
      expect(p.rows[0].draft('p1').toRow()['meta'], {'kind': 'ac'});
    });

    test('английский заголовок «Type»', () {
      expect(mapHeaders(['Name', 'Room', 'Type'])[ImportColumn.kind], 2);
    });
  });
}
