import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';
import 'vps_logic.dart';

/// «VPS-скан помещения» (0025): anchor payload из портала Niantic.
class VpsSite {
  const VpsSite(
      {required this.id,
      required this.locationId,
      required this.name,
      required this.payload,
      this.updatedAt,
      this.marks = 0});
  final String id;
  final String locationId;
  final String name;
  final String payload;
  final DateTime? updatedAt;

  /// Сколько меток оборудования поставлено.
  final int marks;

  static VpsSite fromRow(Map<String, dynamic> r) {
    final m = r['vps_marks'];
    return VpsSite(
      id: r['id'] as String,
      locationId: r['location_id'] as String,
      name: (r['name'] as String?) ?? '',
      payload: (r['anchor_payload'] as String?) ?? '',
      updatedAt: DateTime.tryParse('${r['updated_at'] ?? ''}')?.toLocal(),
      marks: m is List && m.isNotEmpty
          ? ((m.first as Map)['count'] as int? ?? 0)
          : 0,
    );
  }
}

class VpsRepo {
  VpsRepo([SupabaseClient? client]) : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  /// Скан помещения (null — нет или не видно по правам). Без 0025 — null.
  Future<VpsSite?> site(String locationId) => SchemaCompat.run<VpsSite?>(
        '0025',
        () async {
          final r = await _c
              .from('vps_sites')
              .select(
                  'id,location_id,name,anchor_payload,updated_at,vps_marks(count)')
              .eq('location_id', locationId)
              .maybeSingle();
          return r == null ? null : VpsSite.fromRow(r);
        },
        legacy: () async => null,
      );

  /// Сохранить payload (новый скан или замена). Метки остаются: они
  /// привязаны к старому якорю — после пересъёмки их лучше поставить заново.
  Future<void> save(
      {required String locationId,
      required String payload,
      required String name,
      String? id}) async {
    final p = normalizePayload(payload);
    if (p == null) throw ArgumentError('payload');
    if (id == null) {
      await _c.from('vps_sites').insert({
        'location_id': locationId,
        'anchor_payload': p,
        'name': name.trim(),
        // компанию и объект заполняет база (trg_vps_sites_fill)
        'company_id': await _companyId(),
        'object_id': await _objectOf(locationId),
      });
    } else {
      await _c
          .from('vps_sites')
          .update({'anchor_payload': p, 'name': name.trim()}).eq('id', id);
    }
  }

  Future<void> delete(String id) => _c.from('vps_sites').delete().eq('id', id);

  /// Заявки оборудования помещения (открытые и ТО) — для подписей меток.
  Future<List<Map<String, dynamic>>> ordersOfAssets(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return await _c
        .from('work_orders')
        .select('asset_id,status,plan_id,period_end,due_at')
        .inFilter('asset_id', ids)
        .not('status', 'in', '(done,cancelled)')
        .limit(500);
  }

  Future<String?> _companyId() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;
    final r = await _c
        .from('profiles')
        .select('company_id')
        .eq('id', uid)
        .maybeSingle();
    return r?['company_id'] as String?;
  }

  Future<String?> _objectOf(String locationId) async {
    final r = await _c
        .from('locations')
        .select('object_id')
        .eq('id', locationId)
        .maybeSingle();
    return r?['object_id'] as String?;
  }
}
