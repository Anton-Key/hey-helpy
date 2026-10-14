import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/paging.dart';
import '../../core/schema_compat.dart';
import '../directory/directory.dart';

/// Счётчики системы в пределах того, что видно пользователю (RLS и зоны 0016).
class SystemStats {
  const SystemStats(
      {this.assets = 0, this.openOrders = 0, this.contractors = 0});
  final int assets;
  final int openOrders;
  final int contractors;
}

/// Единица оборудования системы с объектом — для карточки системы.
class SystemAsset {
  const SystemAsset(
      {required this.id, required this.name, this.objectId, this.placeName});
  final String id;
  final String name;
  final String? objectId;
  final String? placeName;
}

class SystemContractor {
  const SystemContractor(this.id, this.name, this.objects);
  final String id;
  final String name;

  /// Сколько объектов закреплено; 0 — «на всех объектах».
  final int objects;
}

/// Счётчики по системам из готовых строк — чистая функция (тесты).
Map<String, SystemStats> countSystemStats({
  required List<String?> assetLayers,
  required List<String?> openOrderLayers,
  required List<(String contractorId, String layerId)> bindings,
}) {
  final a = <String, int>{};
  final o = <String, int>{};
  final c = <String, Set<String>>{};
  for (final l in assetLayers) {
    if (l != null) a[l] = (a[l] ?? 0) + 1;
  }
  for (final l in openOrderLayers) {
    if (l != null) o[l] = (o[l] ?? 0) + 1;
  }
  for (final (contractor, layer) in bindings) {
    (c[layer] ??= {}).add(contractor);
  }
  return {
    for (final id in {...a.keys, ...o.keys, ...c.keys})
      id: SystemStats(
          assets: a[id] ?? 0,
          openOrders: o[id] ?? 0,
          contractors: c[id]?.length ?? 0),
  };
}

/// Порядок после «вверх / вниз»: системы с новыми значениями sort (10, 20…).
List<Layer> moveSystem(List<Layer> list, int from, int to) {
  if (from < 0 || from >= list.length || to < 0 || to >= list.length) {
    return list;
  }
  final out = [...list];
  final x = out.removeAt(from);
  out.insert(to, x);
  return out;
}

class SystemsRepository {
  final SupabaseClient _c = Supabase.instance.client;

  /// Все видимые системы (с архивными), по порядку.
  /// Есть ли 0020 — по столбцу `icon` в ответе (запрос «*» работает и без неё).
  Future<List<Layer>> list() async {
    final rows = await _c.from('layers').select().order('sort').order('name');
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isNotEmpty) {
      SchemaCompat.mark('0020', list.first.containsKey('icon'));
    }
    return [for (final r in list) Layer.fromMap(r)];
  }

  Future<Map<String, SystemStats>> stats() async {
    final r = await Future.wait([
      fetchAll(() => _c.from('assets').select('layer_id').order('id')),
      fetchAll(() => _c
          .from('work_orders')
          .select('layer_id')
          .not('status', 'in', '(done,cancelled)')
          .order('id')),
      fetchAll(() => _c
          .from('contractor_layers')
          .select('contractor_id,layer_id')
          .order('id')),
    ]);
    return countSystemStats(
      assetLayers: [for (final x in r[0]) x['layer_id'] as String?],
      openOrderLayers: [for (final x in r[1]) x['layer_id'] as String?],
      bindings: [
        for (final x in r[2])
          (x['contractor_id'] as String, x['layer_id'] as String)
      ],
    );
  }

  Future<List<SystemAsset>> assets(String layerId) async {
    final rows = await fetchAll(() => _c
        .from('assets')
        .select('id,name,location_id,locations(object_id,name)')
        .eq('layer_id', layerId)
        .order('name'));
    return [
      for (final r in rows)
        SystemAsset(
          id: r['id'] as String,
          name: (r['name'] ?? '') as String,
          objectId: (r['locations'] as Map<String, dynamic>?)?['object_id']
              as String?,
          placeName:
              (r['locations'] as Map<String, dynamic>?)?['name'] as String?,
        ),
    ];
  }

  Future<List<SystemContractor>> contractors(String layerId) async {
    final rows = await _c
        .from('contractor_layers')
        .select('contractor_id,object_id,contractors(org_name)')
        .eq('layer_id', layerId);
    final by = <String, (String, Set<String>, bool)>{};
    for (final r in rows as List) {
      final id = r['contractor_id'] as String;
      final name = ((r['contractors'] as Map<String, dynamic>?)?['org_name'] ??
          '') as String;
      final cur = by[id] ?? (name, <String>{}, false);
      final obj = r['object_id'] as String?;
      by[id] = (
        cur.$1,
        obj == null ? cur.$2 : {...cur.$2, obj},
        cur.$3 || obj == null
      );
    }
    final out = [
      for (final e in by.entries)
        SystemContractor(e.key, e.value.$1, e.value.$3 ? 0 : e.value.$2.length)
    ]..sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Новая система или правка (только администратор — проверяет база).
  Future<void> save(
      {String? id,
      required String companyId,
      required String nameRu,
      required String nameEn,
      required String color,
      required String icon,
      int? sort}) async {
    final row = {
      'name': nameRu.trim(),
      'name_i18n': {
        'ru': nameRu.trim(),
        if (nameEn.trim().isNotEmpty) 'en': nameEn.trim(),
      },
      'color': color,
      'icon': icon,
      if (sort != null) 'sort': sort,
    };
    if (id == null) {
      await _c.from('layers').insert({...row, 'company_id': companyId});
    } else {
      final r = await _c.from('layers').update(row).eq('id', id).select('id');
      if ((r as List).isEmpty) throw const SystemDenied();
    }
  }

  Future<void> setArchived(String id, bool archived) async {
    final r = await _c
        .from('layers')
        .update({
          'archived_at':
              archived ? DateTime.now().toUtc().toIso8601String() : null
        })
        .eq('id', id)
        .select('id');
    if ((r as List).isEmpty) throw const SystemDenied();
  }

  /// Удалить можно только неиспользуемую систему: иначе [SystemInUse].
  Future<void> delete(String id) async {
    try {
      final r = await _c.from('layers').delete().eq('id', id).select('id');
      if ((r as List).isEmpty) throw const SystemDenied();
    } on PostgrestException catch (e) {
      if (e.message.contains('system_in_use') || e.code == '23503') {
        throw const SystemInUse();
      }
      rethrow;
    }
  }

  /// Записать порядок: 10, 20, 30…
  Future<void> saveOrder(List<Layer> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final sort = (i + 1) * 10;
      if (ordered[i].sort == sort) continue;
      await _c.from('layers').update({'sort': sort}).eq('id', ordered[i].id);
    }
  }
}

class SystemDenied implements Exception {
  const SystemDenied();
}

class SystemInUse implements Exception {
  const SystemInUse();
}
