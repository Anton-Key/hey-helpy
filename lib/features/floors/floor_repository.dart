import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/schema_compat.dart';
import 'floor_models.dart';
import 'plan_logic.dart';

/// База не дала изменить (не менеджер или чужая компания) — RLS вернула
/// пустой ответ или ошибку прав.
class FloorDenied implements Exception {
  const FloorDenied();
}

/// Нельзя удалить: на помещении или оборудовании есть заявки.
class HasOrders implements Exception {
  const HasOrders();
}

/// Такой номер помещения в объекте уже есть (уникальность, 0015).
class RoomCodeTaken implements Exception {
  const RoomCodeTaken();
}

/// Этажи, помещения и оборудование на плане, файлы планов (0013).
/// Права проверяет база: менять — только менеджер своей компании.
class FloorRepo {
  FloorRepo({SupabaseClient? client}) : _c = client ?? Supabase.instance.client;
  final SupabaseClient _c;

  static const bucket = 'floor-plans';

  /// Подписанные ссылки на картинки планов: путь → (ссылка, до когда).
  /// Общий кэш на всё приложение; ссылки не логируются.
  static final _urls = <String, (String, DateTime)>{};

  // ------------------------------------------------------------------ чтение

  Future<List<Floor>> floorsOf(String objectId) async {
    final rows =
        await _c.from('floors').select(Floor.columns).eq('object_id', objectId);
    return sortFloors([for (final r in rows) Floor.fromMap(r)]);
  }

  /// Все этажи компании (по RLS) — для строки «Этажи · N» на карте.
  Future<List<Floor>> allFloors() async {
    final rows = await _c.from('floors').select(Floor.columns);
    return sortFloors([for (final r in rows) Floor.fromMap(r)]);
  }

  Future<Floor?> floor(String id) async {
    final r = await _c
        .from('floors')
        .select(Floor.columns)
        .eq('id', id)
        .maybeSingle();
    return r == null ? null : Floor.fromMap(r);
  }

  /// Помещения и оборудование объекта (с этажом и точкой на плане).
  Future<List<PlanItem>> itemsOf(String objectId) async {
    final r = await Future.wait([
      SchemaCompat.run(
          '0015',
          () => _c
              .from('locations')
              .select(PlanItem.placeColumns)
              .eq('object_id', objectId)
              .order('name'),
          legacy: () => _c
              .from('locations')
              .select(PlanItem.placeColumnsLegacy)
              .eq('object_id', objectId)
              .order('name')),
      _c
          .from('assets')
          .select(PlanItem.assetColumns)
          .eq('locations.object_id', objectId)
          .order('name'),
    ]);
    return [
      for (final m in r[0]) PlanItem.placeFromMap(m),
      for (final m in r[1]) PlanItem.assetFromMap(m),
    ];
  }

  /// Открытые заявки объекта (то, что видно пользователю по RLS).
  Future<List<PlanOrder>> openOrdersOf(String objectId) async {
    final rows = await _c
        .from('work_orders')
        .select(PlanOrder.columns)
        .eq('object_id', objectId)
        .not('status', 'in', '(done,cancelled)')
        .order('created_at', ascending: false);
    return [for (final r in rows) PlanOrder.fromMap(r)];
  }

  /// Этаж и точка одного помещения и оборудования (для «Показать на плане»
  /// в карточке заявки).
  Future<PlanItem?> placeById(String id) async {
    final r = await SchemaCompat.run(
        '0015',
        () => _c
            .from('locations')
            .select(PlanItem.placeColumns)
            .eq('id', id)
            .maybeSingle(),
        legacy: () => _c
            .from('locations')
            .select(PlanItem.placeColumnsLegacy)
            .eq('id', id)
            .maybeSingle());
    return r == null ? null : PlanItem.placeFromMap(r);
  }

  Future<PlanItem?> assetById(String id) async {
    final r = await _c
        .from('assets')
        .select(PlanItem.assetColumns)
        .eq('id', id)
        .maybeSingle();
    return r == null ? null : PlanItem.assetFromMap(r);
  }

