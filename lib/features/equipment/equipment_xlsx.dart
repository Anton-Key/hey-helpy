import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'equipment_import.dart';
import 'equipment_models.dart';

// Чтение и шаблон .xlsx (пакет excel) — отдельно от разбора строк: экран
// импорта грузится отложенно, и пакет не попадает в первую загрузку
// веб-версии (шаг 18).

/// Первый лист книги Excel → строки (даты — «ГГГГ-ММ-ДД»).
List<List<String>> parseXlsxBytes(Uint8List bytes) {
  final book = Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) return const [];
  final sheet = book.tables.values.first;
  final out = <List<String>>[];
  for (final r in sheet.rows) {
    final cells = [for (final c in r) _cellText(c?.value)];
    if (cells.any((c) => c.isNotEmpty)) out.add(cells);
  }
  return out;
}

String _cellText(CellValue? v) => switch (v) {
      null => '',
      DateCellValue() => isoDate(DateTime(v.year, v.month, v.day)),
      DateTimeCellValue() => isoDate(DateTime(v.year, v.month, v.day)),
      DoubleCellValue(value: final d) when d == d.roundToDouble() =>
        d.toInt().toString(),
      _ => v.toString().trim(),
    };

/// Шаблон .xlsx: заголовки и строка-пример на языке [locale].
Uint8List buildTemplateXlsx(String locale) {
  final lang = templateHeaders.containsKey(locale) ? locale : 'en';
  final book = Excel.createExcel();
  final name = lang == 'ru' ? 'Оборудование' : 'Equipment';
  final first = book.getDefaultSheet() ?? book.tables.keys.first;
  book.rename(first, name);
  final sheet = book[name];
  sheet.appendRow([
    for (final c in ImportColumn.values)
      TextCellValue(templateHeaders[lang]![c]!)
  ]);
  sheet.appendRow([for (final v in templateExample[lang]!) TextCellValue(v)]);
  for (var i = 0; i < ImportColumn.values.length; i++) {
    sheet.setColumnWidth(i, 24);
  }
  return Uint8List.fromList(book.encode()!);
}

