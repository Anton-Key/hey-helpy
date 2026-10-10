import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';
import 'zone_logic.dart';

/// Бригада подрядчика (crews + crew_members + crew_zones, 0016).
class Crew {
  const Crew({
    required this.id,
    required this.contractorId,
    required this.name,
    this.executorIds = const {},
    this.zones = const [],
  });

  final String id;
  final String contractorId;
  final String name;
  final Set<String> executorIds;
  final List<ZoneRow> zones;
}

/// Название бригады уже занято у этого подрядчика (23505).
class CrewDuplicate implements Exception {
  const CrewDuplicate();
}

/// Зоны доступа и бригады. Права проверяет база (0016): зоны меняет только
/// администратор, бригады — менеджер, которому виден подрядчик. Без 0016 —
/// [MigrationMissing].
class ZoneRepository {
  ZoneRepository([SupabaseClient? client])
      : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  static const _zoneCols = 'layer_ids,scope_kind,scope_ref';

  List<ZoneRow> _rows(List<Map<String, dynamic>> list) => [
        for (final m in list)
          if (ZoneRow.fromMap(m) case final r?) r,
      ];

  /// Зоны сотрудника (свои видит сам менеджер, все — администратор).
  Future<List<ZoneRow>> zonesOf(String profileId) =>
      SchemaCompat.run('0016', () async {
        final rows = await _c
            .from('access_zones')
            .select(_zoneCols)
            .eq('profile_id', profileId)
            .order('created_at');
        return _rows(rows);
      });

  /// Свои зоны; без 0016 — пусто (ограничений нет).
  Future<List<ZoneRow>> myZones() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      return await zonesOf(uid);
    } on MigrationMissing {
      return const [];
    }
  }

  /// Заменить зоны сотрудника: удалить старые, вставить новые.
  Future<void> replaceZones(
          {required String profileId,
          required String companyId,
          required List<ZoneRow> rows}) =>
      SchemaCompat.run('0016', () async {
        await _c.from('access_zones').delete().eq('profile_id', profileId);
        if (rows.isEmpty) return;
        await _c.from('access_zones').insert([
          for (final r in rows)
            {...r.toMap(), 'profile_id': profileId, 'company_id': companyId},
        ]);
      });

  /// Бригады подрядчика с участниками и зонами.
  Future<List<Crew>> crewsOf(String contractorId) =>
      SchemaCompat.run('0016', () async {
        final rows = await _c
            .from('crews')
            .select('id,contractor_id,name,crew_members(executor_id),'
                'crew_zones($_zoneCols)')
            .eq('contractor_id', contractorId)
            .order('name');
        return [
          for (final m in rows)
            Crew(
              id: m['id'] as String,
              contractorId: m['contractor_id'] as String,
              name: (m['name'] ?? '') as String,
              executorIds: {
                for (final e in (m['crew_members'] as List?) ?? const [])
                  (e as Map<String, dynamic>)['executor_id'] as String
              },
              zones: _rows([
                for (final z in (m['crew_zones'] as List?) ?? const [])
                  z as Map<String, dynamic>
              ]),
            ),
        ];
      });

  static bool _dup(Object e) => e is PostgrestException && e.code == '23505';

  /// Создать или сохранить бригаду: название, участники, зона.
  Future<String> saveCrew({
    String? id,
    required String companyId,
    required String contractorId,
    required String name,
    required Set<String> executorIds,
    required List<ZoneRow> zones,
  }) =>
      SchemaCompat.run('0016', () async {
        String crewId;
        try {
          if (id == null) {
            final r = await _c
                .from('crews')
                .insert({
                  'company_id': companyId,
                  'contractor_id': contractorId,
                  'name': name.trim(),
                })
                .select('id')
                .single();
            crewId = r['id'] as String;
          } else {
            final r = await _c
                .from('crews')
                .update({'name': name.trim()})
                .eq('id', id)
                .select('id');
            if (r.isEmpty) {
              throw const PostgrestException(message: 'not allowed');
            }
            crewId = id;
          }
        } catch (e) {
          if (_dup(e)) throw const CrewDuplicate();
          rethrow;
        }
        await _c.from('crew_members').delete().eq('crew_id', crewId);
        if (executorIds.isNotEmpty) {
          await _c.from('crew_members').insert([
            for (final e in executorIds)
              {'crew_id': crewId, 'executor_id': e, 'company_id': companyId},
          ]);
        }
        await _c.from('crew_zones').delete().eq('crew_id', crewId);
        if (zones.isNotEmpty) {
          await _c.from('crew_zones').insert([
            for (final z in zones)
              {...z.toMap(), 'crew_id': crewId, 'company_id': companyId},
          ]);
        }
        return crewId;
      });

  Future<void> deleteCrew(String id) => SchemaCompat.run('0016', () async {
        final r = await _c.from('crews').delete().eq('id', id).select('id');
        if (r.isEmpty) throw const PostgrestException(message: 'not allowed');
      });

  /// Названия и объекты этажей и оборудования из зон (для подписей).
  Future<
      ({
        Map<String, String> floorNames,
        Map<String, String> floorObject,
        Map<String, String> assetNames,
        Map<String, String> assetObject,
      })> placeNames(Iterable<ZoneRow> rows) async {
    final floors = {
      for (final r in rows)
        if (r.place.scope == ZoneScope.floor && r.place.ref != null)
          r.place.ref!
    };
    final assets = {
      for (final r in rows)
        if (r.place.scope == ZoneScope.asset && r.place.ref != null)
          r.place.ref!
    };
    final fn = <String, String>{}, fo = <String, String>{};
    final an = <String, String>{}, ao = <String, String>{};
    if (floors.isNotEmpty) {
      final list = await _c
          .from('floors')
          .select('id,name,object_id')
          .inFilter('id', floors.toList());
      for (final f in list) {
        fn[f['id'] as String] = (f['name'] ?? '') as String;
        fo[f['id'] as String] = f['object_id'] as String;
      }
    }
    if (assets.isNotEmpty) {
      final list = await _c
          .from('assets')
          .select('id,name,locations(object_id)')
          .inFilter('id', assets.toList());
      for (final a in list) {
        an[a['id'] as String] = (a['name'] ?? '') as String;
        final o = (a['locations'] as Map<String, dynamic>?)?['object_id'];
        if (o is String) ao[a['id'] as String] = o;
      }
    }
    return (floorNames: fn, floorObject: fo, assetNames: an, assetObject: ao);
  }

  /// Этажи и оборудование объекта — уточнить место правила.
  Future<
      ({
        List<({String id, String name})> floors,
        List<({String id, String name})> assets,
      })> partsOf(String objectId) async {
    final f = await _c
        .from('floors')
        .select('id,name')
        .eq('object_id', objectId)
        .order('sort');
    final a = await _c
        .from('assets')
        .select('id,name,locations!inner(object_id)')
        .eq('locations.object_id', objectId)
        .order('name');
    return (
      floors: [
        for (final r in f)
          (id: r['id'] as String, name: (r['name'] ?? '') as String)
      ],
      assets: [
        for (final r in a)
          (id: r['id'] as String, name: (r['name'] ?? '') as String)
      ],
    );
  }
}