  /// Этажи помещений по id (подпись «1 эт.» в строке заявки).
  Future<Map<String, Floor>> floorsOfPlaces(Iterable<String> placeIds) async {
    final ids = placeIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _c
        .from('locations')
        .select('id,floors(${Floor.columns})')
        .inFilter('id', ids);
    return {
      for (final r in rows)
        if (r['floors'] is Map<String, dynamic>)
          r['id'] as String: Floor.fromMap(r['floors'] as Map<String, dynamic>),
    };
  }

  // ------------------------------------------------------------------ этажи

  Future<Floor> createFloor(
      {required String objectId,
      required String companyId,
      required String name,
      int? level,
      required int sort}) async {
    final r = await _c
        .from('floors')
        .insert({
          'object_id': objectId,
          'company_id': companyId,
          'name': name.trim(),
          'level': level,
          'sort': sort,
        })
        .select(Floor.columns)
        .single();
    return Floor.fromMap(r);
  }

  Future<void> updateFloor(String id, Map<String, dynamic> values) async {
    final rows =
        await _c.from('floors').update(values).eq('id', id).select('id');
    if (rows.isEmpty) throw const FloorDenied();
  }

  Future<void> renameFloor(String id, String name, int? level) =>
      updateFloor(id, {'name': name.trim(), 'level': level});

  Future<void> setSorts(Map<String, int> sorts) async {
    for (final e in sorts.entries) {
      await updateFloor(e.key, {'sort': e.value});
    }
  }

  /// Удаляет этаж: помещения и оборудование остаются (floor_id → null,
  /// 0013), их точки на плане стираются здесь же. Файл плана — тоже.
  Future<void> deleteFloor(Floor f) async {
    await _c
        .from('locations')
        .update({'plan_x': null, 'plan_y': null}).eq('floor_id', f.id);
    await _c
        .from('assets')
        .update({'plan_x': null, 'plan_y': null}).eq('floor_id', f.id);
    final rows = await _c.from('floors').delete().eq('id', f.id).select('id');
    if (rows.isEmpty) throw const FloorDenied();
    if (f.planPath != null) await _removeFile(f.planPath!);
  }

  // ------------------------------------------------------------------ план

