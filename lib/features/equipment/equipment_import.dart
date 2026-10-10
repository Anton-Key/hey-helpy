import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../directory/directory.dart';
import 'equipment_models.dart';

/// Импорт оборудования из Excel / CSV (шаг 16): чтение файла, разбор
/// заголовков (RU / EN), проверка строк. Всё — чистые функции, без сети;
/// тесты — `test/equipment_import_test.dart`.

/// Колонка файла импорта.
enum ImportColumn {
  name,
  system,
  room,
  inventoryNo,
  manufacturer,
  model,
  serialNo,
  installedAt,
}

/// Заголовки шаблона: по языку интерфейса.
const templateHeaders = {
  'ru': {
    ImportColumn.name: 'Название*',
    ImportColumn.system: 'Система',
    ImportColumn.room: 'Помещение*',
    ImportColumn.inventoryNo: 'Инвентарный номер',
    ImportColumn.manufacturer: 'Производитель',
    ImportColumn.model: 'Модель',
    ImportColumn.serialNo: 'Серийный номер',
    ImportColumn.installedAt: 'Дата ввода',
  },
  'en': {
    ImportColumn.name: 'Name*',
    ImportColumn.system: 'System',
    ImportColumn.room: 'Room*',
    ImportColumn.inventoryNo: 'Inventory number',
    ImportColumn.manufacturer: 'Manufacturer',
    ImportColumn.model: 'Model',
    ImportColumn.serialNo: 'Serial number',
    ImportColumn.installedAt: 'Installed on',
  },
};

/// Строка-пример в шаблоне.
const templateExample = {
  'ru': [
    'Кондиционер переговорной',
    'Климат',
    '305',
    'КЛ-3-001',
    'Daikin',
    'FTXM35R',
    'DK-E0412233',
    '2024-05-01'
  ],
  'en': [
    'Meeting room air conditioner',
    'HVAC',
    '305',
    'AC-3-001',
    'Daikin',
    'FTXM35R',
    'DK-E0412233',
    '2024-05-01'
  ],
};

