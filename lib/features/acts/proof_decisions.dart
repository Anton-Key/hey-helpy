import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/paging.dart';
import '../../core/schema_compat.dart';
import '../offline/offline_logic.dart' show timeTrustFromDb, trustOk;

/// Решение менеджера по сомнительному доказательству (шаг 27, 0024):
/// «Подтвердить к оплате» / «Не принимать». Последнее по заявке —
/// действующее, прежние — журнал.
class ProofDecision {
  const ProofDecision(
      {required this.orderId,
      required this.approve,
      required this.at,
      this.reason,
      this.byName});
  final String orderId;
  final bool approve;
  final DateTime at;
  final String? reason;
  final String? byName;

  factory ProofDecision.fromRow(Map<String, dynamic> r) => ProofDecision(
        orderId: r['work_order_id'] as String,
        approve: r['decision'] == 'approve',
        at: DateTime.tryParse('${r['decided_at']}') ?? DateTime.now(),
        reason: r['reason'] as String?,
        byName: (r['by'] as Map<String, dynamic>?)?['full_name'] as String?,
      );
}

/// Ошибки решения — по-человечески.
enum DecisionError { denied, locked, reasonRequired, notAccepted, other }

DecisionError decisionError(Object e) {
  final s = '$e';
  if (s.contains('act_decision_locked')) return DecisionError.locked;
  if (s.contains('act_decision_reason_required')) {
    return DecisionError.reasonRequired;
  }
  if (s.contains('act_decision_not_accepted')) return DecisionError.notAccepted;
  if (s.contains('act_decision_denied')) return DecisionError.denied;
  return DecisionError.other;
}

class ProofDecisionsRepo {
  final SupabaseClient _c = Supabase.instance.client;

  /// Действующие решения по заявкам: order_id → последнее решение.
  Future<Map<String, ProofDecision>> latest(List<String> orderIds) =>
      SchemaCompat.run('0024', () async {
        final out = <String, ProofDecision>{};
        for (final chunk in chunks(orderIds)) {
          final rows = await _c
              .from('act_proof_decisions')
              .select('work_order_id,decision,reason,decided_at,'
                  'by:profiles!act_proof_decisions_decided_by_fkey(full_name)')
              .inFilter('work_order_id', chunk)
              .order('decided_at', ascending: false);
          for (final r in rows) {
            out.putIfAbsent(
                r['work_order_id'] as String, () => ProofDecision.fromRow(r));
          }
        }
        return out;
      }, legacy: () async => const {});

  Future<void> decide(String orderId,
          {required bool approve, String? reason}) =>
      _c.rpc('act_proof_decide', params: {
        'p_order': orderId,
        'p_decision': approve ? 'approve' : 'reject',
        'p_reason': reason,
      });

  /// Для главной менеджера и «Отчётов» (шаг 27): за период принятые
  /// заявки — сколько ждут решения по оплате (фото «после» под вопросом и
  /// решения нет), сколько сдано без сети, сколько подтверждено вручную.
  /// Без 0024 — нули.
  Future<({int pending, int offline, int manual, String? contractorId})> stats(
          DateTime from, DateTime to) =>
      SchemaCompat.run('0024', () async {
        final rows = await _c
            .from('attachments')
            .select('work_order_id,source,offline,time_trust,sync_note,'
                'sha256_ok,work_orders!inner(status,accepted_at,'
                'requires_photo,assigned_contractor_id)')
            .eq('kind', 'photo')
            .eq('stage', 'after')
            .eq('work_orders.status', 'done')
            .gte('work_orders.accepted_at', from.toUtc().toIso8601String())
            .lt('work_orders.accepted_at', to.toUtc().toIso8601String())
            .limit(2000);
        final proven = <String>{};
        final unproven = <String, String?>{};
        final offline = <String>{};
        for (final r in rows) {
          final id = r['work_order_id'] as String;
          final w = r['work_orders'] as Map<String, dynamic>;
          if (r['offline'] == true) offline.add(id);
          final ok = r['source'] != 'file' &&
              (r['offline'] != true ||
                  (trustOk(timeTrustFromDb(r['time_trust'])) &&
                      r['sync_note'] == null &&
                      r['sha256_ok'] == true));
          if (ok) {
            proven.add(id);
          } else if (w['requires_photo'] == true) {
            unproven[id] = w['assigned_contractor_id'] as String?;
          }
        }
        unproven.removeWhere((id, _) => proven.contains(id));
        final decided = await latest(unproven.keys.toList());
        final pending = {
          for (final e in unproven.entries)
            if (!decided.containsKey(e.key)) e.key: e.value
        };
        return (
          pending: pending.length,
          offline: offline.length,
          manual: decided.values.where((d) => d.approve).length,
          contractorId: pending.values.whereType<String>().firstOrNull,
        );
      },
          legacy: () async =>
              (pending: 0, offline: 0, manual: 0, contractorId: null));
}