  /// Загрузка или замена картинки: сначала новый файл, потом этаж, потом
  /// удаление старого файла (если что-то упало — старый план остаётся).
  Future<Floor> uploadPlan(Floor f, Uint8List bytes, PlanImageInfo info) async {
    final path = planStoragePath(f, info.ext, DateTime.now());
    try {
      await _c.storage.from(bucket).uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: info.mime, upsert: false));
    } on StorageException catch (e) {
      // Код и путь — в журнал (без подписанных ссылок и токенов).
      debugPrint('FloorRepo.uploadPlan: storage code=${e.statusCode} '
          'message=${e.message} path=$path');
      rethrow;
    }
    try {
      await updateFloor(f.id,
          {'plan_path': path, 'plan_w': info.width, 'plan_h': info.height});
    } catch (_) {
      await _removeFile(path);
      rethrow;
    }
    final old = f.planPath;
    if (old != null && old != path) await _removeFile(old);
    return Floor(
        id: f.id,
        objectId: f.objectId,
        companyId: f.companyId,
        name: f.name,
        level: f.level,
        sort: f.sort,
        planPath: path,
        planW: info.width,
        planH: info.height);
  }

  /// «Убрать план»: этаж без картинки, точки маркеров остаются.
  Future<void> clearPlan(Floor f) async {
    await updateFloor(
        f.id, {'plan_path': null, 'plan_w': null, 'plan_h': null});
    if (f.planPath != null) await _removeFile(f.planPath!);
  }

  Future<void> _removeFile(String path) async {
    _urls.remove(path);
    try {
      await _c.storage.from(bucket).remove([path]);
    } catch (e) {
      // Файл без этажа никто не увидит; этаж уже сохранён.
      debugPrint('FloorRepo: старый файл плана не удалён (${e.runtimeType})');
    }
  }

  /// Подписанная ссылка на картинку (~1 час, кэш в памяти). В логи не пишется.
  Future<String> planUrl(String path) async {
    final now = DateTime.now();
    final cached = _urls[path];
    if (cached != null && cached.$2.isAfter(now)) return cached.$1;
    final url = await _c.storage.from(bucket).createSignedUrl(path, 3600);
    // Обновляем за 5 минут до конца срока.
    _urls[path] = (url, now.add(const Duration(minutes: 55)));
    return url;
  }

  // ------------------------------------------- помещения и оборудование

  Future<void> _update(String table, String id, Map<String, dynamic> v) async {
    final rows = await _c.from(table).update(v).eq('id', id).select('id');
    if (rows.isEmpty) throw const FloorDenied();
  }

  /// Поставить маркер: этаж и точка (доли 0..1).
  Future<void> setPoint(PlanItem i, String floorId, double x, double y) =>
      _update(i.isPlace ? 'locations' : 'assets', i.id,
          {'floor_id': floorId, 'plan_x': x, 'plan_y': y});

  /// Вернуть прежнее положение («Отменить»).
  Future<void> restore(PlanItem i) => _update(
      i.isPlace ? 'locations' : 'assets',
      i.id,
      {'floor_id': i.floorId, 'plan_x': i.x, 'plan_y': i.y});

  /// «Убрать с плана»: точку стереть, этаж оставить.
  Future<void> clearPoint(PlanItem i) => _update(
      i.isPlace ? 'locations' : 'assets',
      i.id,
      {'plan_x': null, 'plan_y': null});

  Future<void> rename(PlanItem i, String name) =>
      _update(i.isPlace ? 'locations' : 'assets', i.id, {'name': name.trim()});

  /// Номер помещения (0015); пустая строка — убрать номер. Номер уникален
  /// в объекте без учёта регистра — повтор: [RoomCodeTaken].
  Future<void> setCode(PlanItem place, String code) async {
    final c = code.trim();
    try {
      await SchemaCompat.run('0015',
          () => _update('locations', place.id, {'code': c.isEmpty ? null : c}));
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const RoomCodeTaken();
      rethrow;
    }
  }

  /// Область помещения на плане этажа [floorId] (null — удалить область).
  /// Помещению без точки ставится точка в центре области.
  Future<void> setShape(
      PlanItem place, String floorId, List<(double, double)>? points) {
    final v = <String, dynamic>{
      'plan_shape': points == null ? null : planShapeJson(points),
    };
    if (points != null) {
      v['floor_id'] = floorId;
      if (!place.placed || place.floorId != floorId) {
        final (cx, cy) = polygonCentroid(points);
        v['plan_x'] = cx;
        v['plan_y'] = cy;
      }
    }
    return _update('locations', place.id, v);
  }

  Future<PlanItem> createPlace(
      {required String objectId,
      required String name,
      required String floorId,
      required double x,
      required double y}) async {
    final r = await _c
        .from('locations')
        .insert({
          'object_id': objectId,
          'name': name.trim(),
          'floor_id': floorId,
          'plan_x': x,
          'plan_y': y,
        })
        .select(PlanItem.placeColumnsLegacy)
        .single();
    return PlanItem.placeFromMap(r);
  }

  Future<PlanItem> createAsset(
      {required String locationId,
      required String name,
      required String category,
      String? inventoryNo,
      required String floorId,
      required double x,
      required double y}) async {
    final r = await _c
        .from('assets')
        .insert({
          'location_id': locationId,
          'name': name.trim(),
          'category': category,
          'inventory_no': (inventoryNo == null || inventoryNo.trim().isEmpty)
              ? null
              : inventoryNo.trim(),
          'floor_id': floorId,
          'plan_x': x,
          'plan_y': y,
        })
        .select(PlanItem.assetColumns)
        .single();
    return PlanItem.assetFromMap(r);
  }

  /// Удалить помещение или оборудование, только если на нём нет заявок
  /// (иначе — [HasOrders]: предложить «Убрать с плана»).
  Future<void> delete(PlanItem i) async {
    final col = i.isPlace ? 'location_id' : 'asset_id';
    final n =
        await _c.from('work_orders').count(CountOption.exact).eq(col, i.id);
    if (n > 0) throw const HasOrders();
    final rows = await _c
        .from(i.isPlace ? 'locations' : 'assets')
        .delete()
        .eq('id', i.id)
        .select('id');
    if (rows.isEmpty) throw const FloorDenied();
  }
}
