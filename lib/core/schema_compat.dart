import 'package:supabase_flutter/supabase_flutter.dart';

/// Совместимость с базой, где ещё не применены новые миграции.
///
/// Приложение выходит раньше, чем пользователь применяет миграцию (Actions →
/// «Apply migration»). До этого новые таблицы, столбцы и функции в базе
/// отсутствуют, и запрос с ними падает. Поэтому новые запросы идут через
/// [SchemaCompat.run]: сначала «новый» вариант, при ошибке «нет такой
/// таблицы / столбца / функции» — старый вариант (или пусто), а экран
/// показывает «Нужна миграция NNNN».
class SchemaCompat {
  SchemaCompat._();

  /// Результат последней проверки по номеру миграции: true — есть,
  /// false — нет, отсутствует ключ — ещё не проверяли.
  static final Map<String, bool> _known = {};

  /// Применена ли миграция [number] (по последнему запросу). null — неизвестно.
  static bool? has(String number) => _known[number];

  /// Для тестов и при выходе из аккаунта (другая база).
  static void reset() => _known.clear();

  /// Отметить вручную (например, по ответу RPC).
  static void mark(String number, bool applied) => _known[number] = applied;

  /// Ошибка «в базе нет такой таблицы / столбца / связи / функции».
  static bool isMissing(Object error) {
    if (error is! PostgrestException) return false;
    const codes = {
      '42703', // undefined_column
      '42P01', // undefined_table
      '42883', // undefined_function
      'PGRST200', // нет связи между таблицами
      'PGRST202', // нет функции
      'PGRST204', // нет столбца (insert / update)
      'PGRST205', // нет таблицы
    };
    if (codes.contains(error.code)) return true;
    final m = error.message.toLowerCase();
    return m.contains('does not exist') ||
        m.contains('could not find') ||
        m.contains('schema cache');
  }

  /// Запрос, которому нужна миграция [number]. Если её нет — [legacy]
  /// (старый вариант запроса); без [legacy] ошибка пробрасывается как
  /// [MigrationMissing].
  static Future<T> run<T>(String number, Future<T> Function() modern,
      {Future<T> Function()? legacy}) async {
    if (_known[number] == false) {
      if (legacy != null) return legacy();
      throw MigrationMissing(number);
    }
    try {
      final r = await modern();
      _known[number] = true;
      return r;
    } catch (e) {
      if (!isMissing(e)) rethrow;
      _known[number] = false;
      if (legacy != null) return legacy();
      throw MigrationMissing(number);
    }
  }
}

/// В базе нет миграции [number] — экран показывает «Нужна миграция».
class MigrationMissing implements Exception {
  const MigrationMissing(this.number);
  final String number;
  @override
  String toString() => 'MigrationMissing($number)';
}
