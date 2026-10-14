import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'camera_logic.dart';

/// Данные для карточки «Камеры-помощника»: заявки единицы и задачи ППР её
/// системы на объекте. Всё под RLS пользователя (что не видно — того нет).
class AssetFactsRepo {
  AssetFactsRepo([SupabaseClient? client])
      : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  /// Поля строки заявки — те же, что у списков (карточка заявки откроется).
  static const _cols =
      'id,title,work_type,layer_id,priority,status,recurrence,object_id,'
      'location_id,asset_id,assigned_contractor_id,created_at,accepted_at,'
      'return_count,due_at,plan_id,period_end,locations(name)';

  Future<AssetFacts> load(
      {required String assetId, String? objectId, String? layerId}) async {
    final own = _c
        .from('work_orders')
        .select(_cols)
        .eq('asset_id', assetId)
        .order('created_at', ascending: false)
        .limit(60);
    Future<List<Map<String, dynamic>>> system() async {
      if (objectId == null || layerId == null) return const [];
      try {
        return await _c
            .from('work_orders')
            .select(_cols)
            .not('plan_id', 'is', null)
            .isFilter('asset_id', null)
            .eq('object_id', objectId)
            .eq('layer_id', layerId)
            .not('status', 'in', '(done,cancelled)')
            .order('period_end')
            .limit(5);
      } catch (e) {
        // Без 0015 (нет plan_id) — без ТО системы.
        debugPrint('AssetFacts system: ${e.runtimeType}');
        return const [];
      }
    }

    final r = await Future.wait([own, system()]);
    return buildAssetFacts(r[0], systemPprRows: r[1]);
  }
}