/// Все варианты подписей колонки (без регистра, «*», «ё»).
const _synonyms = {
  ImportColumn.name: [
    'название',
    'наименование',
    'оборудование',
    'name',
    'equipment',
    'asset'
  ],
  ImportColumn.system: [
    'система',
    'слой',
    'вид работ',
    'system',
    'layer',
    'work type'
  ],
  ImportColumn.room: [
    'помещение',
    'номер помещения',
    'комната',
    'room',
    'location',
    'place'
  ],
  ImportColumn.inventoryNo: [
    'инвентарный номер',
    'инв. номер',
    'инв номер',
    'инвентарный №',
    'inventory number',
    'inventory no',
    'inventory',
    'inv no'
  ],
  ImportColumn.manufacturer: [
    'производитель',
    'марка',
    'manufacturer',
    'brand',
    'make'
  ],
  ImportColumn.model: ['модель', 'model'],
  ImportColumn.serialNo: [
    'серийный номер',
    'серийный №',
    'с/н',
    'serial number',
    'serial no',
    'serial'
  ],
  ImportColumn.installedAt: [
    'дата ввода',
    'дата ввода в эксплуатацию',
    'введено',
    'дата установки',
    'installed on',
    'installed',
    'install date',
    'installation date'
  ],
};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll('*', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Номера колонок по строке заголовков. Неизвестные колонки пропускаются.
Map<ImportColumn, int> mapHeaders(List<String> header) {
  final out = <ImportColumn, int>{};
  for (var i = 0; i < header.length; i++) {
    final h = _norm(header[i]);
    if (h.isEmpty) continue;
    for (final e in _synonyms.entries) {
      if (out.containsKey(e.key)) continue;
      if (e.value.contains(h)) {
        out[e.key] = i;
        break;
      }
    }
  }
  return out;
}

/// Разбор CSV: разделитель «;», «,» или табуляция (по первой строке),
/// кавычки ("" внутри — одна кавычка), перевод строки внутри кавычек,
/// BOM в начале. Пустые строки пропускаются.
List<List<String>> parseCsv(String text) {
  var s = text;
  if (s.startsWith('﻿')) s = s.substring(1);
  final delimiter = _detectDelimiter(s);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var i = 0;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  while (i < s.length) {
    final ch = s[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        quoted = false;
      } else {
        cell.write(ch);
      }
    } else if (ch == '"' && cell.toString().trim().isEmpty) {
      cell.clear();
      quoted = true;
    } else if (ch == delimiter) {
      endCell();
    } else if (ch == '\r') {
      // \r\n — конец строки на \n
    } else if (ch == '\n') {
      endRow();
    } else {
      cell.write(ch);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return [
    for (final r in rows) [for (final c in r) c.trim()]
  ];
}

String _detectDelimiter(String s) {
  final end = s.indexOf('\n');
  final first = end < 0 ? s : s.substring(0, end);
  int count(String d) {
    var n = 0;
    var q = false;
    for (final ch in first.split('')) {
      if (ch == '"') q = !q;
      if (!q && ch == d) n++;
    }
    return n;
  }

  final candidates = {';': count(';'), ',': count(','), '\t': count('\t')};
  var best = ';';
  var bestN = -1;
  for (final e in candidates.entries) {
    if (e.value > bestN) {
      best = e.key;
      bestN = e.value;
    }
  }
  return best;
}

/// Байты CSV → строки (UTF-8; если не UTF-8 — Windows-1251 из Excel).
List<List<String>> parseCsvBytes(Uint8List bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    text = _decodeCp1251(bytes);
  }
  return parseCsv(text);
}

String _decodeCp1251(Uint8List bytes) {
  final b = StringBuffer();
  for (final x in bytes) {
    if (x < 0x80) {
      b.writeCharCode(x);
    } else if (x >= 0xC0) {
      b.writeCharCode(0x410 + x - 0xC0); // А…я
    } else if (x == 0xA8) {
      b.write('Ё');
    } else if (x == 0xB8) {
      b.write('ё');
    } else {
      b.write(' ');
    }
  }
  return b.toString();
}

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

/// Шаблон .csv (разделитель «;», UTF-8 с BOM — так его правильно открывает Excel).
Uint8List buildTemplateCsv(String locale) {
  final lang = templateHeaders.containsKey(locale) ? locale : 'en';
  String q(String v) =>
      v.contains(RegExp('[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  final lines = [
    [for (final c in ImportColumn.values) q(templateHeaders[lang]![c]!)]
        .join(';'),
    [for (final v in templateExample[lang]!) q(v)].join(';'),
  ];
  return Uint8List.fromList(utf8.encode('﻿${lines.join('\r\n')}\r\n'));
}

/// Что не так со строкой.
enum ImportIssue {
  /// Нет названия.
  noName,

  /// Не указано помещение.
  noRoom,

  /// Помещения нет в объекте (можно создать).
  roomNotFound,

  /// Такой системы (слоя) нет.
  unknownSystem,

  /// Инвентарный номер повторяется в файле.
  duplicateInFile,

  /// Инвентарный номер уже есть в базе.
  duplicateInDb,

  /// Дата не распознана.
  badDate,

  /// Слишком длинное значение (больше 120 символов).
  tooLong,
}

/// Строка импорта после проверки.
class ImportRow {
  ImportRow({
    required this.line,
    required this.name,
    required this.roomText,
    this.placeId,
    this.layerId,
    this.systemText = '',
    this.inventoryNo,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.installedAt,
    required this.issues,
  });

  /// Номер строки в файле (с 1, заголовок — строка 1).
  final int line;
  final String name;
  final String roomText;
  final String? placeId;
  final String? layerId;
  final String systemText;
  final String? inventoryNo;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final DateTime? installedAt;
  final Set<ImportIssue> issues;

  /// Можно импортировать: ошибок нет, кроме «нет помещения», если
  /// разрешено создать недостающие помещения.
  bool ok({bool createRooms = false}) =>
      issues.isEmpty ||
      (createRooms &&
          issues.length == 1 &&
          issues.contains(ImportIssue.roomNotFound));

  AssetDraft draft(String locationId) => AssetDraft(
        name: name,
        locationId: locationId,
        layerId: layerId,
        inventoryNo: inventoryNo,
        manufacturer: manufacturer,
        model: model,
        serialNo: serialNo,
        installedAt: installedAt,
      );
}

/// Итог проверки файла.
class ImportPreview {
  const ImportPreview(
      {required this.rows, required this.missingColumns, this.empty = false});
  final List<ImportRow> rows;

  /// Обязательные колонки, которых нет в заголовке (название, помещение).
  final List<ImportColumn> missingColumns;

  /// В файле нет строк с данными.
  final bool empty;

  int okCount({bool createRooms = false}) =>
      rows.where((r) => r.ok(createRooms: createRooms)).length;

  /// Названия помещений, которых нет в объекте (у строк без других ошибок).
  List<String> get missingRooms {
    final seen = <String>{};
    final out = <String>[];
    for (final r in rows) {
      if (r.issues.length == 1 &&
          r.issues.contains(ImportIssue.roomNotFound) &&
          seen.add(_norm(r.roomText))) {
        out.add(r.roomText);
      }
    }
    return out;
  }
}

/// Дата: «2024-05-01», «01.05.2024», «01/05/2024», «2024-05-01T00:00:00».
DateTime? parseImportDate(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
  final dmy = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})$').firstMatch(t);
  int? y, m, d;
  if (iso != null) {
    y = int.parse(iso[1]!);
    m = int.parse(iso[2]!);
    d = int.parse(iso[3]!);
  } else if (dmy != null) {
    d = int.parse(dmy[1]!);
    m = int.parse(dmy[2]!);
    y = int.parse(dmy[3]!);
  } else {
    return null;
  }
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) return null;
  final dt = DateTime(y, m, d);
  if (dt.month != m || dt.day != d) return null; // 31.02 и т. п.
  return dt;
}

