import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/equipment/equipment_import.dart';
import 'package:hey_helpy/features/equipment/equipment_xlsx.dart';

void main() {
  final places = [
    Place(id: 'p1', objectId: 'o', name: 'Переговорная', code: '305'),
    Place(id: 'p2', objectId: 'o', name: 'Серверная'),
    Place(id: 'p3', objectId: 'o', name: 'Холл, 1 этаж', code: '101'),
  ];
  const layers = [
    Layer(id: 'l1', name: 'Климат', names: {'ru': 'Климат', 'en': 'HVAC'}),
    Layer(id: 'l2', name: 'Электрика', names: {'en': 'Electrical'}),
  ];

  group('CSV', () {
    test('разделитель «;», кавычки, перевод строки в кавычках, BOM', () {
      final rows = parseCsv('﻿Название*;Помещение*\r\n'
          '"Кондиционер ""Daikin""";305\r\n'
          '"Щит;\nвводной";Серверная\r\n'
          '\r\n');
      expect(rows, [
        ['Название*', 'Помещение*'],
        ['Кондиционер "Daikin"', '305'],
        ['Щит;\nвводной', 'Серверная'],
      ]);
    });

    test('разделитель «,» и табуляция определяются сами', () {
      expect(parseCsv('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2']
      ]);
      expect(parseCsv('a\tb\n1\t2'), [
        ['a', 'b'],
        ['1', '2']
      ]);
    });

    test('Windows-1251 из старого Excel', () {
      // «Щит» в cp1251: Щ=0xD9, и=0xE8, т=0xF2
      final bytes = Uint8List.fromList([0xD9, 0xE8, 0xF2, 0x3B, 0x31]);
      expect(parseCsvBytes(bytes), [
        ['Щит', '1']
      ]);
    });
  });

  group('заголовки', () {
    test('русские и английские, регистр, «*», «ё» не важны', () {
      expect(mapHeaders(['НАЗВАНИЕ*', 'Система', 'помещение', 'Инв. номер']), {
        ImportColumn.name: 0,
        ImportColumn.system: 1,
        ImportColumn.room: 2,
        ImportColumn.inventoryNo: 3,
      });
      expect(mapHeaders(['Room', 'Name', 'Serial number', 'Installed on']), {
        ImportColumn.room: 0,
        ImportColumn.name: 1,
        ImportColumn.serialNo: 2,
        ImportColumn.installedAt: 3,
      });
    });

    test('нет обязательных колонок — ошибка файла, не строк', () {
      final p = validateImport([
        ['Модель', 'Система'],
        ['X', 'Климат']
      ], places: places, layers: layers);
      expect(p.missingColumns, [ImportColumn.name, ImportColumn.room]);
      expect(p.rows, isEmpty);
    });
  });

  group('проверка строк', () {
    final header = templateHeaders['ru']!.values.toList();

    test('шаблон с примером проходит без ошибок', () {
      final p = validateImport([header, templateExample['ru']!],
          places: places, layers: layers);
      expect(p.rows.single.issues, isEmpty);
      expect(p.rows.single.placeId, 'p1'); // по номеру 305
      expect(p.rows.single.layerId, 'l1');
      expect(p.rows.single.installedAt, DateTime(2024, 5, 1));
      expect(p.okCount(), 1);
    });

    test('ошибки по строкам: помещение, система, дубли, дата', () {
      final p = validateImport(
          [
            header,
            [
              'Кондиционер',
              'HVAC',
              'Переговорная',
              'INV-1',
              '',
              '',
              '',
              '01.05.2024'
            ],
            ['Щит', 'Лифты', 'Серверная', 'INV-2', '', '', '', ''],
            ['ИБП', '', 'Склад', 'INV-3', '', '', '', ''],
            ['Датчик', '', '', 'INV-3', '', '', '', '31.02.2024'],
            ['', 'Климат', '101', 'INV-9', '', '', '', ''],
            [
              'Фанкойл',
              'Климат',
              '305 · Переговорная',
              'OLD-1',
              '',
              '',
              '',
              ''
            ],
          ],
          places: places,
          layers: layers,
          existingInventory: {'old-1'});
      final issues = [for (final r in p.rows) r.issues];
      expect(issues[0], isEmpty);
      expect(p.rows[0].layerId, 'l1'); // по переводу «HVAC»
      expect(issues[1], {ImportIssue.unknownSystem});
      expect(
          issues[2], {ImportIssue.roomNotFound, ImportIssue.duplicateInFile});
      expect(issues[3], {
        ImportIssue.noRoom,
        ImportIssue.duplicateInFile,
        ImportIssue.badDate
      });
      expect(issues[4], {ImportIssue.noName});
      expect(issues[5], {ImportIssue.duplicateInDb});
      expect(p.rows.map((r) => r.line), [2, 3, 4, 5, 6, 7]);
      expect(p.okCount(), 1);
    });

    test('недостающее помещение можно создать', () {
      final p = validateImport([
        header,
        ['ИБП', '', 'Склад', '', '', '', '', ''],
        ['Щит', '', 'склад', '', '', '', '', ''],
        ['Насос', '', 'Подвал', '', '', '', '', ''],
      ], places: places, layers: layers);
      expect(p.okCount(), 0);
      expect(p.okCount(createRooms: true), 3);
      expect(p.missingRooms, ['Склад', 'Подвал']);
    });

    test('пустой файл', () {
      final p = validateImport(const [], places: places, layers: layers);
      expect(p.empty, isTrue);
    });
  });

  test('даты', () {
    expect(parseImportDate('2024-02-29'), DateTime(2024, 2, 29));
    expect(parseImportDate('2023-02-29'), isNull);
    expect(parseImportDate('5/6/2024'), DateTime(2024, 6, 5));
    expect(parseImportDate('2024-05-01T00:00:00.000Z'), DateTime(2024, 5, 1));
    expect(parseImportDate('вчера'), isNull);
  });

  test('помещение: номер, название, «номер · название»', () {
    expect(findPlace(places, '305')?.id, 'p1');
    expect(findPlace(places, ' серверная ')?.id, 'p2');
    expect(findPlace(places, '101 · Холл, 1 этаж')?.id, 'p3');
    expect(findPlace(places, 'Склад'), isNull);
  });

  test('шаблон xlsx читается обратно', () {
    final rows = parseXlsxBytes(buildTemplateXlsx('ru'));
    expect(rows.first, templateHeaders['ru']!.values.toList());
    expect(rows[1], templateExample['ru']);
    final p = validateImport(rows, places: places, layers: layers);
    expect(p.rows.single.issues, isEmpty);
  });

  test('шаблон csv — UTF-8 с BOM, «;»', () {
    final bytes = buildTemplateCsv('en');
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final rows = parseCsv(utf8.decode(bytes));
    expect(rows.first.first, 'Name*');
    expect(mapHeaders(rows.first).length, ImportColumn.values.length);
  });
}
