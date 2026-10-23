import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../photo_identify/identify_log.dart' show newUuid;
import '../requests/work_order.dart' show WorkOrder;
import 'device_clock.dart';
import 'offline_logic.dart';
import 'offline_store.dart';

/// Работа без интернета (шаг 27, только APK; в браузере — только в
/// тестовом режиме `--dart-define=OFFLINE_TEST=true`).
///
/// * Предзагрузка: свои назначенные заявки исполнителя («назначена / в
///   работе / возвращена») с чек-листами и местом, справочники — при
///   входе, при открытии списка и раз в 15 минут.
/// * Кэш ответов сервера ([cachedJson]): нет сети — последний ответ.
/// * Очередь действий исполнителя ([enqueue]): по порядку, у каждого свой
///   id; при появлении сети — отправка одной функцией `offline_sync`.
/// * Шаг 32: новая заявка без сети ([createOrder]) — у любого вошедшего;
///   справочники для формы (объекты, системы, этажи, помещения и
///   оборудование) — в предзагрузке у всех.
/// * Якорь часов ([anchor]) при каждой связи — для «доверенного» времени.
class OfflineService extends ChangeNotifier {
  OfflineService._();
  static final OfflineService instance = OfflineService._();

  /// Тестовый режим в браузере: сборка с `OFFLINE_TEST=true` и адрес с
  /// `?offline=1` (сквозной сценарий 17, кадры 25–27). Без параметра —
  /// как обычный веб.
  static final bool testMode = const bool.fromEnvironment('OFFLINE_TEST') &&
      Uri.base.queryParameters['offline'] == '1';

