import 'package:intl/intl.dart';

/// Документы заявки (шаг 24, миграция 0019): чистые функции.

/// Не больше 20 МБ — как у хранилища order-files.
const kMaxDocumentBytes = 20 * 1024 * 1024;

/// Расширение → тип файла. Тот же список разрешён в хранилище (0019).
const kDocumentTypes = <String, String>{
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'txt': 'text/plain',
};

List<String> get kDocumentExtensions => kDocumentTypes.keys.toList();

/// Вид документа — для значка.
enum DocKind { pdf, word, excel, image, text, other }

String extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// Тип файла по имени; null — такой файл приложить нельзя.
String? mimeForName(String name) => kDocumentTypes[extensionOf(name)];

DocKind docKindOf(String name, [String? mime]) {
  final m = mime ?? mimeForName(name) ?? '';
  if (m == 'application/pdf') return DocKind.pdf;
  if (m.contains('word')) return DocKind.word;
  if (m.contains('excel') || m.contains('spreadsheet')) return DocKind.excel;
  if (m.startsWith('image/')) return DocKind.image;
  if (m.startsWith('text/')) return DocKind.text;
  return DocKind.other;
}

enum DocProblem { empty, tooBig, badType }

/// Можно ли приложить файл: тип из списка, 1 байт … 20 МБ.
DocProblem? checkDocument(String name, int size) {
  if (mimeForName(name) == null) return DocProblem.badType;
  if (size <= 0) return DocProblem.empty;
  if (size > kMaxDocumentBytes) return DocProblem.tooBig;
  return null;
}

/// Безопасная часть имени для пути в хранилище: латиница, цифры и -_. —
/// остальное «_», подряд идущие «_» схлопываются, не длиннее 80 знаков,
/// расширение сохраняется. Имя для людей хранится отдельно, как есть.
String safeStorageName(String name) {
  final ext = extensionOf(name);
  var base =
      ext.isEmpty ? name : name.substring(0, name.length - ext.length - 1);
  base = base
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
  if (base.isEmpty) base = 'file';
  final max = 80 - (ext.isEmpty ? 0 : ext.length + 1);
  if (base.length > max) base = base.substring(0, max);
  return ext.isEmpty ? base : '$base.$ext';
}

/// Путь файла: <company_id>/<work_order_id>/<uuid>-<безопасное имя>.
String documentPath(
        String companyId, String workOrderId, String uuid, String name) =>
    '$companyId/$workOrderId/$uuid-${safeStorageName(name)}';

/// Имя для показа: обрезано до 200 знаков (как в базе), без пробелов по краям.
String displayFileName(String name) {
  final t = name.trim();
  return t.length <= 200 ? t : t.substring(0, 200);
}

/// «34 КБ», «1,2 МБ» — по языку интерфейса.
String formatFileSize(int bytes, String locale,
    {required String kb, required String mb}) {
  if (bytes < 1024 * 1024) {
    final k = (bytes / 1024).ceil().clamp(1, 1024);
    return '$k $kb';
  }
  final f = NumberFormat('0.#', locale);
  return '${f.format(bytes / (1024 * 1024))} $mb';
}
