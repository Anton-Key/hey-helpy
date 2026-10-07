import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../models/user_role.dart';

/// Что произошло. Подпись подбирает экран на языке интерфейса.
enum NotificationKind {
  /// Исполнителю: заявка назначена его подрядчику.
  assigned,

  /// Исполнителю: работу вернули на доработку.
  returned,

  /// Менеджеру: работа ждёт приёмки.
  onReview,

  /// Менеджеру: срок прошёл, заявка не закрыта.
  overdue,

  /// Менеджеру: визит вне геозоны.
  visitOutside,

  /// Менеджеру: визит с подменой GPS.
  visitMock,

  /// Заявителю: его заявку взяли в работу.
  inProgress,

  /// Заявителю: работу по его заявке приняли.
  accepted,
}

class AppNotification {
  const AppNotification(
      {required this.kind,
      required this.at,
      required this.order,
      this.distanceM});
  final NotificationKind kind;
  final DateTime at;

  /// Строка заявки — для подписи и открытия карточки.
  final Map<String, dynamic> order;
  final double? distanceM;

  String get orderId => order['id'] as String;
}

/// События за последние [days] дней из заявок и визитов. Всё читается
/// под RLS: база отдаёт только то, что человеку и так видно.
class NotificationRepository {
  final SupabaseClient _c = Supabase.instance.client;

  static const days = 14;

  /// Поля заявки: для подписи, карточки (WorkOrder.fromMap) и времени события.
  static const _orderFields =
      'id,title,work_type,layer_id,priority,status,recurrence,object_id,'
      'location_id,assigned_contractor_id,created_by,created_at,updated_at,'
      'started_at,submitted_at,accepted_at,accepted_by,due_at,return_reason,'
      'locations(name)';

  Future<List<AppNotification>> load(Profile me) async {
    final now = DateTime.now().toUtc();
    final since = now.subtract(const Duration(days: days)).toIso8601String();
    final out = <AppNotification>[];
    DateTime? at(Map<String, dynamic> r, String field) =>
        DateTime.tryParse('${r[field]}');

    switch (me.role) {
      case UserRole.admin:
      case UserRole.manager:
        final review = await _c
            .from('work_orders')
            .select(_orderFields)
            .eq('status', 'on_review')
            .gte('submitted_at', since)
            .limit(100);
        for (final r in review) {
          out.add(AppNotification(
              kind: NotificationKind.onReview,
              at: at(r, 'submitted_at')!,
              order: r));
        }
        final overdue = await _c
            .from('work_orders')
            .select(_orderFields)
            .not('status', 'in', '(done,cancelled)')
            .gte('due_at', since)
            .lt('due_at', now.toIso8601String())
            .limit(100);
        for (final r in overdue) {
          out.add(AppNotification(
              kind: NotificationKind.overdue, at: at(r, 'due_at')!, order: r));
        }
        final visits = await _c
            .from('visits')
            .select(
                'id,started_at,distance_m,in_geofence,mock_location,work_orders!inner($_orderFields)')
            .gte('started_at', since)
            .or('in_geofence.eq.false,mock_location.eq.true')
            .limit(100);
        for (final v in visits) {
          final order = v['work_orders'] as Map<String, dynamic>?;
          if (order == null) continue;
          out.add(AppNotification(
              kind: v['mock_location'] == true
                  ? NotificationKind.visitMock
                  : NotificationKind.visitOutside,
              at: at(v, 'started_at')!,
              order: order,
              distanceM: (v['distance_m'] as num?)?.toDouble()));
        }
      case UserRole.executor:
      case UserRole.contractor:
        final mine = await _c
            .from('executors')
            .select('contractor_id')
            .eq('profile_id', me.id);
        final ids = [for (final r in mine) r['contractor_id'] as String];
        if (ids.isEmpty) break;
        final rows = await _c
            .from('work_orders')
            .select(_orderFields)
            .inFilter('assigned_contractor_id', ids)
            .inFilter('status', ['assigned', 'returned'])
            .gte('updated_at', since)
            .limit(100);
        for (final r in rows) {
          out.add(AppNotification(
              kind: r['status'] == 'returned'
                  ? NotificationKind.returned
                  : NotificationKind.assigned,
              at: at(r, 'updated_at')!,
              order: r));
        }
      case UserRole.requester:
        final started = await _c
            .from('work_orders')
            .select(_orderFields)
            .eq('created_by', me.id)
            .eq('status', 'in_progress')
            .gte('started_at', since)
            .limit(100);
        for (final r in started) {
          out.add(AppNotification(
              kind: NotificationKind.inProgress,
              at: at(r, 'started_at')!,
              order: r));
        }
        final accepted = await _c
            .from('work_orders')
            .select(_orderFields)
            .eq('created_by', me.id)
            .eq('status', 'done')
            .gte('accepted_at', since)
            .limit(100);
        for (final r in accepted) {
          // Если принял сам заявитель — это не новость для него.
          if (r['accepted_by'] == me.id) continue;
          out.add(AppNotification(
              kind: NotificationKind.accepted,
              at: at(r, 'accepted_at')!,
              order: r));
        }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  static String _prefsKey(String uid) => 'notifications_seen_at_$uid';

  /// Когда уведомления открывали последний раз: позднее из двух —
  /// с этого устройства и из профиля (profiles.notifications_seen_at, 0011).
  Future<DateTime?> seenAt(String uid) async {
    DateTime? local;
    try {
      final prefs = await SharedPreferences.getInstance();
      local = DateTime.tryParse(prefs.getString(_prefsKey(uid)) ?? '');
    } catch (_) {}
    DateTime? remote;
    try {
      final row =
          await _c.from('profiles').select().eq('id', uid).maybeSingle();
      remote = DateTime.tryParse('${row?['notifications_seen_at']}');
    } catch (_) {}
    if (local == null) return remote;
    if (remote == null) return local;
    return local.isAfter(remote) ? local : remote;
  }

  /// Отметить всё прочитанным. На устройстве — всегда; в профиле — если в базе
  /// уже есть колонка из 0011 (до неё база отвечает ошибкой, её пропускаем).
  Future<void> markSeen(String uid) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey(uid), now);
    } catch (_) {}
    try {
      await _c
          .from('profiles')
          .update({'notifications_seen_at': now}).eq('id', uid);
    } catch (_) {}
  }

  /// Сколько событий новее отметки «прочитано».
  static int unread(List<AppNotification> list, DateTime? seen) =>
      seen == null ? list.length : list.where((n) => n.at.isAfter(seen)).length;
}
