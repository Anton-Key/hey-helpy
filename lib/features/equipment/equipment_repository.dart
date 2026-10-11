import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';
import 'equipment_models.dart';

/// Реестр оборудования (шаг 16). Читает вся компания, меняет только
/// менеджер — это проверяет база (политики assets из 0008). Паспортные
/// поля — с миграцией 0015; до неё читаются только старые колонки.
class EquipmentRepo {
  final SupabaseClient _c = Supabase.instance.client;

  /// Есть ли в базе поля паспорта оборудования (0015). null — ещё не знаем.
  static bool? get hasRegistry => SchemaCompat.has('0015');

  /// Оборудование объекта (через помещения объекта).
  Future<List<Asset>> assetsOf(String objectId) async {
    Future<List<Asset>> query(String cols) async {
      final rows = await _c
          .from('assets')
          .select('$cols,locations!inner(object_id)')
          .eq('locations.object_id', objectId)
          .order('name');
      return [for (final r in rows) Asset.fromMap(r)];
    }

    return SchemaCompat.run('0015', () => query(Asset.columns),
        legacy: () => query(Asset.legacyColumns));
  }

  Future<Asset?> asset(String id) async {
    Future<Asset?> query(String cols) async {
      final r = await _c.from('assets').select(cols).eq('id', id).maybeSingle();
      return r == null ? null : Asset.fromMap(r);
    }

    return SchemaCompat.run('0015', () => query(Asset.columns),
        legacy: () => query(Asset.legacyColumns));
  }

  /// Новое оборудование. Нужна 0015 (паспортные поля).
  Future<String> add(AssetDraft d) async {
    final r = await SchemaCompat.run('0015',
        () => _c.from('assets').insert(d.toRow()).select('id').single());
    return r['id'] as String;
  }

  /// Изменить паспорт и помещение. Если RLS не дал изменить — ошибка.
  Future<void> update(String id, AssetDraft d) async {
    final rows = await SchemaCompat.run('0015',
        () => _c.from('assets').update(d.toRow()).eq('id', id).select('id'));
    if (rows.isEmpty) {
      throw const PostgrestException(message: 'not allowed', code: '42501');
    }
  }

  /// Несколько единиц сразу (импорт) — одним запросом: либо все, либо ни одной.
  Future<int> addMany(List<AssetDraft> list) async {
    if (list.isEmpty) return 0;
    final rows = await SchemaCompat.run(
        '0015',
        () => _c
            .from('assets')
            .insert([for (final d in list) d.toRow()]).select('id'));
    return rows.length;
  }

  /// Инвентарные номера, уже занятые в компании (проверка импорта).
  Future<Set<String>> inventoryNumbers() async {
    final rows = await _c
        .from('assets')
        .select('inventory_no')
        .not('inventory_no', 'is', null);
    return {
      for (final r in rows)
        if ((r['inventory_no'] as String?)?.trim().isNotEmpty == true)
          (r['inventory_no'] as String).trim()
    };
  }

  /// Новое помещение объекта (импорт: «создать недостающие»). Возвращает id.
  Future<String> addPlace(String objectId, String name) async {
    final r = await _c
        .from('locations')
        .insert({'object_id': objectId, 'name': name.trim()})
        .select('id')
        .single();
    return r['id'] as String;
  }

  /// Планы ППР этого оборудования (0015). Без 0015 — пусто.
  Future<List<AssetPlan>> plansOf(String assetId) async {
    try {
      final rows = await SchemaCompat.run(
          '0015',
          () => _c
              .from('maintenance_plans')
              .select('id,title,period_kind,period_days,active')
              .eq('asset_id', assetId)
              .order('title'));
      return [for (final r in rows) AssetPlan.fromMap(r)];
    } on MigrationMissing {
      return const [];
    }
  }

  /// Заявки по оборудованию (сначала новые) — те же поля, что у списков
  /// заявок объекта ([OrderContext.open] открывает их карточку).
  Future<List<Map<String, dynamic>>> ordersOf(String assetId,
      {int limit = 50}) async {
    final rows = await _c
        .from('work_orders')
        .select(
            'id,title,work_type,layer_id,priority,status,recurrence,object_id,'
            'location_id,assigned_contractor_id,created_at,accepted_at,'
            'return_count,due_at,locations(name)')
        .eq('asset_id', assetId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows;
  }
}
