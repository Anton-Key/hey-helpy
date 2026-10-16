/// «Готовность к показу» (шаг 29): чистые функции — какой цвет у строки проверки.
/// Сами запросы — `readiness_repository.dart`, экран — `readiness_screen.dart`.
library;

/// Состояние одной проверки: зелёная, жёлтая, красная, неизвестно (серая).
enum CheckLevel { ok, warn, fail, unknown }

/// Худшее из состояний (для общей строки сверху): красное > жёлтое > серое > зелёное.
CheckLevel worst(Iterable<CheckLevel> levels) {
  var r = CheckLevel.ok;
  for (final l in levels) {
    if (l == CheckLevel.fail) return CheckLevel.fail;
    if (l == CheckLevel.warn) r = CheckLevel.warn;
    if (l == CheckLevel.unknown && r == CheckLevel.ok) r = CheckLevel.unknown;
  }
  return r;
}

/// Ответ функции на проверочный запрос: [status] — HTTP-код (null — нет ответа:
/// сеть, таймаут). Функция «жива», если ответила сама: 2xx или ожидаемые 400 / 401 /
/// 403 / 404 (неверный ввод, нет прав). 5xx (не настроена, упала) и тишина — красное.
CheckLevel functionLevel(int? status) {
  if (status == null) return CheckLevel.fail;
  if (status >= 200 && status < 300) return CheckLevel.ok;
  if (const {400, 401, 403, 404}.contains(status)) return CheckLevel.ok;
  return CheckLevel.fail;
}

/// Миграции, которые проверяет экран, и чем: таблица или столбец под RLS.
/// 0022 — закрытая схема `telegram`, её не видно; 0025 требует 0022, поэтому
/// 0022 считается применённой, если есть 0025.
const readinessMigrations = <String, (String table, String column)>{
  '0017': ('photo_identifications', 'id'),
  '0018': ('report_links', 'id'),
  '0019': ('attachments', 'file_name'),
  '0020': ('layers', 'archived_at'),
  '0021': ('contractor_rates', 'contractor_id'),
  '0023': ('work_orders', 'submitted_by'),
  '0024': ('act_proof_decisions', 'id'),
  '0025': ('vps_sites', 'id'),
};

/// Итог по миграциям: [found] — номер → есть / нет / null (не удалось проверить).
/// Возвращает список отсутствующих (с учётом 0022 через 0025) и цвет.
({CheckLevel level, List<String> missing}) migrationsLevel(
    Map<String, bool?> found) {
  final missing = <String>[
    for (final e in found.entries)
      if (e.value == false) e.key,
  ];
  missing.sort();
  if (missing.isNotEmpty) return (level: CheckLevel.fail, missing: missing);
  if (found.values.any((v) => v == null)) {
    return (level: CheckLevel.unknown, missing: const []);
  }
  return (level: CheckLevel.ok, missing: const []);
}

/// Свежесть демо-данных по самой новой демо-заявке (Refresh demo ставит даты
/// от сегодняшнего дня): до 2 суток — зелёное, до 7 — жёлтое, старше — красное.
CheckLevel demoLevel(DateTime? newest, DateTime now) {
  if (newest == null) return CheckLevel.fail;
  final age = now.difference(newest);
  if (age <= const Duration(days: 2)) return CheckLevel.ok;
  if (age <= const Duration(days: 7)) return CheckLevel.warn;
  return CheckLevel.fail;
}

/// Время ответа ИИ: до 8 с — зелёное (так ждёт экран), до 16 с — жёлтое
/// (приложение ещё дождётся), дольше или ошибка — красное.
CheckLevel aiLevel(int? ms) {
  if (ms == null) return CheckLevel.fail;
  if (ms <= 8000) return CheckLevel.ok;
  if (ms <= 16000) return CheckLevel.warn;
  return CheckLevel.fail;
}

/// Средняя скорость «По фото» из журнала за сутки: пусто — серое (не снимали).
CheckLevel photoLogLevel(int count, int? avgMs) =>
    count == 0 ? CheckLevel.unknown : aiLevel(avgMs);

/// Ответ функции telegram-notify на `{kind: "webhook"}`.
class WebhookStatus {
  const WebhookStatus(
      {required this.configured, required this.pending, this.lastErrorAgeS});
  final bool configured;
  final int pending;
  final int? lastErrorAgeS;

  static WebhookStatus? fromJson(Object? data) {
    final w = data is Map ? data['webhook'] : null;
    if (w is! Map) return null;
    return WebhookStatus(
      configured: w['configured'] == true,
      pending: (w['pending'] as num?)?.toInt() ?? 0,
      lastErrorAgeS: (w['last_error_age_s'] as num?)?.toInt(),
    );
  }
}

/// Вебхук бота: не настроен — красное; ошибка доставки за последний час или
/// очередь > 10 — жёлтое; иначе зелёное. [status] — HTTP-код функции:
/// 400 — выложена старая версия без проверки (серое, «после Deploy functions»).
CheckLevel webhookLevel(int? status, WebhookStatus? w) {
  if (status == 400) return CheckLevel.unknown;
  if (status == null || w == null) return CheckLevel.fail;
  if (!w.configured) return CheckLevel.fail;
  final recentError = w.lastErrorAgeS != null && w.lastErrorAgeS! < 3600;
  if (recentError || w.pending > 10) return CheckLevel.warn;
  return CheckLevel.ok;
}
