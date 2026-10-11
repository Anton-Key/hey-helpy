import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';

/// Регион компании (`regions`, 0015): «Европа», «СНГ». Один общий список
/// на компанию; объекты ссылаются на регион ([Obj.regionId]), поэтому
/// переименование сразу видно везде.
class Region {
  const Region({required this.id, required this.name, this.sort = 0});
  final String id;
  final String name;
  final int sort;

  factory Region.fromMap(Map<String, dynamic> m) => Region(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        sort: (m['sort'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is Region &&
      other.id == id &&
      other.name == name &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(id, name, sort);
}

/// Порядок регионов: по [Region.sort], затем по названию.
List<Region> sortRegions(Iterable<Region> regions) => [...regions]
  ..sort((a, b) {
    final s = a.sort.compareTo(b.sort);
    return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

/// Регион с таким названием уже есть (база не пропустила дубль, 23505).
class RegionDuplicate implements Exception {
  const RegionDuplicate();
}

/// План объединения: какие объекты переедут из [from] в [into].
class RegionMergePlan {
  const RegionMergePlan(
      {required this.from, required this.into, required this.objectIds});
  final Region from;
  final Region into;
  final List<String> objectIds;
  int get count => objectIds.length;
}

/// Объединить [from] с [into]: объекты [from] (по их regionId) переходят в
/// [into], сам [from] потом удаляется. Чистая функция — тест без базы.
RegionMergePlan planRegionMerge<T>(
    Region from, Region into, Iterable<T> objects,
    {required String? Function(T) regionOf, required String Function(T) idOf}) {
  if (from.id == into.id) {
    throw ArgumentError('cannot merge a region into itself');
  }
  return RegionMergePlan(from: from, into: into, objectIds: [
    for (final o in objects)
      if (regionOf(o) == from.id) idOf(o)
  ]);
}

/// Сколько объектов в каждом регионе: id региона → число.
Map<String, int> regionObjectCounts<T>(
    Iterable<T> objects, String? Function(T) regionOf) {
  final out = <String, int>{};
  for (final o in objects) {
    final r = regionOf(o);
    if (r != null) out[r] = (out[r] ?? 0) + 1;
  }
  return out;
}

/// Регионы компании и страна / город / регион объекта. Права проверяет
/// база: читает компания, меняет менеджер (0015). До миграции 0015
/// запросы бросают [MigrationMissing].
class RegionRepository {
  RegionRepository({SupabaseClient? client})
      : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  /// Последний загруженный список (для подписей, которым нужен ответ сразу:
  /// таблетка фильтра, группировка). null — ещё не загружали или нет 0015.
  static List<Region>? cached;

  Future<List<Region>> list() async {
    final rows = await SchemaCompat.run(
        '0015', () => _c.from('regions').select('id,name,sort').order('sort'));
    final list = sortRegions([
      for (final r in rows as List) Region.fromMap(r as Map<String, dynamic>)
    ]);
    cached = list;
    return list;
  }

  /// Список или пусто, если миграции 0015 нет / ошибка сети.
  Future<List<Region>> listOrEmpty() async {
    try {
      return await list();
    } catch (_) {
      return const [];
    }
  }

  static bool _isDuplicate(Object e) =>
      e is PostgrestException && e.code == '23505';

  Future<Region> create(String name,
      {required String companyId, int sort = 0}) async {
    try {
      final r = await SchemaCompat.run(
          '0015',
          () => _c
              .from('regions')
              .insert(
                  {'company_id': companyId, 'name': name.trim(), 'sort': sort})
              .select('id,name,sort')
              .single());
      return Region.fromMap(r);
    } catch (e) {
      if (_isDuplicate(e)) throw const RegionDuplicate();
      rethrow;
    }
  }

  Future<void> rename(String id, String name) async {
    try {
      final rows = await _c
          .from('regions')
          .update({'name': name.trim()})
          .eq('id', id)
          .select('id');
      if ((rows as List).isEmpty) {
        throw const PostgrestException(message: 'not allowed');
      }
    } catch (e) {
      if (_isDuplicate(e)) throw const RegionDuplicate();
      rethrow;
    }
  }

  /// Порядок: sort = позиция в [ordered].
  Future<void> reorder(List<Region> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].sort == i + 1) continue;
      await _c.from('regions').update({'sort': i + 1}).eq('id', ordered[i].id);
    }
  }

  /// Удалить регион: у его объектов регион станет пустым (on delete set null).
  Future<void> delete(String id) async {
    final rows = await _c.from('regions').delete().eq('id', id).select('id');
    if ((rows as List).isEmpty) {
      throw const PostgrestException(message: 'not allowed');
    }
  }

  /// Объединить: объекты переходят в [plan.into], лишний регион удаляется.
  Future<void> merge(RegionMergePlan plan) async {
    await _c
        .from('objects')
        .update({'region_id': plan.into.id}).eq('region_id', plan.from.id);
    await delete(plan.from.id);
  }

  /// Страна (код ISO), город и регион объекта. null — очистить.
  Future<void> setObjectGeo(String objectId,
      {String? countryCode, String? city, String? regionId}) async {
    final rows = await SchemaCompat.run(
        '0015',
        () => _c
            .from('objects')
            .update({
              'country_code': countryCode,
              'city': (city?.trim().isEmpty ?? true) ? null : city!.trim(),
              'region_id': regionId,
            })
            .eq('id', objectId)
            .select('id'));
    if ((rows as List).isEmpty) {
      throw const PostgrestException(message: 'not allowed');
    }
  }
}
