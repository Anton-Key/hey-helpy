import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/paging.dart';
import '../../core/schema_compat.dart';

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
}
