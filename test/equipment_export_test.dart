import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/equipment/asset_place.dart';
import 'package:hey_helpy/features/equipment/equipment_export.dart';
import 'package:hey_helpy/features/equipment/equipment_import.dart';
import 'package:hey_helpy/features/equipment/equipment_models.dart';
import 'package:hey_helpy/features/equipment/equipment_xlsx.dart';

void main() {
  final places = [
    Place(id: 'p301', objectId: 'o1', name: 'Переговорная', code: '301'),
    Place(id: 'p302', objectId: 'o1', name: 'Кабинет', code: '302'),
  ];
  final layers = [
    Layer.fromMap({
      'id': 'l-hvac',
      'name': 'Климат',
      'name_i18n': {'ru': 'Климат', 'en': 'HVAC'}
    }),
    Layer.fromMap({
      'id': 'l-el',
      'name': 'Электрика',
      'name_i18n': {'ru': 'Электрика', 'en': 'Electrical'}
    }),
  ];
  const objectName = 'Белград · БЦ «Демо»';

  final a1 = Asset.fromMap({
    'id': 'de300000-0000-4000-8000-000000000708',
    'location_id': 'p301',
    'name': 'Кондиционер КД-301',
    'category': 'equipment',
    'inventory_no': 'КЛ-3-001',
    'meta': {
      'kind': 'ac',
      'mount': 'ceiling',
      'height_m': 2.8,
      'landmark': 'над дверью, слева',
      'extra': 'сохраняется',
    },
    'floor_id': 'f3',
    'plan_x': 0.21,
    'plan_y': 0.33,
    'layer_id': 'l-hvac',
    'manufacturer': 'Daikin',
    'model': 'FTXM35R',
    'serial_no': 'DK-E0412233',
    'installed_at': '2024-05-01',
  });
  final a2 = Asset.fromMap({
    'id': 'de300000-0000-4000-8000-000000000736',
    'location_id': 'p302',
    'name': 'Щиток',
    'category': 'equipment',
    'meta': {'mount': 'cabinet'},
    'layer_id': 'l-el',
  });
  final items = [
    ExportItem(asset: a1, roomText: places[0].label, objectName: objectName),
    ExportItem(asset: a2, roomText: places[1].label, objectName: objectName),
  ];

  void expectSame(ImportRow r, Asset a) {
    final d = r.draft(r.placeId!, base: a);
    expect(r.issues, isEmpty, reason: 'строка ${r.line}: ${r.issues}');
    expect(r.updateId, a.id);
    expect(d.name, a.name);
    expect(d.locationId, a.locationId);
    expect(d.layerId, a.layerId);
    expect(d.inventoryNo, a.inventoryNo);
    expect(d.manufacturer, a.manufacturer);
    expect(d.model, a.model);
    expect(d.serialNo, a.serialNo);
    expect(d.installedAt, a.installedAt);
    expect(d.kind, a.kind);
    expect(d.meta, a.meta, reason: 'meta — те же ключи и значения');
  }

  for (final locale in ['ru', 'en']) {
    test('выгрузка ($locale) → разбор импортом → те же данные', () {
      final rows = buildExportRows(items, locale: locale, layers: layers);
      expect(rows.first, exportHeader(locale));
      final p = validateImport(rows,
          places: places,
          layers: layers,
          existingInventory: {'КЛ-3-001'},
          existing: [a1, a2],
          objectNames: {objectName});
      expect(p.missingColumns, isEmpty);
      expect(p.rows, hasLength(2));
      expectSame(p.rows[0], a1);
      expectSame(p.rows[1], a2);
      expect(p.updateCount(), 2);
    });
  }

  test('выгрузка: колонки и значения', () {
    final rows = buildExportRows(items, locale: 'ru', layers: layers);
    final h = rows.first;
    String cell(int row, String header) => rows[row][h.indexOf(header)];
    expect(cell(1, 'Система'), 'Климат');
    expect(cell(1, 'Помещение*'), '301 · Переговорная');
    expect(cell(1, 'Вид'), isNotEmpty);
    expect(cell(1, 'Где именно'), 'Потолок');
    expect(cell(1, 'Высота, м'), '2,8');
    expect(cell(1, 'Ориентир'), 'над дверью, слева');
    expect(cell(1, 'Точка на плане'), 'да');
    expect(cell(2, 'Точка на плане'), 'нет');
    expect(cell(1, 'Объект'), objectName);
    expect(cell(1, 'ID'), a1.id);
    expect(cell(1, 'Дата ввода'), '2024-05-01');
  });

  test('xlsx: выгрузка → чтение → импорт → те же данные', () {
    final rows = buildExportRows(items, locale: 'ru', layers: layers);
    final back = parseXlsxBytes(buildRowsXlsx(rows));
    expect(back.first, rows.first);
    final p = validateImport(back,
        places: places,
        layers: layers,
        existing: [a1, a2],
        objectNames: {objectName});
    expectSame(p.rows[0], a1);
    expectSame(p.rows[1], a2);
  });

  test('правка выгрузки: изменённое попадает в черновик, остальное — нет', () {
    final rows = buildExportRows(items, locale: 'ru', layers: layers);
    final h = rows.first;
    rows[1][h.indexOf('Высота, м')] = '3,1';
    rows[1][h.indexOf('Где именно')] = 'стена';
    rows[1][h.indexOf('Помещение*')] = '302';
    final p = validateImport(rows,
        places: places, layers: layers, existing: [a1, a2]);
    final d = p.rows[0].draft(p.rows[0].placeId!, base: a1, columns: p.columns);
    expect(d.locationId, 'p302');
    expect(d.meta['height_m'], 3.1);
    expect(d.meta['mount'], 'wall');
    expect(d.meta['extra'], 'сохраняется');
    expect(d.toRow().containsKey('plan_x'), isFalse,
        reason: 'точку на плане импорт не трогает');
  });

  test(
      'старый файл без новых колонок: импорт работает, обновление не '
      'стирает «где именно»', () {
    final old = [
      [
        'Название*',
        'Помещение*',
        'Инвентарный номер',
        'ID',
      ],
      ['Кондиционер КД-301', '301', 'КЛ-3-001', a1.id],
      ['Новый датчик', '302', '', ''],
    ];
    final p = validateImport(old,
        places: places,
        layers: layers,
        existingInventory: {'КЛ-3-001'},
        existing: [a1]);
    expect(p.rows.every((r) => r.issues.isEmpty), isTrue);
    expect(p.rows[0].updateId, a1.id);
    expect(p.rows[1].updateId, isNull);
    final d = p.rows[0].draft('p301', base: a1, columns: p.columns);
    expect(MountInfo.fromMeta(d.meta), a1.mount);
    expect(d.kind, 'ac');
    expect(d.layerId, 'l-hvac');
    expect(d.manufacturer, 'Daikin');
  });

  test('ошибки новых колонок и строка другого объекта', () {
    final rows = buildExportRows(items, locale: 'ru', layers: layers);
    final h = rows.first;
    rows[1][h.indexOf('Высота, м')] = 'высоко';
    rows[1][h.indexOf('Где именно')] = 'на крыше';
    rows[2][h.indexOf('Объект')] = 'Москва · Офис 1';
    final p = validateImport(rows,
        places: places,
        layers: layers,
        existing: [a1, a2],
        objectNames: {objectName});
    expect(p.rows[0].issues, {ImportIssue.badHeight, ImportIssue.unknownMount});
    expect(p.rows[1].issues, {ImportIssue.otherObject});
  });

  test('ID чужого объекта — строка добавится как новая', () {
    final rows = buildExportRows([items[0]], locale: 'ru', layers: layers);
    final p = validateImport(rows,
        places: places,
        layers: layers,
        existingInventory: {'КЛ-3-001'},
        existing: const []);
    expect(p.rows[0].updateId, isNull);
    expect(p.rows[0].issues, {ImportIssue.duplicateInDb});
  });

  test('имя файла без запрещённых символов', () {
    expect(exportFileBase('Оборудование - Москва · Офис 1'),
        'Оборудование - Москва - Офис 1');
    expect(exportFileBase('a/b:c'), 'a - b - c');
    expect(exportFileBase('  '), 'equipment');
  });
}
