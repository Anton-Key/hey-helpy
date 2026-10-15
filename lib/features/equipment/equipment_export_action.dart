import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/file_share.dart';
import '../../core/l10n_ext.dart';
import '../directory/directory.dart';
import 'equipment_export.dart';
// Отложенно: пакет excel не попадает в первую загрузку веб-версии (шаг 18).
import 'equipment_xlsx.dart' deferred as xlsx;

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// «Выгрузить в Excel» (шаг 27): реестр [items] в .xlsx в формате шаблона
/// импорта. Веб — скачать файл, Android — «Поделиться». [title] — часть
/// имени файла (объект или система).
Future<void> exportEquipmentXlsx(
  BuildContext context, {
  required List<ExportItem> items,
  required List<Layer> layers,
  required String title,
}) async {
  final l = context.l10n;
  if (items.isEmpty) {
    showAppMessage(context, l.eqExportEmpty);
    return;
  }
  final locale = context.localeCode;
  try {
    await xlsx.loadLibrary();
    final rows = buildExportRows(items, locale: locale, layers: layers);
    final bytes =
        xlsx.buildRowsXlsx(rows, sheetName: l.importTemplateSheetName);
    final name = '${exportFileBase('${l.eqExportFileName} - $title')}.xlsx';
    final done =
        await saveOrShareBytes(bytes: bytes, fileName: name, mime: _xlsxMime);
    if (done && context.mounted) {
      showAppMessage(context, l.eqExportDone, type: AppMessageType.success);
    }
  } catch (e) {
    debugPrint('Equipment export: ${e.runtimeType}');
    if (context.mounted) {
      showAppMessage(context, l.eqExportFailed, type: AppMessageType.error);
    }
  }
}
