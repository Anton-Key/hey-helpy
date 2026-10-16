import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';
import 'readiness_logic.dart';

/// Ответ функции на проверочный запрос: HTTP-код (null — не ответила),
/// время в мс и тело ответа (только для разбора полей, не показывается).
typedef Probe = ({int? status, int ms, Object? data});

/// Запросы экрана «Готовность к показу» (шаг 29). Всё — с правами вошедшего
/// администратора (RLS), в базе ничего не меняется, заявок не создаётся.
class ReadinessRepository {
  ReadinessRepository([SupabaseClient? client]) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _c => _client ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 20);

  /// База отвечает: одна строка своей компании.
  Future<({bool ok, int ms})> pingDb() async {
    final sw = Stopwatch()..start();
    try {
      await _c.from('companies').select('id').limit(1).timeout(_timeout);
      return (ok: true, ms: sw.elapsedMilliseconds);
    } catch (_) {
      return (ok: false, ms: sw.elapsedMilliseconds);
    }
  }

  /// Есть ли таблица / столбец каждой миграции из [readinessMigrations].
  Future<Map<String, bool?>> migrations() async {
    final entries =
        await Future.wait(readinessMigrations.entries.map((e) async {
      try {
        await _c.from(e.value.$1).select(e.value.$2).limit(1).timeout(_timeout);
        return MapEntry(e.key, true as bool?);
      } catch (err) {
        return MapEntry(e.key, SchemaCompat.isMissing(err) ? false : null);
      }
    }));
    return Map.fromEntries(entries);
  }

  /// Вызов функции с JWT. Ожидаемые 4xx — тоже ответ (функция жива).
  Future<Probe> invoke(String name, Map<String, dynamic> body) async {
    final sw = Stopwatch()..start();
    try {
      final res = await _c.functions.invoke(name, body: body).timeout(_timeout);
      return (status: res.status, ms: sw.elapsedMilliseconds, data: res.data);
    } on FunctionException catch (e) {
      return (status: e.status, ms: sw.elapsedMilliseconds, data: e.details);
    } catch (_) {
      return (status: null, ms: sw.elapsedMilliseconds, data: null);
    }
  }

  /// Голос: настоящий разбор короткой фразы (ничего не создаёт).
  Future<Probe> voiceProbe(String locale) => invoke('voice-intake', {
        'text': locale == 'ru'
            ? 'Эй, Хелпи, проверка связи: в переговорной жарко'
            : 'Hey Helpy, connection test: it is hot in the meeting room',
        'locale': locale == 'ru' ? 'ru' : 'en',
      });

  /// «По фото»: настоящий разбор нарисованного демо-снимка из сборки
  /// (`assets/demo_photos/ac_indoor.jpg`). Функция снимок не сохраняет,
  /// журнал 0017 пишет только приложение — эта проверка его не трогает.
  Future<Probe> photoProbe(String locale) async {
    final bytes = await rootBundle.load('assets/demo_photos/ac_indoor.jpg');
    return invoke('photo-identify', {
      'image': base64Encode(bytes.buffer.asUint8List()),
      'locale': locale == 'ru' ? 'ru' : 'en',
    });
  }

  /// Остальные функции — проверочные запросы без действия:
  /// telegram-bot без секрета вебхука отвечает 401, offline-sync на пустой
  /// запрос — 400, telegram-notify `{kind: webhook}` — состояние вебхука.
  Future<Probe> botProbe() => invoke('telegram-bot', const {});
  Future<Probe> offlineSyncProbe() => invoke('offline-sync', const {});
  Future<Probe> webhookProbe() =>
      invoke('telegram-notify', const {'kind': 'webhook'});

  /// Самая новая демо-заявка (id `de300000-…-000000000101…299`):
  /// Refresh demo ставит даты от дня запуска.
  Future<DateTime?> newestDemoOrder() async {
    try {
      final rows = await _c
          .from('work_orders')
          .select('created_at')
          .gte('id', 'de300000-0000-4000-8000-000000000101')
          .lte('id', 'de300000-0000-4000-8000-000000000299')
          .order('created_at', ascending: false)
          .limit(1)
          .timeout(_timeout);
      final list = rows as List;
      if (list.isEmpty) return null;
      return DateTime.tryParse(list.first['created_at'] as String? ?? '')
          ?.toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Журнал «По фото» (0017) за сутки: сколько узнаваний и среднее время.
  Future<({int count, int? avgMs})?> photoLog24h() async {
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(hours: 24));
      final rows = await _c
          .from('photo_identifications')
          .select('ms')
          .gte('created_at', since.toIso8601String())
          .limit(1000)
          .timeout(_timeout);
      final ms = [
        for (final r in rows as List)
          if ((r as Map)['ms'] is num) (r['ms'] as num).toInt()
      ];
      if (ms.isEmpty) return (count: (rows).length, avgMs: null);
      return (
        count: rows.length,
        avgMs: ms.reduce((a, b) => a + b) ~/ ms.length
      );
    } catch (_) {
      return null;
    }
  }
}