/// Помещение объекта по тексту: номер («305»), название («Переговорная»)
/// или подпись «305 · Переговорная».
Place? findPlace(List<Place> places, String text) {
  final t = _norm(text);
  if (t.isEmpty) return null;
  for (final p in places) {
    if (p.code != null && _norm(p.code!) == t) return p;
  }
  for (final p in places) {
    if (_norm(p.name) == t || _norm(p.label) == t) return p;
  }
  return null;
}

/// Проверка строк файла. [rows] — все строки, первая — заголовок.
/// [existingInventory] — инвентарные номера, уже занятые в компании.
ImportPreview validateImport(
  List<List<String>> rows, {
  required List<Place> places,
  required List<Layer> layers,
  Set<String> existingInventory = const {},
}) {
  if (rows.isEmpty) {
    return const ImportPreview(
        rows: [],
        missingColumns: [ImportColumn.name, ImportColumn.room],
        empty: true);
  }
  final cols = mapHeaders(rows.first);
  final missing = [
    for (final c in const [ImportColumn.name, ImportColumn.room])
      if (!cols.containsKey(c)) c
  ];
  if (missing.isNotEmpty) {
    return ImportPreview(rows: const [], missingColumns: missing);
  }
  final taken = {for (final i in existingInventory) _norm(i)};
  final inFile = <String, int>{};
  for (var i = 1; i < rows.length; i++) {
    final v = _get(rows[i], cols[ImportColumn.inventoryNo]);
    if (v.isNotEmpty) inFile[_norm(v)] = (inFile[_norm(v)] ?? 0) + 1;
  }

  final out = <ImportRow>[];
  for (var i = 1; i < rows.length; i++) {
    final r = rows[i];
    String get(ImportColumn c) => _get(r, cols[c]);
    final issues = <ImportIssue>{};
    final name = get(ImportColumn.name);
    if (name.isEmpty) issues.add(ImportIssue.noName);

    final roomText = get(ImportColumn.room);
    Place? place;
    if (roomText.isEmpty) {
      issues.add(ImportIssue.noRoom);
    } else {
      place = findPlace(places, roomText);
      if (place == null) issues.add(ImportIssue.roomNotFound);
    }

    final system = get(ImportColumn.system);
    String? layerId;
    if (system.isNotEmpty) {
      layerId = Layer.find(layers, name: system)?.id;
      if (layerId == null) issues.add(ImportIssue.unknownSystem);
    }

    final inv = get(ImportColumn.inventoryNo);
    if (inv.isNotEmpty) {
      if ((inFile[_norm(inv)] ?? 0) > 1) {
        issues.add(ImportIssue.duplicateInFile);
      }
      if (taken.contains(_norm(inv))) issues.add(ImportIssue.duplicateInDb);
    }

    final dateText = get(ImportColumn.installedAt);
    final date = parseImportDate(dateText);
    if (dateText.isNotEmpty && date == null) issues.add(ImportIssue.badDate);

    String? opt(ImportColumn c) {
      final v = get(c);
      return v.isEmpty ? null : v;
    }

    final values = [
      name,
      inv,
      get(ImportColumn.manufacturer),
      get(ImportColumn.model),
      get(ImportColumn.serialNo)
    ];
    if (values.any((v) => v.length > 120)) issues.add(ImportIssue.tooLong);

    out.add(ImportRow(
      line: i + 1,
      name: name,
      roomText: roomText,
      placeId: place?.id,
      layerId: layerId,
      systemText: system,
      inventoryNo: opt(ImportColumn.inventoryNo),
      manufacturer: opt(ImportColumn.manufacturer),
      model: opt(ImportColumn.model),
      serialNo: opt(ImportColumn.serialNo),
      installedAt: date,
      issues: issues,
    ));
  }
  return ImportPreview(rows: out, missingColumns: const []);
}

String _get(List<String> row, int? i) =>
    i == null || i >= row.length ? '' : row[i].trim();

/// Ключ для сравнения названий помещений при создании недостающих.
String importRoomKey(String s) => _norm(s);