  /// Офлайн-режим доступен: Android или тестовый режим.
  static bool get supported =>
      testMode || (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Сколько ждать сервер, прежде чем считать, что сети нет.
  static const requestTimeout = Duration(seconds: 12);
  static const prefetchEvery = Duration(minutes: 15);
  static const retryEvery = Duration(seconds: 20);

  /// Лимит снимков на телефоне (очередь и миниатюры).
  static const maxPhotoBytes = 30 * 1024 * 1024;

  SupabaseClient get _c => Supabase.instance.client;
  DeviceClock clock = PlatformDeviceClock(skew: _testSkew());

  OfflineStore? _store;
  String? _uid;
  Map<String, Object?> _cache = {};
  List<OfflineAction> _queue = [];
  List<SyncFailure> _failures = [];
  ClockAnchor? _anchor;
  DateTime? _cacheAt;
  DateTime? _prefetchedAt;
  Timer? _prefetchTimer;
  Timer? _retryTimer;
  Timer? _saveCacheTimer;
  Timer? _sentTimer;
  bool _online = true;
  bool _sending = false;
  bool _justSent = false;

  /// Тестовый режим: принудительно «нет сети» (кнопки не трогают сервер).
  bool forceOffline = false;

  bool get online => _online && !forceOffline;
  bool get sending => _sending;

  /// «Отправлено ✓» — 2 секунды после успешной отправки.
  bool get justSent => _justSent;
  int get pending => _queue.length;
  List<OfflineAction> get queue => List.unmodifiable(_queue);
  List<SyncFailure> get failures => List.unmodifiable(_failures);
  DateTime? get cacheAt => _cacheAt;
  ClockAnchor? get anchorValue => _anchor;
  bool get attached => _uid != null;

  static Duration _testSkew() {
    if (!testMode) return Duration.zero;
    final m = int.tryParse(Uri.base.queryParameters['clockSkewMin'] ?? '');
    return Duration(minutes: m ?? 0);
  }

  // ---------------------------------------------------------------------
  // Вход / выход
  // ---------------------------------------------------------------------

  /// После входа: поднять сохранённое, предзагрузить, запустить таймеры.
  Future<void> attach(String uid) async {
    if (!supported || _uid == uid) return;
    await detach(clear: false);
    _uid = uid;
    final store = _store = OfflineStore.forUser(uid);
    final cache = await store.read('cache');
    _cache = cache is Map ? Map<String, Object?>.from(cache) : {};
    final q = await store.read('queue');
    _queue = [
      if (q is List)
        ...q.map(OfflineAction.fromJson).whereType<OfflineAction>(),
    ];
    final meta = await store.read('meta');
    if (meta is Map) {
      _anchor = ClockAnchor.fromJson(meta['anchor']);
      _cacheAt = DateTime.tryParse('${meta['cache_at'] ?? ''}');
      _failures = [
        if (meta['failures'] is List)
          ...(meta['failures'] as List)
              .map(SyncFailure.fromJson)
              .whereType<SyncFailure>(),
      ];
    }
    notifyListeners();
    _prefetchTimer = Timer.periodic(prefetchEvery, (_) => prefetch());
    unawaited(_afterAttach());
  }

  Future<void> _afterAttach() async {
    await anchor();
    if (_queue.isNotEmpty) await flush();
    await prefetch();
  }

  /// Выход из аккаунта: таймеры стоп, [clear] — удалить всё с телефона.
  Future<void> detach({bool clear = true}) async {
    _prefetchTimer?.cancel();
    _retryTimer?.cancel();
    _saveCacheTimer?.cancel();
    _prefetchTimer = _retryTimer = _saveCacheTimer = null;
    final store = _store;
    if (clear && store != null) await store.clear();
    _store = null;
    _uid = null;
    _cache = {};
    _queue = [];
    _failures = [];
    _anchor = null;
    _cacheAt = null;
    _prefetchedAt = null;
    _online = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Сеть и кэш
  // ---------------------------------------------------------------------

  void _markOnline() {
    if (_online) return;
    _online = true;
    notifyListeners();
    if (_queue.isNotEmpty) unawaited(flush());
  }

  void markOffline() {
    if (!_online) return;
    _online = false;
    notifyListeners();
    _scheduleRetry();
  }

  /// Ответ сервера с запасом на телефоне: сеть есть — свежий (и
  /// сохраняется), нет — последний сохранённый. Ни того, ни другого —
  /// исходная ошибка. Вне офлайн-режима — просто [load].
  Future<Object?> cachedJson(
      String key, Future<Object?> Function() load) async {
    if (!supported || _uid == null) return load();
    if (forceOffline) {
      if (_cache.containsKey(key)) return _cache[key];
      throw TimeoutException('offline');
    }
    try {
      final v = await load().timeout(requestTimeout);
      _cache[key] = v;
      _scheduleCacheSave();
      _markOnline();
      return v;
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      markOffline();
      if (_cache.containsKey(key)) return _cache[key];
      rethrow;
    }
  }

  Object? cached(String key) => _cache[key];

  void put(String key, Object? value) {
    if (!supported || _uid == null) return;
    _cache[key] = value;
    _scheduleCacheSave();
  }

  void _scheduleCacheSave() {
    _saveCacheTimer?.cancel();
    _saveCacheTimer = Timer(const Duration(milliseconds: 500), _saveCache);
  }

  Future<void> _saveCache() async {
    await _store?.write('cache', _cache);
  }

  Future<void> _saveMeta() async {
    await _store?.write('meta', {
      'anchor': _anchor?.toJson(),
      'cache_at': _cacheAt?.toUtc().toIso8601String(),
      'failures': [for (final f in _failures) f.toJson()],
    });
  }

  Future<void> _saveQueue() async {
    await _store?.write('queue', [for (final a in _queue) a.toJson()]);
  }

  // ---------------------------------------------------------------------
  // Часы
  // ---------------------------------------------------------------------

  /// Якорь «время сервера ↔ монотонные часы»: при каждой связи.
  Future<void> anchor() async {
    if (!supported || _uid == null || forceOffline) return;
    try {
      final r = await clock.read();
      if (r.monoMs == null || r.bootId == null) return;
      final at = await _c.rpc('offline_clock', params: {
        'p_boot': r.bootId,
        'p_mono_ms': r.monoMs,
      }).timeout(requestTimeout);
      final server = DateTime.tryParse('$at');
      if (server == null) return;
      _anchor =
          ClockAnchor(serverAt: server, monoMs: r.monoMs!, bootId: r.bootId!);
      await _saveMeta();
      _markOnline();
    } catch (e) {
      if (isNetworkError(e)) markOffline();
      // Без 0024 функции нет — молча: время останется «по часам телефона».
      debugPrint('offline_clock: ${e.runtimeType}');
    }
  }

  /// Показания часов на момент [device] (снимок сделан чуть раньше,
  /// чем его ставят в очередь): монотонные и GPS сдвигаются так же.
  Future<ClockReading> readingAt([DateTime? device]) async {
    final r = await clock.read();
    if (device == null) return r;
    // [device] — DateTime.now() экрана съёмки; в тестовом режиме к нему
    // добавляются те же «переведённые часы», что и у [clock].
    final c = clock;
    if (c is PlatformDeviceClock) device = device.add(c.skew);
    final shift = r.device.difference(device);
    return ClockReading(
        device: device,
        monoMs: r.monoMs == null ? null : r.monoMs! - shift.inMilliseconds,
        bootId: r.bootId,
        gpsAt: r.gpsAt?.subtract(shift));
  }

  /// Время для штампа фото: доверенное, если есть, иначе часы телефона.
  Future<DateTime> stampTimeFor(DateTime device) async =>
      stampTime(await readingAt(device), _anchor);

  // ---------------------------------------------------------------------
  // Предзагрузка своих заявок исполнителя
  // ---------------------------------------------------------------------

  static const _openStatuses = ['assigned', 'in_progress', 'returned'];

  /// Колонки строки списка — те же, что у вкладки «Заявки».
  static const listColumns = WorkOrder.listColumns0015;

  /// Не чаще раза в 2 минуты (кроме [force]).
  Future<void> prefetch({bool force = false}) async {
    final uid = _uid;
    if (!supported || uid == null || forceOffline) return;
    final last = _prefetchedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _prefetchedAt = DateTime.now();
    await _prefetchRefs(uid);
    try {
      final ex = await _c
          .from('executors')
          .select('contractor_id')
          .eq('profile_id', uid)
          .timeout(requestTimeout);
      final contractors = {for (final r in ex) r['contractor_id'] as String};
      // Тот же ключ, что у RequestsRepo.myContractorIds — карточка без
      // сети узнаёт, что пользователь — исполнитель.
      _cache['my_contractor_rows'] = ex;
      if (contractors.isEmpty) {
        _scheduleCacheSave();
        return;
      }
      final rows = await _c
          .from('work_orders')
          .select(listColumns)
          .inFilter('assigned_contractor_id', contractors.toList())
          .inFilter('status', _openStatuses)
          .order('created_at', ascending: false)
          .limit(300)
          .timeout(requestTimeout);
      final details = await _c
          .from('work_orders')
          .select('*,locations(name,code)')
          .inFilter('assigned_contractor_id', contractors.toList())
          .inFilter('status', _openStatuses)
          .limit(300)
          .timeout(requestTimeout);
      final ids = [for (final d in details) d['id'] as String];
      final objIds = {
        for (final d in details)
          if (d['object_id'] != null) d['object_id'] as String
      }.toList();
      final checklist = ids.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _c
              .from('checklist_items')
              .select('id,work_order_id,text,is_done,done_at,created_at')
              .inFilter('work_order_id', ids)
              .order('created_at')
              .timeout(requestTimeout);
      // Место: помещения, этажи и оборудование объектов своих заявок.
      if (objIds.isNotEmpty) {
        final r = await Future.wait([
          _c.from('locations').select().inFilter('object_id', objIds),
          // Шаг 28: с путём плана и размером — план без сети.
          _c
              .from('floors')
              .select(
                  'id,object_id,company_id,name,level,sort,plan_path,plan_w,plan_h')
              .inFilter('object_id', objIds),
        ]).timeout(requestTimeout);
        final locIds = [for (final l in r[0]) l['id'] as String];
        final assets = locIds.isEmpty
            ? const <Map<String, dynamic>>[]
            : await _c
                .from('assets')
                .select('id,name,location_id,layer_id,meta,model,serial_no,'
                    'category,inventory_no,floor_id,plan_x,plan_y')
                .inFilter('location_id', locIds)
                .timeout(requestTimeout);
        _cache['places'] = {
          'locations': r[0],
          'floors': r[1],
          'assets': assets
        };
      }
      _cache['my_orders'] = rows;
      // Карточки: старые записи своих заявок убираем, новые — кладём.
      _cache.removeWhere(
          (k, _) => k.startsWith('detail:') || k.startsWith('checklist:'));
      for (final d in details) {
        _cache['detail:${d['id']}'] = d;
      }
      for (final id in ids) {
        _cache['checklist:$id'] = [
          for (final c in checklist)
            if (c['work_order_id'] == id) c
        ];
      }
      _cacheAt = DateTime.now();
      await _saveCache();
      await _saveMeta();
      _markOnline();
      notifyListeners();
      // Шаг 28: фото «до» и планы этажей — байтами, после всего остального
      // (без них заявки уже работают без сети).
      await _prefetchMedia(ids, details);
    } catch (e) {
      if (isNetworkError(e)) markOffline();
      debugPrint('offline prefetch: ${e.runtimeType}');
    }
  }

  /// Шаг 32: справочники формы новой заявки — у всех ролей, по RLS (свои
  /// объекты). Ключи — те же, что у DirectoryRepo / FloorRepo
  /// (`objects`, `layers`, `floors_of:<объект>`, `items_of:<объект>`).
  /// Свои открытые заявки не исполнителя — в `my_orders` (список без сети).
  static const _refObjectsMax = 300;

  Future<void> _prefetchRefs(String uid) async {
    try {
      final r = await Future.wait<Object>([
        _c.from('objects').select().order('created_at').limit(_refObjectsMax),
        _c
            .from('layers')
            .select()
            .order('sort', ascending: true)
            .order('name', ascending: true),
      ]).timeout(requestTimeout);
      final objects = r[0] as List;
      _cache['objects'] = objects;
      _cache['layers'] = r[1];
      final ids = [for (final o in objects) '${(o as Map)['id']}'];
      if (ids.isNotEmpty) {
        final p = await Future.wait<List<Map<String, dynamic>>>([
          _c.from('floors').select(_floorColumns).inFilter('object_id', ids),
          _c
              .from('locations')
              .select(_placeColumns)
              .inFilter('object_id', ids)
              .order('name')
              .limit(5000),
          _c
              .from('assets')
              .select(_assetColumns)
              .inFilter('locations.object_id', ids)
              .order('name')
              .limit(5000),
          // Помещения с объектом — для разбора голосовой заявки словарём.
          _c
              .from('locations')
              .select('id,object_id,name,code,objects(name,address)')
              .order('name')
              .limit(5000),
        ]).timeout(requestTimeout);
        _cache['all_places'] = p[3];
        for (final id in ids) {
          _cache['floors_of:$id'] = [
            for (final f in p[0])
              if (f['object_id'] == id) f
          ];
          _cache['items_of:$id'] = {
            'places': [
              for (final l in p[1])
                if (l['object_id'] == id) l
            ],
            'assets': [
              for (final a in p[2])
                if ((a['locations'] as Map?)?['object_id'] == id) a
            ],
          };
        }
      }
      // Не исполнитель — свои открытые заявки (у исполнителя — заявки
      // подрядчика, ниже).
      final mine = await _c
          .from('work_orders')
          .select(listColumns)
          .eq('created_by', uid)
          .not('status', 'in', '(done,cancelled)')
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(requestTimeout);
      _cache['my_created_orders'] = mine;
      _scheduleCacheSave();
    } catch (e) {
      if (isNetworkError(e)) markOffline();
      // Без 0015 (code у помещений) — без предзагрузки, форма как раньше.
      debugPrint('offline refs: ${e.runtimeType}');
    }
  }

  // Колонки — как у FloorRepo (Floor.columns, PlanItem.*Columns).
  static const _floorColumns =
      'id,object_id,company_id,name,level,sort,plan_path,plan_w,plan_h';
  static const _placeColumns =
      'id,object_id,name,floor_id,plan_x,plan_y,plan_shape,code';
  static const _assetColumns =
      'id,location_id,name,category,inventory_no,meta,floor_id,plan_x,plan_y,'
      'locations!inner(object_id)';

  // ---------------------------------------------------------------------
  // Шаг 28: фото «до» и планы этажей на телефоне
  // ---------------------------------------------------------------------

  static const _photoBucket = 'work-photos';
  static const _planBucket = 'floor-plans';
  final Map<String, Uint8List> _mediaMemo = {};

  Map<String, int> get _media => {
        for (final e in ((_cache['media'] as Map?) ?? const {}).entries)
          '${e.key}': (e.value as num).toInt(),
      };

  /// Скачать байты (не ссылки — ссылки живут час) фото «до» своих заявок
  /// и планов этажей их помещений, в пределах бюджетов (offline_logic.dart);
  /// ненужное (заявку закрыли, передали) — удалить.
  Future<void> _prefetchMedia(
      List<String> ids, List<Map<String, dynamic>> details) async {
    final store = _store;
    if (store == null) return;
    final media = _media;
    try {
      // 1) Фото «до»: метаданные — для карточки без сети, файлы — в бюджет.
      final rows = ids.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _c
              .from('attachments')
              .select('id,work_order_id,stage,storage_path,taken_at,lat,lng,'
                  'mock_location,created_at')
              .inFilter('work_order_id', ids)
              .eq('kind', 'photo')
              .eq('stage', 'before')
              .timeout(requestTimeout);
      _cache.removeWhere((k, _) => k.startsWith('photos:'));
      for (final id in ids) {
        _cache['photos:$id'] = [
          for (final r in rows)
            if (r['work_order_id'] == id) r
        ];
      }
      final keep = beforePhotosToKeep(ids, rows);
      await _syncMedia(
        store,
        media,
        wanted: [
          for (final r in keep)
            (offlinePhotoName('${r['id']}'), '${r['storage_path']}')
        ],
        isKind: isOfflinePhotoName,
        bucket: _photoBucket,
        budget: kOfflinePhotoBudget,
        max: kOfflinePhotoMax,
      );

      // 2) Планы этажей помещений и оборудования своих заявок.
      final places = (_cache['places'] as Map?) ?? const {};
      final locs = {
        for (final l in (places['locations'] as List?) ?? const [])
          if (l is Map) '${l['id']}': l
      };
      final assets = {
        for (final a in (places['assets'] as List?) ?? const [])
          if (a is Map) '${a['id']}': a
      };
      final floors = {
        for (final f in (places['floors'] as List?) ?? const [])
          if (f is Map) '${f['id']}': f
      };
      final floorIds = <String>{
        for (final d in details) ...[
          if (assets[d['asset_id']]?['floor_id'] != null)
            '${assets[d['asset_id']]!['floor_id']}',
          if (locs[d['location_id']]?['floor_id'] != null)
            '${locs[d['location_id']]!['floor_id']}',
        ],
      };
      await _syncMedia(
        store,
        media,
        wanted: [
          for (final f in floorIds)
            if (floors[f]?['plan_path'] != null)
              (
                offlinePlanName(f, '${floors[f]!['plan_path']}'),
                '${floors[f]!['plan_path']}'
              )
        ],
        isKind: isOfflinePlanName,
        bucket: _planBucket,
        budget: kOfflinePlanBudget,
        max: kOfflinePlanMax,
      );
    } catch (e) {
      if (isNetworkError(e)) markOffline();
      debugPrint('offline media: ${e.runtimeType}');
    } finally {
      _cache['media'] = media;
      await _saveCache();
    }
  }

  Future<void> _syncMedia(OfflineStore store, Map<String, int> media,
      {required List<(String, String)> wanted,
      required bool Function(String) isKind,
      required String bucket,
      required int budget,
      required int max}) async {
    final c = mediaCleanup([for (final w in wanted) w.$1], media, isKind);
    for (final n in c.drop) {
      await store.deletePhoto(n);
      media.remove(n);
      _mediaMemo.remove(n);
    }
    var used = c.used;
    for (final (name, path) in wanted) {
      if (media.containsKey(name)) continue;
      if (used >= budget) break;
      final Uint8List bytes;
      try {
        bytes = await _c.storage
            .from(bucket)
            .download(path)
            .timeout(const Duration(seconds: 60));
      } catch (e) {
        if (isNetworkError(e)) rethrow;
        continue; // файла нет или нет прав — пропускаем
      }
      if (!mediaFits(used, bytes.length, budget, max)) continue;
      await store.putPhoto(name, bytes);
      media[name] = bytes.length;
      used += bytes.length;
    }
  }

  Future<Uint8List?> _mediaBytes(String name) async {
    final m = _mediaMemo[name];
    if (m != null) return m;
    if (!_media.containsKey(name)) return null;
    final b = await _store?.getPhoto(name);
    if (b != null && _mediaMemo.length < 40) _mediaMemo[name] = b;
    return b;
  }

  /// Фото «до» заявки с телефона: строки вложений (как с сервера) и байты
  /// тех, что успели сохраниться. null — заявка не предзагружена.
  Future<List<(Map<String, dynamic>, Uint8List?)>?> offlineBeforePhotos(
      String orderId) async {
    final rows = _cache['photos:$orderId'];
    if (rows is! List) return null;
    return [
      for (final r in rows)
        if (r is Map)
          (
            Map<String, dynamic>.from(r),
            await _mediaBytes(offlinePhotoName('${r['id']}'))
          )
    ];
  }

  /// План этажа с телефона (байты картинки); null — не сохранён.
  Future<Uint8List?> planBytes(String floorId, String path) =>
      _mediaBytes(offlinePlanName(floorId, path));

  /// Строки места из предзагрузки: помещение, оборудование, этаж.
  Map<String, dynamic>? cachedPlace(String kind, String? id) {
    if (id == null) return null;
    final places = (_cache['places'] as Map?) ?? const {};
    for (final r in (places[kind] as List?) ?? const []) {
      if (r is Map && r['id'] == id) return Map<String, dynamic>.from(r);
    }
    return null;
  }

  /// Заявки исполнителя из телефона (для списка без сети) — статус уже с
  /// учётом неотправленных действий.
  List<Map<String, dynamic>> myOrders() {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    // Шаг 32: созданные без сети — сверху; потом заявки подрядчика
    // (исполнитель) и свои открытые (все роли).
    for (final r in [
      ...pendingCreates(_queue),
      ...((_cache['my_orders'] as List?) ?? const []),
      ...((_cache['my_created_orders'] as List?) ?? const []),
    ]) {
      if (r is! Map || !seen.add('${r['id']}')) continue;
      out.add({
        ...Map<String, dynamic>.from(r),
        'status': view('${r['id']}', '${r['status']}').status,
      });
    }
    return out;
  }

  /// Есть ли что показать в списке без сети.
  bool get hasOfflineList =>
      _cache['my_orders'] != null ||
      _cache['my_created_orders'] != null ||
      _queue.any((a) => a.kind == OfflineKind.create);

  /// Строка заявки, созданной без сети и ещё не отправленной; null — нет такой.
  Map<String, dynamic>? pendingRow(String orderId) {
    for (final a in _queue) {
      if (a.kind == OfflineKind.create && a.orderId == orderId) {
        return pendingOrderRow(a);
      }
    }
    return null;
  }

  /// Заявка создана без сети и ещё не отправлена.
  bool isPendingCreate(String orderId) =>
      _queue.any((a) => a.kind == OfflineKind.create && a.orderId == orderId);

  Map<String, dynamic>? detail(String id) {
    final d = _cache['detail:$id'];
    return d is Map ? Map<String, dynamic>.from(d) : null;
  }

  List<Map<String, dynamic>>? checklist(String id) {
    final c = _cache['checklist:$id'];
    return c is List
        ? [for (final x in c) Map<String, dynamic>.from(x as Map)]
        : null;
  }

  void putChecklist(String id, List<Map<String, dynamic>> items) =>
      put('checklist:$id', items);

  // ---------------------------------------------------------------------
  // Очередь
  // ---------------------------------------------------------------------

  PendingView view(String orderId, String status) =>
      pendingView(status, _queue, orderId);

  bool shouldQueueFor(String orderId) =>
      supported &&
      _uid != null &&
      shouldQueue(online: online, queue: _queue, orderId: orderId);

  /// Выполнить действие сразу или поставить в очередь: нет сети (или по
  /// заявке уже есть неотправленное) — в очередь; ошибка сети при
  /// отправке — тоже в очередь. true — поставлено в очередь.
  Future<bool> runOrQueue({
    required String orderId,
    required OfflineKind kind,
    Map<String, Object?> payload = const {},
    required Future<void> Function() online,
  }) async {
    if (!supported || _uid == null) {
      await online();
      return false;
    }
    if (shouldQueueFor(orderId)) {
      await enqueue(kind: kind, orderId: orderId, payload: payload);
      return true;
    }
    try {
      await online().timeout(requestTimeout);
      _markOnline();
      return false;
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      markOffline();
      await enqueue(kind: kind, orderId: orderId, payload: payload);
      return true;
    }
  }

  /// Поставить действие в очередь. [photo] — снимок (после штампа),
  /// [device] — когда снято. Путь в хранилище — `<компания>/<заявка>/off_<id>.jpg`.
  Future<OfflineAction> enqueue({
    required OfflineKind kind,
    required String orderId,
    Map<String, Object?> payload = const {},
    Uint8List? photo,
    String? companyId,
    DateTime? device,
  }) async {
    final id = newUuid();
    final reading = await readingAt(device);
    var p = Map<String, Object?>.from(payload);
    String? file;
    if (photo != null) {
      file = '$id.jpg';
      await _store?.putPhoto(file, photo);
      p = {
        ...p,
        'path': '$companyId/$orderId/off_$id.jpg',
        'sha256': sha256.convert(photo).toString(),
      };
    }
    final a = OfflineAction(
        id: id,
        kind: kind,
        orderId: orderId,
        clock: reading,
        payload: p,
        photoFile: file);
    _queue.add(a);
    await _saveQueue();
    notifyListeners();
    _scheduleRetry();
    if (online) unawaited(flush());
    return a;
  }

  /// Шаг 32: новая заявка без сети — в очередь (create), строка — в кэш для
  /// списка и карточки на телефоне, снимок [photo] — фото «до» следом
  /// (тем же порядком отправятся на сервер).
  Future<void> createOrder({
    required String orderId,
    required String companyId,
    required Map<String, Object?> fields,
    ({
      Uint8List bytes,
      DateTime takenAt,
      double? lat,
      double? lng,
      bool mock
    })? photo,
  }) async {
    final a = await enqueue(
        kind: OfflineKind.create,
        orderId: orderId,
        payload: {...fields, 'created_by': _uid});
    put('detail:$orderId', pendingOrderRow(a));
    if (photo != null) {
      await enqueue(
          kind: OfflineKind.photo,
          orderId: orderId,
          companyId: companyId,
          photo: photo.bytes,
          device: photo.takenAt,
          payload: {
            'stage': 'before',
            'lat': photo.lat,
            'lng': photo.lng,
            'mock': photo.mock,
          });
    }
  }

  Future<Uint8List?> photoBytes(OfflineAction a) async =>
      a.photoFile == null ? null : _store?.getPhoto(a.photoFile!);

  void _scheduleRetry() {
    if (_retryTimer != null) return;
    _retryTimer = Timer.periodic(retryEvery, (_) => _retry());
  }

  Future<void> _retry() async {
    if (_queue.isEmpty && online) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    if (forceOffline) return;
    await anchor();
    if (online && _queue.isNotEmpty) await flush();
  }

  /// Тестовый режим: включить / выключить «сеть».
  Future<void> setForceOffline(bool v) async {
    forceOffline = v;
    if (v) {
      _online = false;
      _scheduleRetry();
    } else {
      _online = true;
      await anchor();
      await flush();
    }
    notifyListeners();
  }

  /// Отправить очередь: снимки → проверка отпечатков (Edge Function
  /// `offline-sync`, если выложена) → `offline_sync` в базе.
  Future<void> flush() async {
    if (_sending || _queue.isEmpty || _uid == null || forceOffline) return;
    _sending = true;
    notifyListeners();
    final batch = _queue.take(200).toList();
    try {
      // Шаг 32: сначала новые заявки — снимки «до» кладутся в их папки.
      final parts = splitForSync(batch);
      var failed = 0;
      if (parts.creates.isNotEmpty) {
        failed += await _sync(parts.creates);
      }
      final photos = <Map<String, String>>[];
      for (final a in parts.rest.where((a) => a.kind == OfflineKind.photo)) {
        final bytes = await photoBytes(a);
        final path = a.payload['path'] as String?;
        if (bytes == null || path == null) continue;
        try {
          await _c.storage
              .from('work-photos')
              .uploadBinary(path, bytes,
                  fileOptions: const FileOptions(
                      contentType: 'image/jpeg', upsert: false))
              .timeout(const Duration(seconds: 60));
        } on StorageException catch (e) {
          // уже загружено прошлой попыткой — дальше
          final dup = e.statusCode == '409' || e.message.contains('exists');
          // Нет прав (заявку не создали, отменили) — не загружаем; база
          // ответит «файл не дошёл», и действие уйдёт из очереди, а не
          // будет повторяться вечно.
          final denied = e.statusCode == '403' || e.statusCode == '400';
          if (!dup && !denied) rethrow;
        }
        photos.add({'path': path, 'sha256': '${a.payload['sha256']}'});
      }
      if (photos.isNotEmpty) {
        try {
          await _c.functions.invoke('offline-sync',
              body: {'photos': photos}).timeout(const Duration(seconds: 30));
        } catch (e) {
          // функция не выложена — отпечатки останутся «не сверены»
          if (isNetworkError(e)) rethrow;
          debugPrint('offline-sync verify: ${e.runtimeType}');
        }
      }
      if (parts.rest.isNotEmpty) failed += await _sync(parts.rest);
      await _saveQueue();
      await _saveMeta();
      _markOnline();
      if (failed == 0) {
        _justSent = true;
        _sentTimer?.cancel();
        _sentTimer = Timer(const Duration(seconds: 2), () {
          _justSent = false;
          notifyListeners();
        });
      }
      unawaited(anchor());
      unawaited(prefetch(force: true));
    } catch (e) {
      if (isNetworkError(e)) {
        markOffline();
      } else {
        debugPrint('offline flush: $e');
      }
      _scheduleRetry();
    } finally {
      _sending = false;
      notifyListeners();
    }
    if (_queue.isNotEmpty && online && !_sending && batch.length == 200) {
      unawaited(flush());
    }
  }

  /// Одна отправка `offline_sync`: принятое и отклонённое уходит из
  /// очереди, отклонённое — в «Не отправлено». Возвращает число отказов.
  Future<int> _sync(List<OfflineAction> actions) async {
    final res = await _c.rpc('offline_sync', params: {
      'p_actions': [for (final a in actions) a.toServer()],
    }).timeout(const Duration(seconds: 40));
    final results = {for (final r in SyncResult.parse(res)) r.id: r};
    var failed = 0;
    for (final a in actions) {
      final r = results[a.id];
      if (r == null) continue;
      _queue.removeWhere((x) => x.id == a.id);
      if (a.photoFile != null) await _store?.deletePhoto(a.photoFile!);
      if (a.kind == OfflineKind.create) {
        // Карточку перечитает сервер: строку «ждёт отправки» — убрать.
        _cache.remove('detail:${a.orderId}');
      }
      if (r.outcome != SyncOutcome.applied) {
        failed++;
        _failures.add(SyncFailure(
            kind: a.kind,
            orderId: a.orderId,
            orderTitle: (a.payload['title'] as String?) ??
                detail(a.orderId)?['title'] as String?,
            reason: r.reason ?? SyncReason.other,
            photoKept: r.outcome == SyncOutcome.savedLate,
            before: a.payload['stage'] == 'before'));
      }
    }
    return failed;
  }

  void clearFailures() {
    _failures = [];
    unawaited(_saveMeta());
    notifyListeners();
  }
}
