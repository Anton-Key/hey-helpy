/// Шаг 28: VPS-эксперимент (Niantic Spatial) — чистые функции.
/// Тесты — test/vps_logic_test.dart.
library;

/// Состояние VPS-варианта сборки (канал hey_helpy/vps → status).
enum VpsToken { ok, missing, expired }

enum VpsArcore { supported, unsupported, unknown }

class VpsStatus {
  const VpsStatus(
      {required this.available,
      this.token = VpsToken.missing,
      this.arcore = VpsArcore.unknown,
      this.tokenExpiresAt});

  /// Обычная сборка (канала нет) или браузер.
  static const none = VpsStatus(available: false);

  /// VPS-вариант сборки — кнопки «Метки VPS» показываются только тогда.
  final bool available;
  final VpsToken token;
  final VpsArcore arcore;
  final DateTime? tokenExpiresAt;

  static VpsStatus fromMap(Map<Object?, Object?>? m) {
    if (m == null || m['available'] != true) return none;
    final exp = m['tokenExpiresAt'];
    return VpsStatus(
      available: true,
      token: switch (m['token']) {
        'ok' => VpsToken.ok,
        'expired' => VpsToken.expired,
        _ => VpsToken.missing,
      },
      arcore: switch (m['arcore']) {
        'supported' => VpsArcore.supported,
        'unsupported' => VpsArcore.unsupported,
        _ => VpsArcore.unknown,
      },
      tokenExpiresAt:
          exp is num ? DateTime.fromMillisecondsSinceEpoch(exp.toInt()) : null,
    );
  }
}

/// Почему экран VPS открывать нельзя (до запуска камеры).
enum VpsBlocker { tokenMissing, tokenExpired, noArcore, noSite }

VpsBlocker? vpsBlocker(VpsStatus s, {required bool hasSite, DateTime? now}) {
  if (s.token == VpsToken.missing) return VpsBlocker.tokenMissing;
  final expired = s.token == VpsToken.expired ||
      (s.tokenExpiresAt != null &&
          !s.tokenExpiresAt!.isAfter(now ?? DateTime.now()));
  if (expired) return VpsBlocker.tokenExpired;
  if (s.arcore == VpsArcore.unsupported) return VpsBlocker.noArcore;
  if (!hasSite) return VpsBlocker.noSite;
  return null;
}

/// Сколько дней до конца токена — предупредить за неделю.
int? vpsTokenDaysLeft(VpsStatus s, DateTime now) {
  final e = s.tokenExpiresAt;
  if (e == null) return null;
  return e.difference(now).inHours ~/ 24;
}

/// Anchor payload из портала: без пробелов и переносов (их добавляет
/// копирование из письма или PDF). null — пусто или явно не payload.
String? normalizePayload(String raw) {
  final s = raw.replaceAll(RegExp(r'\s+'), '');
  if (s.length < 8 || s.length > 20000) return null;
  if (!RegExp(r'^[A-Za-z0-9+/=_\-.:]+$').hasMatch(s)) return null;
  return s;
}

/// Короткий вид payload для экрана: «CjIK…9Qs= · 1 284 знака».
String payloadPreview(String payload) {
  if (payload.length <= 16) return payload;
  return '${payload.substring(0, 6)}…${payload.substring(payload.length - 6)}';
}

/// Подпись метки над оборудованием.
class VpsMarkLabel {
  const VpsMarkLabel(
      {required this.id,
      required this.name,
      required this.line,
      required this.color});
  final String id;
  final String name;
  final String line;

  /// «#RRGGBB» — цвет системы.
  final String color;

  Map<String, Object> toJson() =>
      {'id': id, 'name': name, 'line': line, 'color': color};
}

/// «1 открытая заявка · ТО 31.10» — части берутся из переводов.
String vpsMarkLine(
    {required int openCount,
    DateTime? nextDue,
    required String Function(int) openOrders,
    required String noOpenOrders,
    required String Function(DateTime) maintenance}) {
  final parts = [
    openCount > 0 ? openOrders(openCount) : noOpenOrders,
    if (nextDue != null) maintenance(nextDue),
  ];
  return parts.join(' · ');
}

/// Сводка по оборудованию помещения из строк заявок (под RLS):
/// открытые заявки (без задач ППР) и ближайшее ТО единицы.
class VpsAssetFacts {
  const VpsAssetFacts({this.openCount = 0, this.nextDue});
  final int openCount;
  final DateTime? nextDue;
}

const _closed = {'done', 'cancelled'};

Map<String, VpsAssetFacts> vpsFactsByAsset(List<Map<String, dynamic>> rows) {
  final open = <String, int>{};
  final next = <String, DateTime>{};
  for (final r in rows) {
    final id = r['asset_id'] as String?;
    if (id == null || _closed.contains(r['status'])) continue;
    if (r['plan_id'] != null) {
      final d = DateTime.tryParse('${r['period_end'] ?? r['due_at'] ?? ''}');
      if (d != null && (next[id] == null || d.isBefore(next[id]!))) {
        next[id] = d;
      }
    } else {
      open[id] = (open[id] ?? 0) + 1;
    }
  }
  return {
    for (final id in {...open.keys, ...next.keys})
      id: VpsAssetFacts(openCount: open[id] ?? 0, nextDue: next[id]),
  };
}
