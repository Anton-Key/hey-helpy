import 'package:supabase_flutter/supabase_flutter.dart';

/// Сервер отдаёт не больше 1000 строк за раз — читаем страницами.
/// [query] должен задавать устойчивый порядок (order по id в конце).
Future<List<Map<String, dynamic>>> fetchAll(
    PostgrestTransformBuilder<PostgrestList> Function() query,
    {int page = 1000}) async {
  final out = <Map<String, dynamic>>[];
  for (var start = 0;; start += page) {
    final rows = await query().range(start, start + page - 1);
    out.addAll(rows);
    if (rows.length < page) return out;
  }
}

/// Делит список id на порции, чтобы адрес запроса не стал слишком длинным.
Iterable<List<String>> chunks(List<String> ids, [int size = 100]) sync* {
  for (var i = 0; i < ids.length; i += size) {
    yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
  }
}
