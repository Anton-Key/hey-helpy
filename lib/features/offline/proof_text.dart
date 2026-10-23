import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'offline_logic.dart';

/// «2 ч» / «15 мин» — на сколько расходились часы телефона.
String driftText(AppLocalizations l, int seconds) {
  final m = (seconds.abs() / 60).round();
  if (m >= 60) return l.durHours((m / 60).round());
  return l.durMinutes(m);
}

/// «время по GPS ✓» / «⚠️ время не подтверждено (часы … на 2 ч)».
String trustText(AppLocalizations l, TimeTrust? t, int? driftS) => switch (t) {
      TimeTrust.gps => l.proofTrustGps,
      TimeTrust.monotonic || TimeTrust.online || null => l.proofTrustMono,
      TimeTrust.deviceOnly => l.proofTrustDevice,
      TimeTrust.unverified => l.proofTrustUnverified(driftText(l, driftS ?? 0)),
    };

/// Строка доказательства для менеджера (шаг 27): «Снято без сети в 14:19 ·
/// время по GPS ✓ · отправлено в 14:25»; сомнительное — с «решение при
/// формировании акта»; прислано после отмены — с пометкой.
String? offlineProofLine(
  AppLocalizations l, {
  required bool offline,
  String? trust,
  DateTime? at,
  DateTime? synced,
  int? driftS,
  String? syncNote,
  bool? sha256Ok,
  bool visit = false,
}) {
  if (!offline) return null;
  final t = timeTrustFromDb(trust);
  final taken = at == null ? '—' : l.time(at);
  final sent = synced == null ? '—' : l.time(synced);
  final base = visit
      ? l.proofVisitOffline(taken, trustText(l, t, driftS), sent)
      : l.proofOffline(taken, trustText(l, t, driftS), sent);
  final notes = <String>[
    if (syncNote == 'after_cancel') l.proofLateAfterCancel,
    if (syncNote == 'after_reassign') l.proofLateAfterReassign,
    if (syncNote == 'after_close') l.proofLateAfterClose,
    if (!visit && sha256Ok != true) l.proofHashUnchecked,
    if (!trustOk(t) || syncNote != null || (!visit && sha256Ok != true))
      l.proofNeedsDecision,
  ];
  return [base, ...notes].join(' · ');
}
