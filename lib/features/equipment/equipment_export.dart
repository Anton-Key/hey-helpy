import 'package:flutter/widgets.dart' show Locale;

import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import 'asset_place.dart';
import 'equipment_import.dart';
import 'equipment_kinds.dart';
import 'equipment_models.dart';

// =====================================================================
// Выгрузка реестра оборудования (шаг 27, блок 9) — чистые функции, без
// пакета excel (его грузит отложенно equipment_xlsx.dart). Формат — тот
// же, что шаблон импорта, плюс «Точка на плане», «Объект» и «ID»: файл
// можно поправить и загрузить обратно импортом (строки с ID обновляют своё
// оборудование). Тесты — test/equipment_export_test.dart.
// =====================================================================

/// Единица оборудования для выгрузки: помещение («305 · Переговорная») и
/// объект («Москва · Офис 1») — как их понимает импорт.
class ExportItem {
  const ExportItem({required this.asset, this.roomText, this.objectName});
  final Asset asset;
  final String? roomText;
  final String? objectName;
}

/// Заголовок выгрузки на языке [locale]: колонки шаблона + колонки выгрузки.
List<String> exportHeader(String locale) {
  final lang = _lang(locale);
  return [
    for (final c in ImportColumn.values) templateHeaders[lang]![c]!,
    for (final c in ExtraColumn.values) exportExtraHeaders[lang]![c]!,
  ];
}

String _lang(String locale) =>
    templateHeaders.containsKey(locale) ? locale : 'en';

/// Строки выгрузки (первая — заголовок). Система — название на языке
/// [locale], вид и «где именно» — подписи (импорт понимает и коды, и
/// подписи RU / EN), даты — «ГГГГ-ММ-ДД», высота — «2,8» / «2.8».
List<List<String>> buildExportRows(List<ExportItem> items,
    {required String locale, required List<Layer> layers}) {
  final lang = _lang(locale);
  final l = lookupAppLocalizations(Locale(lang));
  final (yes, no) = exportYesNo[lang]!;
  String system(String? id) {
    if (id == null) return '';
    for (final y in layers) {
      if (y.id == id) return y.label(lang);
    }
    return '';
  }

  List<String> row(ExportItem e) {
    final a = e.asset;
    final m = a.mount;
    final v = <ImportColumn, String>{
      ImportColumn.name: a.name,
      ImportColumn.system: system(a.layerId),
      ImportColumn.room: e.roomText ?? '',
      ImportColumn.inventoryNo: a.inventoryNo ?? '',
      ImportColumn.manufacturer: a.manufacturer ?? '',
      ImportColumn.model: a.model ?? '',
      ImportColumn.serialNo: a.serialNo ?? '',
      ImportColumn.installedAt:
          a.installedAt == null ? '' : isoDate(a.installedAt!),
      ImportColumn.kind: a.kind == null || equipmentKind(a.kind) == null
          ? ''
          : equipmentKindLabel(l, a.kind!),
      ImportColumn.mount: m.mount == null ? '' : mountLabel(l, m.mount!),
      ImportColumn.heightM:
          m.heightM == null ? '' : formatHeightNumber(m.heightM!, lang),
      ImportColumn.landmark: m.landmark ?? '',
    };
    return [
      for (final c in ImportColumn.values) v[c]!,
      a.placed ? yes : no,
      e.objectName ?? '',
      a.id,
    ];
  }

  return [exportHeader(lang), for (final e in items) row(e)];
}

/// Имя файла выгрузки без запрещённых символов: «Оборудование — Москва ·
/// Офис 1» → «Оборудование - Москва - Офис 1».
String exportFileBase(String title) {
  final t = title
      .replaceAll(RegExp(r'[\\/:*?"<>|·—–]+'), '-')
      .replaceAll(RegExp(r'\s*-\s*'), ' - ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final cut = t.length > 80 ? t.substring(0, 80).trim() : t;
  return cut.isEmpty ? 'equipment' : cut;
}
