import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../core/paging.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../floors/floor_models.dart';
import '../floors/floor_repository.dart';
import '../floors/order_plan_link.dart';
import '../floors/plan_logic.dart';
import '../regions/geo_pickers.dart';
import '../photos/live_shot_screen.dart';
import '../photos/photo_capture.dart';
import '../photos/photo_stamp.dart';
import '../ppr/ppr_logic.dart';
import '../ppr/ppr_text.dart';
import '../documents/document_repository.dart';
import '../documents/documents_section.dart';
import '../photos/photo_repository.dart';
import '../photos/photo_section.dart';
import '../photo_identify/identify_log.dart' show newUuid;
import '../offline/offline_banner.dart';
import '../offline/offline_logic.dart';
import '../offline/offline_service.dart';
import 'order_checklist.dart';
import '../acts/act_doc.dart' show actDecisionText;
import '../acts/act_logic.dart' show ActDecision;
import '../acts/proof_decisions.dart';
import '../offline/proof_text.dart';
import '../visits/visit_repository.dart';
import '../visits/visit_section.dart';
import 'contractor_picker.dart';
import 'order_filter.dart';
import 'order_form_place.dart';
import 'order_actions.dart';
import 'order_menu.dart';
import 'work_order.dart';
import '../../core/app_message.dart';
import '../directory/city.dart';
import '../telegram/telegram_repository.dart';

export 'requests_tab.dart';
export 'work_order.dart';

/// Добавляет к запросу условия фильтра ([OrderFilter.serverConditions]).
PostgrestFilterBuilder<T> applyServerConds<T>(
    PostgrestFilterBuilder<T> q, List<ServerCond> conds) {
  for (final c in conds) {
    q = c.column == 'or' ? q.or(c.value) : q.filter(c.column, c.op, c.value);
  }
  return q;
}

/// База не дала удалить заявку (не менеджер или заявка чужой компании).
class OrderDeleteDenied implements Exception {
  const OrderDeleteDenied();
}

class RequestsRepo {
  final SupabaseClient _c = Supabase.instance.client;

  String? get uid => _c.auth.currentUser?.id;

  Future<String?> myRole() async {
    final id = uid;
    if (id == null) return null;
    final r = await OfflineService.instance.cachedJson('my_role',
        () => _c.from('profiles').select('role').eq('id', id).maybeSingle());
    return (r as Map?)?['role'] as String?;
  }

  /// Заявки подрядчика, объекта или помещения (сначала новые). Сколько видно —
  /// решает RLS: менеджер — все, заявитель — свои, исполнитель — своего подрядчика.
  Future<List<Map<String, dynamic>>> listBy(
      {String? contractorId,
      String? objectId,
      String? locationId,
      String? layerId,
      bool openOnly = false,
      int limit = 200}) async {
    var q = _c.from('work_orders').select(
        'id,title,work_type,layer_id,priority,status,recurrence,object_id,location_id,'
        'assigned_contractor_id,created_at,accepted_at,return_count,locations(name)');
    if (contractorId != null) q = q.eq('assigned_contractor_id', contractorId);
    if (objectId != null) q = q.eq('object_id', objectId);
    if (locationId != null) q = q.eq('location_id', locationId);
    if (layerId != null) q = q.eq('layer_id', layerId);
    if (openOnly) q = q.not('status', 'in', '(done,cancelled)');
    return await q.order('created_at', ascending: false).limit(limit);
  }

  /// Заявки для карты объектов: только объект, статус, срочность и срок.
  /// Видно столько, сколько разрешает RLS.
  Future<List<Map<String, dynamic>>> mapOrders() => fetchAll(() => _c
      .from('work_orders')
      .select('id,object_id,status,priority,due_at')
      .order('id'));

  /// Заявки списка «Заявки» с условиями фильтра (на сервере, поверх RLS).
  /// Читает страницами: заявок может быть больше 1000.
  Future<List<WorkOrder>> listFiltered(List<ServerCond> conds) async {
    // С полями ППР (0015); без миграции — прежние колонки.
    Future<List<Map<String, dynamic>>> read(String columns) => fetchAll(() =>
        applyServerConds(_c.from('work_orders').select(columns), conds)
            .order('created_at', ascending: false)
            .order('id'));
    final rows = await SchemaCompat.run(
        '0015', () => read(WorkOrder.listColumns0015),
        legacy: () => read(WorkOrder.listColumns));
    return rows.map(WorkOrder.fromMap).toList();
  }

  /// Сколько заявок подходит под условия — только число, без строк
  /// («Показать N заявок» в окне «Фильтры»).
  Future<int> countFiltered(List<ServerCond> conds) =>
      applyServerConds(_c.from('work_orders').count(CountOption.exact), conds);

  /// Заявки канала за последние [days] дней (плашки на главной, шаг 24).
  Future<int> countChannel(String channel, {int days = 7}) => _c
      .from('work_orders')
      .count(CountOption.exact)
      .eq('input_channel', channel)
      .gte(
          'created_at',
          DateTime.now()
              .subtract(Duration(days: days))
              .toUtc()
              .toIso8601String());

  /// Сколько всего заявок видно пользователю (без фильтров) — «из M».
  Future<int> countAll() => _c.from('work_orders').count(CountOption.exact);

  /// Мои записи исполнителя (executors.id) — для «Назначено мне».
  Future<List<String>> myExecutorIds() async {
    final id = uid;
    if (id == null) return const [];
    final rows = await OfflineService.instance.cachedJson('my_executor_ids',
        () => _c.from('executors').select('id').eq('profile_id', id));
    return [for (final r in (rows as List)) r['id'] as String];
  }

  /// Без сети (шаг 27) — последняя сохранённая карточка.
  Future<Map<String, dynamic>?> detail(String id) async {
    final d = await OfflineService.instance
        .cachedJson('detail:$id', () => _detail(id));
    return d == null ? null : Map<String, dynamic>.from(d as Map);
  }

  Future<Map<String, dynamic>?> _detail(String id) => SchemaCompat.run(
      '0015',
      () => _c
          .from('work_orders')
          .select('*,locations(name,code)')
          .eq('id', id)
          .maybeSingle(),
      legacy: () => _c
          .from('work_orders')
          .select('*,locations(name)')
          .eq('id', id)
          .maybeSingle());

  /// Новая заявка. [id] — заранее (узнавание по фото: к заявке сразу
  /// прикладывается снимок; автор видит свою заявку по RLS).
  Future<void> create(
      {String? id,
      required String companyId,
      required String title,
      String? description,
      Layer? layer,
      required String priority,
      String? objectId,
      required bool recurring,
      String? locationId,
      String? assetId,
      String inputChannel = 'button'}) async {
    // id — из приложения: после вставки по нему зовём telegram-notify.
    final oid = id ?? newUuid();
    // Слой передаём явно: тогда назначение подрядчика не зависит от языка интерфейса.
    await _c.from('work_orders').insert({
      'id': oid,
      'company_id': companyId,
      'title': title,
      'description': description,
      'work_type': layer?.name,
      'layer_id': layer?.id,
      'priority': priority,
      'status': 'new',
      'input_channel': inputChannel,
      'object_id': objectId,
      'location_id': locationId,
      if (assetId != null) 'asset_id': assetId,
      'recurrence': recurring ? {'kind': 'regular'} : null,
      'created_by': uid,
    });
    // База могла сразу назначить подрядчика (по системе и объекту) — его
    // исполнителям «Новая заявка» в Telegram (шаг 28; нет подрядчика — ничего).
    notifyAssigned(oid);
  }

  Future<void> update(String id,
      {required String title,
      String? description,
      Layer? layer,
      required String priority,
      String? objectId,
      required bool recurring,
      Object? keepRecurrence,
      bool setLocation = false,
      String? locationId}) async {
    await _c.from('work_orders').update({
      'title': title,
      if (setLocation) 'location_id': locationId,
      'description': description,
      'work_type': layer?.name,
      'layer_id': layer?.id,
      'priority': priority,
      'object_id': objectId,
      'recurrence': keepRecurrence ?? (recurring ? {'kind': 'regular'} : null),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Имя конкретного исполнителя заявки (executors → profiles).
  /// Объекты последних заявок текущего пользователя (новые — первыми) —
  /// для кнопок «Недавние» в форме новой заявки.
  Future<List<String?>> recentObjectIds() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _c
        .from('work_orders')
        .select('object_id')
        .eq('created_by', uid)
        .not('object_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(30);
    return [for (final r in rows as List) r['object_id'] as String?];
  }

  Future<String?> executorName(String executorId) async {
    final r = await _c
        .from('executors')
        .select('profiles(full_name)')
        .eq('id', executorId)
        .maybeSingle();
    return (r?['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;
  }

  Future<void> assign(String id, String contractorId) async {
    await _c.from('work_orders').update({
      'assigned_contractor_id': contractorId,
      'status': 'assigned',
      'assigned_by': 'manager',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    notifyAssigned(id);
  }

  /// Подрядчики, где текущий пользователь — исполнитель (`executors`).
  /// Кэш на время работы приложения: состав меняется редко.
  static final Map<String, Set<String>> _myContractors = {};

  Future<Set<String>> myContractorIds() async {
    final me = uid;
    if (me == null) return const {};
    final cached = _myContractors[me];
    if (cached != null) return cached;
    final rows = await OfflineService.instance.cachedJson(
        'my_contractor_rows',
        () =>
            _c.from('executors').select('contractor_id').eq('profile_id', me));
    return _myContractors[me] = {
      for (final r in (rows as List)) r['contractor_id'] as String,
    };
  }

  Future<void> setStatus(String id, String status) async {
    await _c.from('work_orders').update({'status': status}).eq('id', id);
  }

  /// Шаг 24: сообщить автору в Telegram о новом статусе (Edge Function
  /// telegram-notify). Что и кому — решает функция по базе; ошибки и
  /// «функция не выложена» — тихо, смена статуса уже сохранена.
  void notifyTelegram(String id) {
    unawaited(_c.functions
        .invoke('telegram-notify', body: {'orderId': id})
        .timeout(const Duration(seconds: 20))
        .then((_) {},
            onError: (e) => debugPrint('telegram-notify: ${e.runtimeType}')));
  }

  /// Шаг 28: исполнителям назначенного подрядчика — «Новая заявка» в Telegram
  /// с кнопкой «Взять в работу» (telegram-notify, kind: assigned). Кому —
  /// решает база (бригады, отписка, повтор не шлёт); ошибки — тихо.
  void notifyAssigned(String id) {
    unawaited(_c.functions
        .invoke('telegram-notify', body: {'orderId': id, 'kind': 'assigned'})
        .timeout(const Duration(seconds: 20))
        .then((_) {},
            onError: (e) => debugPrint('telegram-notify: ${e.runtimeType}')));
  }

  /// Удалить заявку навсегда — только менеджер (политика `wo_delete`).
  /// Сначала файлы фото из Storage, затем сама заявка; визиты, вложения,
  /// чек-листы и история удаляются базой каскадом. Возвращает, сколько файлов
  /// осталось в Storage: правило хранилища (0006) разрешает удалять только
  /// свои файлы, чужие фото остаются (без заявки их никто не видит).
  /// RLS не дал удалить — [OrderDeleteDenied].
  Future<int> deleteOrder(String id) async {
    final rows = await _c
        .from('attachments')
        .select('storage_path,kind')
        .eq('work_order_id', id);
    // Фото — в work-photos, документы (0019) — в order-files.
    final byBucket = <String, List<String>>{};
    for (final r in rows) {
      if (r['storage_path'] is! String) continue;
      final bucket = r['kind'] == 'document'
          ? DocumentRepository.bucket
          : PhotoRepository.bucket;
      (byBucket[bucket] ??= []).add(r['storage_path'] as String);
    }
    final paths = [for (final p in byBucket.values) ...p];
    var removed = 0;
    for (final e in byBucket.entries) {
      try {
        removed += (await _c.storage.from(e.key).remove(e.value)).length;
      } catch (err) {
        debugPrint('deleteOrder files: ${err.runtimeType}');
      }
    }
    final deleted =
        await _c.from('work_orders').delete().eq('id', id).select('id');
    if (deleted.isEmpty) throw const OrderDeleteDenied();
    return paths.length - removed;
  }

  /// Вернуть работу на доработку с комментарием (только автор или менеджер).
  Future<void> returnForRework(String id, String reason) async {
    await _c
        .from('work_orders')
        .update({'status': 'returned', 'return_reason': reason}).eq('id', id);
  }
}

String _objNameIn(AppLocalizations l, List<Obj> objects, String? id) {
  if (id == null) return l.objectNone;
  for (final o in objects) {
    if (o.id == id) return objectDisplayName(o);
  }
  return l.objectUnknown;
}

String _contractorNameIn(
    AppLocalizations l, List<Contractor> list, String? id) {
  if (id == null) return l.contractorNone;
  for (final c in list) {
    if (c.id == id) return c.orgName;
  }
  return l.contractorUnknown;
}

/// Вид работ заявки на языке интерфейса.
String? _workTypeLabel(List<Layer> layers, String locale,
    {String? layerId, String? workType}) {
  final layer = Layer.find(layers, id: layerId, name: workType);
  if (layer != null) return layer.label(locale);
  return (workType == null || workType.isEmpty) ? null : workType;
}

class WorkOrderDetailScreen extends StatefulWidget {
  const WorkOrderDetailScreen(
      {super.key,
      required this.order,
      required this.objects,
      required this.contractors,
      required this.layers,
      required this.uid,
      required this.role,
      required this.repo,
      required this.companyId});
  final WorkOrder order;
  final List<Obj> objects;
  final List<Contractor> contractors;
  final List<Layer> layers;
  final String? uid;
  final String? role;
  final RequestsRepo repo;
  final String? companyId;

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  final _photoRepo = PhotoRepository();
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;
  List<WorkPhoto> _photos = const [];
  bool _photosFailed = false;
  bool _uploading = false;
  final _visitRepo = VisitRepository();
  List<Visit> _visits = const [];
  bool _visitsFailed = false;
  bool _starting = false;
  String? _executorName;
  Set<String> _myContractorIds = const {};

  @override
  void initState() {
    super.initState();
    _off.addListener(_onOffline);
    _load();
  }

  @override
  void dispose() {
    _off.removeListener(_onOffline);
    super.dispose();
  }

  /// Шаг 27: очередь без сети — статус и отметки «ждут отправки».
  final _off = OfflineService.instance;
  int _lastPending = 0;
  void _onOffline() {
    if (!mounted) return;
    final p = _off.view(widget.order.id, _rawStatus).count;
    // Очередь по заявке ушла на сервер — перечитать карточку.
    if (_lastPending > 0 && p == 0 && _off.online) unawaited(_load());
    _lastPending = p;
    setState(() {});
  }

  String get _rawStatus => (_d?['status'] ?? widget.order.status) as String;

  /// Статус с учётом действий, которые ещё не ушли на сервер.
  PendingView get _pending => _off.view(widget.order.id, _rawStatus);
  final _checklistKey = GlobalKey<OrderChecklistSectionState>();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.repo.detail(widget.order.id);
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
      });
      await Future.wait([
        _loadMyContractors(),
        _loadPhotos(),
        if (_isManager) _loadVisits(),
        if (_isManager) _loadDecision(),
        _loadExecutor(d?['assigned_executor_id'] as String?),
      ]);
    } catch (e) {
      debugPrint('WorkOrderDetail: $e');
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMyContractors() async {
    try {
      final ids = await widget.repo.myContractorIds();
      if (mounted) setState(() => _myContractorIds = ids);
    } catch (e) {
      debugPrint('my contractors: $e');
    }
  }

  Future<void> _loadExecutor(String? executorId) async {
    if (executorId == null) {
      if (mounted) setState(() => _executorName = null);
      return;
    }
    try {
      final name = await widget.repo.executorName(executorId);
      if (mounted) setState(() => _executorName = name);
    } catch (e) {
      debugPrint('executor: $e');
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _photoRepo.list(widget.order.id);
      if (mounted) {
        setState(() {
          _photos = photos;
          _photosFailed = false;
        });
      }
    } catch (e) {
      debugPrint('photos: $e');
      // Без сети фото с сервера не показать — это не ошибка карточки.
      if (mounted) setState(() => _photosFailed = !isNetworkError(e));
    }
  }

  Future<void> _loadVisits() async {
    try {
      final visits = await _visitRepo.list(widget.order.id);
      if (mounted) {
        setState(() {
          _visits = visits;
          _visitsFailed = false;
        });
      }
    } catch (e) {
      debugPrint('visits: $e');
      if (mounted) setState(() => _visitsFailed = true);
    }
  }

  /// «Начать работу»: статус «в работе» и, у исполнителя, отметка посещения
  /// с координатами. Вне геозоны работать можно — база лишь помечает визит.
  /// Без сети (шаг 27) — оба действия в очередь телефона, GPS работает и
  /// без интернета: «📍 В геозоне» считается на телефоне.
  Future<void> _startWork() async {
    final l = context.l10n;
    final d = _d!;
    final id = widget.order.id;
    final recordVisit = _can.isExecutor && d['object_id'] != null;
    setState(() => _starting = true);
    try {
      // Координаты ищутся, пока меняется статус.
      final positionFuture = recordVisit
          ? ensureLocationPermission()
              .then((ok) => ok ? currentPosition() : null)
          : Future.value(null);
      final bool queued;
      try {
        queued = await _off.runOrQueue(
            orderId: id,
            kind: OfflineKind.start,
            online: () => widget.repo.setStatus(id, 'in_progress'));
      } catch (e) {
        _ok(l.statusError(e, to: 'in_progress'), type: AppMessageType.error);
        return;
      }
      if (!queued) _notifyTelegram();
      var message = queued ? l.offQueuedToast : l.toastInProgress;
      var type = queued ? AppMessageType.info : AppMessageType.success;
      if (recordVisit) {
        final position = await positionFuture;
        final payload = <String, Object?>{
          'lat': position?.latitude,
          'lng': position?.longitude,
          'accuracy': position?.accuracy,
          'mock': position?.isMocked ?? false,
        };
        try {
          final visitQueued = await _off.runOrQueue(
              orderId: id,
              kind: OfflineKind.visit,
              payload: payload,
              online: () => _visitRepo.start(
                  workOrderId: id,
                  companyId: widget.companyId ?? (d['company_id'] as String),
                  position: position));
          if (visitQueued) {
            message = '${l.offQueuedToast}\n${_zoneText(l, position)}';
            type = AppMessageType.info;
          } else if (position == null) {
            message = l.visitNoLocation;
            type = AppMessageType.info;
          }
        } on PostgrestException catch (e) {
          // 23505 — у человека уже есть открытый визит по заявке (uq_visits_open,
          // миграция 0009): кнопку нажали повторно или с устаревшего экрана.
          debugPrint('visit: $e');
          message = e.code == '23505' ? l.visitAlreadyOpen : l.visitNotRecorded;
          type = AppMessageType.info;
        } catch (e) {
          debugPrint('visit: $e');
          message = l.visitNotRecorded;
          type = AppMessageType.info;
        }
      }
      if (!queued) await _load();
      // Работа начата, но визит без координат или не записан — это не успех.
      _ok(message, type: type);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// «📍 В геозоне» / «Вне геозоны · 240 м» / «Нет GPS» — на телефоне.
  String _zoneText(AppLocalizations l, Position? p) {
    final g = _geofence(_d?['object_id'] as String?);
    if (p == null) return l.offVisitNoGps;
    if (g == null) return l.offVisitInZone;
    final m = const Distance().as(LengthUnit.Meter,
        LatLng(p.latitude, p.longitude), LatLng(g.lat, g.lng));
    final tol = p.accuracy.clamp(0, 50);
    return m <= g.radiusM + tol
        ? l.offVisitInZone
        : l.offVisitOutZone(m.round());
  }

  bool get _hasAfterPhoto =>
      _photos.any((p) => p.stage != 'before') || _pending.photos.isNotEmpty;

  /// Съёмка и загрузка фото «до» (автор) или «после» (исполнитель).
  Future<void> _addPhoto(String stage) async {
    final l = context.l10n;
    final companyId = widget.companyId ?? (_d!['company_id'] as String);
    final CapturedPhoto? photo;
    try {
      // «После» — только живой камерой со штампом (шаг 26); «до» — как раньше.
      photo = stage == 'after'
          ? await captureLivePhoto(context, stamp: _stamp())
          : await capturePhoto();
    } on CaptureException catch (e) {
      _ok(
          e.problem == CaptureProblem.cameraDenied
              ? l.photoCameraDenied
              : l.photoCameraFailed,
          type: AppMessageType.error);
      return;
    }
    if (photo == null || !mounted) return;
    final shot = photo;
    setState(() => _uploading = true);
    final id = widget.order.id;
    // Фото «после» без сети (шаг 27): файлом в каталоге приложения и в
    // очередь; отпечаток SHA-256 — от снимка уже со штампом.
    Future<void> queue() => _off.enqueue(
            kind: OfflineKind.photo,
            orderId: id,
            companyId: companyId,
            photo: shot.bytes,
            device: shot.takenAt,
            payload: {
              'lat': shot.lat,
              'lng': shot.lng,
              'mock': shot.mockLocation,
            });
    final offlineOk =
        stage == 'after' && OfflineService.supported && _off.attached;
    try {
      if (offlineOk && _off.shouldQueueFor(id)) {
        await queue();
        _ok(l.offQueuedToast, type: AppMessageType.info);
        return;
      }
      await _photoRepo.upload(
          companyId: companyId, workOrderId: id, stage: stage, photo: photo);
      await _loadPhotos();
      _ok(l.photoUploaded);
    } catch (e) {
      debugPrint('upload: $e');
      if (offlineOk && isNetworkError(e)) {
        _off.markOffline();
        await queue();
        _ok(l.offQueuedToast, type: AppMessageType.info);
        return;
      }
      _ok(l.photoUploadFailed, type: AppMessageType.error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Штамп фото «после»: объект, помещение заявки и геозона объекта.
  PhotoStamp _stamp() {
    final d = _d!;
    final objId = d['object_id'] as String?;
    final obj = widget.objects.where((o) => o.id == objId).firstOrNull;
    final loc = d['locations'] as Map<String, dynamic>?;
    return PhotoStamp(
        object: obj == null ? null : objectDisplayName(obj),
        place: loc?['name'] == null
            ? null
            : placeLabel(loc!['name'] as String, loc['code'] as String?),
        geofence: _geofence(objId),
        offline: OfflineService.supported && !_off.online,
        timeFix: OfflineService.supported && _off.attached
            ? _off.stampTimeFor
            : null);
  }

  /// Заявка из Telegram — автор узнает о новом статусе в чате (шаг 24).
  void _notifyTelegram() {
    if (_d?['input_channel'] == 'telegram') {
      widget.repo.notifyTelegram(widget.order.id);
    }
  }

  bool get _isAuthor => widget.uid != null && _d?['created_by'] == widget.uid;
  bool get _isManager => widget.role == 'admin' || widget.role == 'manager';
  bool get _isExecutor =>
      widget.role == 'executor' || widget.role == 'contractor';

  /// Что можно этому пользователю с этой заявкой — одна функция (шаг 26).
  OrderActions get _can => orderActions(
        OrderActor(
            role: widget.role,
            uid: widget.uid,
            contractorIds: _myContractorIds),
        status: _pending.status,
        createdBy: _d?['created_by'] as String?,
        contractorId: _d?['assigned_contractor_id'] as String?,
        submittedBy: _d?['submitted_by'] as String?,
      );
  bool get _canEdit => _d != null && _can.edit;

  Future<void> _edit() async {
    final ok = await showOrderForm(
        context: context,
        repo: widget.repo,
        objects: widget.objects,
        companyId: widget.companyId ?? (_d!['company_id'] as String),
        existing: _d);
    if (ok == true) {
      await _load();
      if (mounted) _ok(context.l10n.toastSaved);
    }
  }

  Future<void> _assign() async {
    final l = context.l10n;
    if (widget.contractors.isEmpty) {
      _ok(l.assignNoContractors(l.tabContractors), type: AppMessageType.info);
      return;
    }
    final d = _d!;
    final chosen = await pickContractor(context,
        contractors: widget.contractors,
        layerId: d['layer_id'] as String?,
        layerLabel: _workTypeLabel(widget.layers, context.localeCode,
            layerId: d['layer_id'] as String?,
            workType: d['work_type'] as String?),
        objectId: d['object_id'] as String?,
        currentId: d['assigned_contractor_id'] as String?);
    if (chosen == null) return;
    try {
      await widget.repo.assign(widget.order.id, chosen.id);
      await _load();
      _ok(l.toastAssignedTo(chosen.orgName));
    } catch (e) {
      debugPrint('assign: $e');
      _ok(l.errorGeneric, type: AppMessageType.error);
    }
  }

  Future<void> _setStatus(String status, String okText) async {
    final l = context.l10n;
    try {
      await widget.repo.setStatus(widget.order.id, status);
      _notifyTelegram();
      await _load();
      _ok(okText);
    } catch (e) {
      _ok(l.statusError(e, to: status), type: AppMessageType.error);
    }
  }

  /// «Выполнено, на проверку» — без сети в очередь (шаг 27).
  Future<void> _submit() async {
    final l = context.l10n;
    final id = widget.order.id;
    try {
      final queued = await _off.runOrQueue(
          orderId: id,
          kind: OfflineKind.submit,
          online: () => widget.repo.setStatus(id, 'on_review'));
      if (queued) {
        _ok(l.offQueuedToast, type: AppMessageType.info);
        return;
      }
      _notifyTelegram();
      await _load();
      _ok(l.toastSubmitted);
    } catch (e) {
      _ok(l.statusError(e, to: 'on_review'), type: AppMessageType.error);
    }
  }

  Future<void> _returnForRework() async {
    final l = context.l10n;
    final c = TextEditingController();
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.actionReturn,
      // В белом диалоге поле — серое, иначе его не видно.
      content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
              hintText: l.returnHint, fillColor: AppColors.fill)),
      actions: [
        AppDialogAction(l.returnConfirm, true, primary: true),
        AppDialogAction(l.commonCancel, false),
      ],
    );
    final reason = c.text.trim();
    c.dispose();
    if (ok != true) return;
    if (reason.isEmpty) {
      _ok(l.returnReasonRequired, type: AppMessageType.info);
      return;
    }
    try {
      await widget.repo.returnForRework(widget.order.id, reason);
      _notifyTelegram();
      await _load();
      _ok(l.toastReturned);
    } catch (e) {
      _ok(l.statusError(e, to: 'returned'), type: AppMessageType.error);
    }
  }

  void _ok(String m, {AppMessageType type = AppMessageType.success}) {
    if (mounted) showAppMessage(context, m, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bar = _loading || _error != null ? null : _bottomBar();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: bar != null,
            child: CustomScrollView(slivers: [
              const SliverToBoxAdapter(child: OfflineBanner()),
              AppSliverHeader(
                title: l.detailTitle,
                large: false,
                backLabel: l.tabRequests,
                actions: [
                  if (_canEdit)
                    AppIconButton(
                        icon: AppIcons.edit,
                        label: l.detailEdit,
                        onPressed: _edit),
                  if (_d != null)
                    OrderMenu(
                        canCancel: _canCancel,
                        canDelete: _isManager,
                        onCancel: () =>
                            _setStatus('cancelled', l.toastCancelled),
                        onDelete: _delete),
                ],
              ),
              if (_loading)
                const SliverFillRemaining(
                    hasScrollBody: false, child: AppLoader())
              else if (_error != null)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                        text: l.detailLoadFailed,
                        error: true,
                        actionLabel: l.commonRetry,
                        onAction: _load))
              else
                SliverContent(
                    top: AppSpace.l,
                    sliver: SliverList.list(children: _content())),
              const SliverBottomInset(),
            ]),
          ),
        ),
        if (bar != null) bar,
      ]),
    );
  }

  /// Главные действия по роли и статусу — внизу экрана, не уезжают при
  /// прокрутке: основная кнопка и, если есть, круглая вторичная.
  /// У заявителя панели нет (его кнопки — в блоке «Действия»).
  Widget? _bottomBar() {
    final (main, extra) = _primary();
    if (main == null) return null;
    return BottomActionBar(
      child: Row(children: [
        Expanded(child: main),
        if (extra != null) ...[const SizedBox(width: AppSpace.m), extra],
      ]),
    );
  }

  List<Widget> _content() {
    final l = context.l10n;
    final d = _d!;
    final status = _pending.status;
    final priority = (d['priority'] ?? 'normal') as String;
    final recurring = d['recurrence'] != null;
    final ppr = isPprOrder(d);
    final pprLine = ppr
        ? pprTaskLine(l,
            recurrence: d['recurrence'],
            periodStart: d['period_start'],
            periodEnd: d['period_end'])
        : null;
    final title = (d['title'] ?? '') as String;
    final desc = (d['description'] ?? '') as String?;
    final workType = _workTypeLabel(widget.layers, context.localeCode,
        layerId: d['layer_id'] as String?, workType: d['work_type'] as String?);
    final objId = d['object_id'] as String?;
    final loc = d['locations'] as Map<String, dynamic>?;
    final place = loc?['name'] == null
        ? null
        : placeLabel(loc!['name'] as String, loc['code'] as String?);
    final contractorId = d['assigned_contractor_id'] as String?;
    final created = DateTime.tryParse('${d['created_at']}');
    final createdText = created == null ? '—' : l.dateTime(created);
    final due = DateTime.tryParse('${d['due_at'] ?? ''}');
    final open = status != 'done' && status != 'cancelled';
    final overdue = open && due != null && due.isBefore(DateTime.now());
    final channel = switch (d['input_channel']) {
      'voice' => l.reqViaVoice,
      'text' => l.reqViaText,
      'telegram' => l.reqViaTelegram,
      _ => null,
    };
    final noDesc = desc == null || desc.isEmpty;
    final actions = _actions(status);
    final reporter = telegramReporterLabel(l, d['reporter']);

    return [
      Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
        StatusPill(status, large: true),
        if (_pending.pending)
          StatusPill('returned',
              label: '${l.offPendingBadge} · ${_pending.count}', large: true),
        PriorityPill(priority, large: true),
        if (overdue) StatusPill('overdue', label: l.statusOverdue, large: true),
      ]),
      const SizedBox(height: AppSpace.m),
      Text(
          title +
              (ppr
                  ? '  · ${l.pprTag}'
                  : (recurring ? '  · ${l.requestRecurringTag}' : '')),
          style: AppText.title),
      const SizedBox(height: AppSpace.xs),
      Text(
          [
            '${l.fieldCreated} ${_isAuthor ? l.createdByYou(createdText) : createdText}',
            if (channel != null) channel,
          ].join(' · '),
          style: AppText.footnote),
      const SizedBox(height: AppSpace.l),
      AppGroup(children: [
        // Кто написал в Telegram (шаг 23): «Мария К. · гость».
        if (reporter != null)
          AppRow(
              leading: const LeadingIcon(AppIcons.telegram),
              title: l.tgReporter,
              value: reporter),
        AppRow(
            leading: const LeadingIcon(AppIcons.building),
            title: l.fieldObject,
            value: _objNameIn(l, widget.objects, objId)),
        if (place != null && place.isNotEmpty)
          AppRow(
              leading: const LeadingIcon(AppIcons.room),
              title: l.reqFieldPlace,
              value: place),
        AppRow(
            leading: const LeadingIcon(AppIcons.workType),
            title: l.fieldWorkType,
            value: workType ?? '—'),
        AppRow(
          leading: const LeadingIcon(AppIcons.contractor),
          title: l.fieldContractor,
          subtitle: _contractorNameIn(l, widget.contractors, contractorId),
          subtitleMaxLines: 2,
          trailing: _can.assign
              ? AppButton.tinted(
                  small: true,
                  expand: false,
                  label: contractorId == null
                      ? l.assignInline
                      : l.assignChangeInline,
                  onPressed: _assign)
              : null,
        ),
        if (_executorName != null && _executorName!.isNotEmpty)
          AppRow(
              leading: const LeadingIcon(AppIcons.executor),
              title: l.fieldExecutor,
              value: _executorName!),
        // Задача ППР: «ППР · октябрь 2026 · до 31 окт.», исполнителю —
        // «Выполнить в течение периода».
        if (pprLine != null)
          AppRow(
            leading: overdue
                ? const LeadingIcon.danger(AppIcons.calendar)
                : const LeadingIcon(AppIcons.calendar),
            title: pprLine,
            subtitle: _can.isExecutor ? l.pprDoWithin : null,
            chevron: false,
          )
        else if (due != null)
          AppRow(
            leading: overdue
                ? const LeadingIcon.danger(AppIcons.clock)
                : const LeadingIcon(AppIcons.clock),
            title: l.reqFieldDue,
            trailing: Text(l.dateTime(due),
                style: AppText.body.copyWith(
                    color: overdue ? AppColors.danger : AppColors.secondary,
                    fontWeight: overdue ? FontWeight.w600 : null)),
          ),
      ]),
      // «Показать на плане» — если у помещения или оборудования есть точка.
      OrderPlanLink(
          orderId: widget.order.id,
          objectId: objId,
          locationId: d['location_id'] as String?,
          assetId: d['asset_id'] as String?),
      AppGroup(children: [
        AppRow(
            title: l.fieldKind,
            value: ppr
                ? l.pprKindOrder
                : (recurring ? l.kindRecurring : l.kindOneOff)),
        AppRow(
            title: l.fieldPhotoProof,
            value: (d['requires_photo'] == true)
                ? l.photoRequired
                : l.photoNotRequired),
      ]),
      if ((d['return_reason'] as String?)?.isNotEmpty == true &&
          status == 'returned')
        AppCard(
          color: StatusColors.returned.background,
          child: Text(l.returnedWithReason('${d['return_reason']}'),
              style: AppText.callout.copyWith(
                  color: StatusColors.returned.foreground,
                  fontWeight: FontWeight.w600)),
        ),
      AppGroup(header: l.fieldDescription, children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpace.rowH, vertical: AppSpace.rowV),
          child: Text(noDesc ? l.noDescription : desc,
              style: AppText.body.copyWith(
                  color: noDesc ? AppColors.secondary : AppColors.ink)),
        ),
      ]),
      // Чек-лист (шаг 27): отмечает исполнитель, в том числе без сети.
      OrderChecklistSection(
        key: _checklistKey,
        orderId: widget.order.id,
        canCheck: _can.addAfterPhoto,
        pending: _pending.checked,
      ),
      if (_pending.photos.isNotEmpty)
        PendingPhotosRow(actions: _pending.photos),
      if (_photos.isNotEmpty ||
          _photosFailed ||
          _can.addBeforePhoto ||
          _can.addAfterPhoto)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpace.group),
          child: WorkPhotosSection(
            photos: _photos,
            loadFailed: _photosFailed,
            busy: _uploading,
            geofence: _geofence(objId),
            onAddBefore: _can.addBeforePhoto ? () => _addPhoto('before') : null,
            onAddAfter: _can.addAfterPhoto ? () => _addPhoto('after') : null,
          ),
        ),
      // Документы (шаг 24, 0019): видят все, кто видит заявку; прикрепляют
      // автор, менеджер и исполнитель подрядчика; в отменённую — нельзя.
      OrderDocumentsSection(
        key: ValueKey('docs-${widget.order.id}'),
        orderId: widget.order.id,
        companyId: widget.companyId ?? (d['company_id'] as String),
        canUpload:
            status != 'cancelled' && (_isAuthor || _isManager || _isExecutor),
        isManager: _isManager,
        uid: widget.uid,
      ),
      if (_isManager && (_visits.isNotEmpty || _visitsFailed))
        VisitsSection(visits: _visits, loadFailed: _visitsFailed),
      // Шаг 27: как сняты фото и отмечен визит без сети, решение менеджера.
      if (_isManager) ..._proofLines(l),
      if (actions.isNotEmpty) ...[
        SectionHeader(l.actionsTitle),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s),
          actions[i],
        ],
      ],
    ];
  }

  ProofDecision? _decision;

  Future<void> _loadDecision() async {
    try {
      final d = await ProofDecisionsRepo().latest([widget.order.id]);
      if (mounted) setState(() => _decision = d[widget.order.id]);
    } catch (e) {
      debugPrint('decision: ${e.runtimeType}');
    }
  }

  /// «Снято без сети в 14:19 · время по GPS ✓ · отправлено в 14:25» —
  /// у каждого фото «после» и визита без сети; решение менеджера, если есть.
  List<Widget> _proofLines(AppLocalizations l) {
    final lines = <(String, String)>[
      for (final p in _photos.where((p) => p.stage != 'before'))
        if (offlineProofLine(l,
                offline: p.offline,
                trust: p.timeTrust,
                at: p.trustedAt ?? p.takenAt,
                synced: p.syncedAt,
                driftS: p.driftS,
                syncNote: p.syncNote,
                sha256Ok: p.sha256Ok)
            case final t?)
          (l.offKindPhoto, t),
      for (final v in _visits)
        if (offlineProofLine(l,
                offline: v.offline,
                trust: v.timeTrust,
                at: v.startedAt,
                synced: v.syncedAt,
                driftS: v.driftS,
                visit: true)
            case final t?)
          (l.offKindVisit, t),
    ];
    final d = _decision;
    final decision = d == null
        ? null
        : actDecisionText(
            l,
            ActDecision(
                approve: d.approve, at: d.at, by: d.byName, reason: d.reason));
    if (lines.isEmpty && decision == null) return const [];
    return [
      AppGroup(header: l.proofTitle, children: [
        for (final (title, t) in lines)
          AppRow(
              leading: t.contains('⚠️') || t.contains(l.proofNeedsDecision)
                  ? LeadingIcon(AppIcons.warning,
                      color: StatusColors.newOrder.foreground,
                      background: StatusColors.newOrder.background)
                  : const LeadingIcon(AppIcons.verified),
              title: title,
              subtitle: t,
              subtitleMaxLines: 5,
              chevron: false),
        if (decision != null)
          AppRow(
              leading: const LeadingIcon.neutral(AppIcons.act),
              title: l.actByManager,
              subtitle: decision,
              subtitleMaxLines: 5,
              chevron: false),
      ]),
    ];
  }

  /// Геозона объекта заявки — для подписи фото «в геозоне».
  PhotoGeofence? _geofence(String? objectId) {
    final o = widget.objects.where((o) => o.id == objectId).firstOrNull;
    if (o?.lat == null || o?.lng == null) return null;
    return PhotoGeofence(lat: o!.lat!, lng: o.lng!, radiusM: o.geofenceRadiusM);
  }

  // Без фото «после» кнопка «На проверку» неактивна; база проверяет то же.
  bool get _needPhoto => _d?['requires_photo'] == true && !_hasAfterPhoto;

  Widget _startButton(String status) => AppButton.primary(
        onPressed: _starting ? null : _startWork,
        loading: _starting,
        icon: AppIcons.play,
        label: status == 'returned'
            ? context.l10n.actionRestart
            : context.l10n.actionStart,
      );

  Widget _photoButton({bool primary = true}) => AppButton(
        kind: primary ? AppButtonKind.primary : AppButtonKind.tinted,
        onPressed: _uploading ? null : () => _addPhoto('after'),
        loading: _uploading,
        icon: AppIcons.camera,
        label: context.l10n.photoTakeResult,
      );

  Widget _submitButton() => AppButton.primary(
        onPressed: _needPhoto ? null : _submit,
        icon: AppIcons.check,
        label: context.l10n.actionSubmit,
      );

  Widget _acceptButton() => AppButton.primary(
        onPressed: () => _setStatus('done', context.l10n.toastAccepted),
        icon: AppIcons.verified,
        label: context.l10n.actionAccept,
      );

  /// Главное действие нижней панели и необязательное круглое вторичное —
  /// строго по [orderActions] (шаг 26). Менеджер: «Новая» → назначить;
  /// «На проверке» → принять (вернуть — круглая кнопка). Исполнитель
  /// назначенного подрядчика: «Назначена» / «Возвращена» → начать;
  /// «В работе» → фото «после» (пока его нет), затем сдать.
  (Widget?, Widget?) _primary() {
    final d = _d;
    if (d == null) return (null, null);
    final l = context.l10n;
    final status = _pending.status;
    final can = _can;
    if (can.assign && status == 'new') {
      return (
        AppButton.primary(
            onPressed: _assign, icon: AppIcons.userAdd, label: l.actionAssign),
        null
      );
    }
    if (can.accept) {
      return (
        _acceptButton(),
        AppIconButton(
            icon: AppIcons.undo,
            label: l.actionReturn,
            filled: true,
            size: 52,
            color: AppColors.danger,
            onPressed: _returnForRework)
      );
    }
    if (can.start) return (_startButton(status), null);
    if (can.submit) {
      if (_needPhoto) return (_photoButton(), null);
      return (
        _submitButton(),
        AppIconButton(
            icon: AppIcons.camera,
            label: l.photoTakeMore,
            filled: true,
            size: 52,
            onPressed: _uploading ? null : () => _addPhoto('after'))
      );
    }
    return (null, null);
  }

  bool get _canCancel => _d != null && _can.cancel;

  /// Удаление (меню «⋯», только менеджер): подтверждение → фото из Storage →
  /// заявка → назад к списку с сообщением. Ошибка — заявка остаётся.
  Future<void> _delete() async {
    if (!await confirmDeleteOrder(context) || !mounted) return;
    final l = context.l10n;
    try {
      final left = await widget.repo.deleteOrder(widget.order.id);
      if (left > 0) debugPrint('deleteOrder: $left file(s) left in Storage');
      if (!mounted) return;
      showAppMessage(context, l.toastDeleted, type: AppMessageType.success);
      Navigator.pop(context, true);
    } on OrderDeleteDenied {
      _ok(l.deleteOrderDenied, type: AppMessageType.error);
    } catch (e) {
      debugPrint('deleteOrder: $e');
      _ok(l.deleteOrderFailed, type: AppMessageType.error);
    }
  }

  /// Остальные действия и пояснения — в блоке «Действия» (без повторов с
  /// нижней панелью). Те же правила проверяет база (0023).
  List<Widget> _actions(String status) {
    final l = context.l10n;
    final can = _can;
    Widget hint(String text) => Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.xs),
          child: Text(text, style: AppText.footnote),
        );
    return [
      if (can.assignFirstHint) hint(l.orderAssignFirst),
      if (can.watchProgress) _progressLine(),
      if (can.otherManagerMustAccept) hint(l.orderOtherManagerAccepts),
      if (_needPhoto && can.submit) hint(l.photoNeededHint),
      if (can.cancel)
        AppButton.destructive(
          onPressed: () => _setStatus('cancelled', l.toastCancelled),
          icon: AppIcons.close,
          label: l.actionCancel,
        ),
    ];
  }

  /// Менеджер, заявка в работе: «Выполняет КлиматСервис · начато 14.10
  /// 10:15 · фото «после»: нет» — вместо кнопок исполнителя.
  Widget _progressLine() {
    final l = context.l10n;
    final d = _d!;
    final started = DateTime.tryParse('${d['started_at'] ?? ''}');
    final after = _photos.where((p) => p.stage != 'before').length;
    return AppGroup(children: [
      AppRow(
        leading: const LeadingIcon(AppIcons.contractor),
        title: l.orderProgressBy(_contractorNameIn(
            l, widget.contractors, d['assigned_contractor_id'] as String?)),
        subtitle: [
          if (started != null) l.orderProgressStarted(l.dateTime(started)),
          l.orderProgressAfter(after == 0 ? l.orderProgressNone : '$after'),
        ].join(' · '),
        subtitleMaxLines: 2,
      ),
    ]);
  }
}

Future<bool?> showOrderForm({
  required BuildContext context,
  required RequestsRepo repo,
  required List<Obj> objects,
  required String companyId,
  Map<String, dynamic>? existing,

  /// Объект новой заявки заранее (кнопка «Создать заявку здесь» на карте).
  String? initialObjectId,

  /// Помещение и оборудование заранее («Создать заявку здесь» на плане).
  String? initialLocationId,
  String? initialAssetId,
  String? initialAssetName,

  /// Вид работ заранее (заявка на оборудование — система оборудования, шаг 16).
  String? initialLayerId,

  /// Узнавание по фото (шаг 22): заголовок и описание заранее, снимок
  /// прикладывается к новой заявке как фото «до», канал — camera.
  String? initialTitle,
  String? initialDescription,
  CapturedPhoto? photo,

  /// «Узнать оборудование по фото» вверху новой заявки: окно закрывается
  /// и вызывается [onPhoto].
  VoidCallback? onPhoto,

  /// Откуда открыли форму — подпись «из карточки объекта» / «с плана».
  PlaceOrigin? origin,
}) async {
  // Виды работ = слои компании из базы; ничего не зашито в приложение.
  List<Layer> layers = const [];
  var layersFailed = false;
  try {
    layers = await DirectoryRepo().layers();
  } catch (_) {
    layersFailed = true;
  }
  if (!context.mounted) return null;

  final isEdit = existing != null;
  final titleC = TextEditingController(
      text: isEdit ? (existing['title'] ?? '') as String : initialTitle ?? '');
  final descC = TextEditingController(
      text: isEdit
          ? (existing['description'] ?? '') as String? ?? ''
          : initialDescription ?? '');
  Layer? layer = isEdit
      ? Layer.find(layers,
          id: existing['layer_id'] as String?,
          name: existing['work_type'] as String?)
      : Layer.find(layers, id: initialLayerId);
  String priority =
      isEdit ? (existing['priority'] ?? 'normal') as String : 'normal';
  // Место новой заявки (шаг 24): контекст → GPS ≤ 200 м → пусто.
  // Объект и помещение прошлой заявки не подставляются никогда.
  final start = isEdit
      ? InitialPlace.empty
      : initialOrderPlace(
          objects: objects,
          contextObjectId: initialObjectId,
          contextLocationId: initialLocationId,
          origin: origin);
  String? objectId = isEdit ? existing['object_id'] as String? : start.objectId;
  var placeSource = start.source;
  int? nearbyM;
  bool recurring = isEdit ? existing['recurrence'] != null : false;
  String? locationId =
      isEdit ? existing['location_id'] as String? : start.locationId;
  // Пока окно открыто, GPS и «Недавние» дописываются по мере ответа.
  var sheetOpen = true;
  StateSetter? sheetSet;
  var touched = false;
  List<Obj> recent = const [];
  void refresh() {
    if (sheetOpen) sheetSet?.call(() {});
  }

  if (!isEdit && objectId == null) {
    quickPosition().then((pos) {
      if (pos == null || touched || objectId != null) return;
      final near = nearestObject(objects, pos.lat, pos.lng);
      if (near == null) return;
      objectId = near.object.id;
      locationId = null;
      placeSource = PlaceSource.gps;
      nearbyM = near.distanceM;
      refresh();
    });
    repo.recentObjectIds().then((ids) {
      recent = recentObjects(ids, objects);
      refresh();
    }, onError: (_) {});
  }
  final initialLocation = locationId;
  // Оборудование — только если не сменили объект и помещение.
  final assetId = isEdit ? null : initialAssetId;

  const priorities = ['low', 'normal', 'high', 'critical'];
  final l = context.l10n;
  // Документы новой заявки (шаг 24): загружаются после создания заявки.
  var docs = <PickedDocument>[];
  final locale = context.localeCode;
  final formTitle = isEdit ? l.formEditTitle : l.formNewTitle;

  Future<void> save(BuildContext ctx) async {
    if (titleC.text.trim().isEmpty) {
      showAppMessage(ctx, l.formWhatRequired);
      return;
    }
    try {
      if (isEdit) {
        await repo.update(existing['id'] as String,
            title: titleC.text.trim(),
            description: descC.text.trim().isEmpty ? null : descC.text.trim(),
            layer: layer,
            priority: priority,
            objectId: objectId,
            recurring: recurring,
            // Задача ППР остаётся задачей ППР (recurrence.kind = 'ppr').
            keepRecurrence: isPprOrder(existing) && recurring
                ? existing['recurrence']
                : null,
            setLocation: locationId != initialLocation,
            locationId: locationId);
      } else {
        // id из приложения — чтобы сразу приложить снимок и документы.
        final id = photo == null && docs.isEmpty ? null : newUuid();
        await repo.create(
            id: id,
            inputChannel: photo == null ? 'button' : 'camera',
            companyId: companyId,
            title: titleC.text.trim(),
            description: descC.text.trim().isEmpty ? null : descC.text.trim(),
            layer: layer,
            priority: priority,
            objectId: objectId,
            recurring: recurring,
            locationId: locationId,
            assetId: locationId == initialLocation ? assetId : null);
        if (id != null && docs.isNotEmpty) {
          var failed = false;
          for (final f in docs) {
            try {
              await DocumentRepository()
                  .upload(companyId: companyId, workOrderId: id, file: f);
            } catch (e) {
              debugPrint('Order document: ${e.runtimeType}');
              failed = true;
            }
          }
          if (failed && ctx.mounted) {
            showAppMessage(ctx, l.docAttachFailed, type: AppMessageType.error);
          }
        }
        if (id != null && photo != null) {
          try {
            await PhotoRepository().upload(
                companyId: companyId,
                workOrderId: id,
                stage: 'before',
                photo: photo);
          } catch (e) {
            debugPrint('Order photo: ${e.runtimeType}');
            if (ctx.mounted) {
              showAppMessage(ctx, l.photoAttachFailed,
                  type: AppMessageType.error);
            }
          }
        }
      }
      if (ctx.mounted) Navigator.pop(ctx, true);
    } catch (_) {
      if (!ctx.mounted) return;
      showAppMessage(ctx, l.formSaveFailed, type: AppMessageType.error);
    }
  }

  final result = await showAppSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        // Поля прокручиваются, кнопка «Создать» / «Сохранить» закреплена
        // внизу окна и видна при любой высоте и с открытой клавиатурой.
        builder: (ctx, setSt) {
          sheetSet = setSt;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(title: formTitle, cancelLabel: l.commonCancel),
            Flexible(
                child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.l),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isEdit && onPhoto != null && photo == null)
                      AppGroup(children: [
                        AppRow(
                          leading: const LeadingIcon(AppIcons.camera),
                          title: l.photoEntryHint,
                          onTap: () {
                            Navigator.pop(ctx);
                            onPhoto();
                          },
                        ),
                      ]),
                    if (photo != null)
                      AppGroup(children: [
                        AppRow(
                          leading: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.segmentThumb),
                            child: Image.memory(photo.bytes,
                                width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          title: l.photoWillAttach,
                          chevron: false,
                        ),
                      ]),
                    if (!isEdit && SchemaCompat.has('0019') != false)
                      AppGroup(children: [
                        AppRow(
                          leading: const LeadingIcon(AppIcons.attach),
                          title: docs.isEmpty
                              ? l.docAttach
                              : l.docWillAttach(docs.length),
                          subtitle: docs.isEmpty
                              ? l.docAttachHint
                              : docs.map((d) => d.name).join(', '),
                          subtitleMaxLines: 2,
                          chevron: false,
                          trailing: docs.isEmpty
                              ? null
                              : AppIconButton(
                                  icon: AppIcons.close,
                                  label: l.actionDelete,
                                  onPressed: () => setSt(() => docs = [])),
                          onTap: () async {
                            final picked = await pickDocuments(ctx);
                            if (picked.isNotEmpty) {
                              setSt(() => docs = [...docs, ...picked]);
                            }
                          },
                        ),
                      ]),
                    AppGroup(header: l.formWhat, children: [
                      _inp(titleC, l.formWhatHint),
                    ]),
                    AppGroup(header: l.fieldDescription, children: [
                      _inp(descC, l.formDetailsHint, lines: 3),
                    ]),
                    AppGroup(header: l.fieldObject, children: [
                      _Dropdown(
                          value: objectId,
                          hint: objects.isEmpty
                              ? l.formNoObjects(l.tabLocations)
                              : l.formChooseObject,
                          // По городам: «Москва · Офис 3» (одинаковые названия
                          // бывают в разных городах).
                          items: [
                            for (final g in groupObjectsByCity(objects))
                              for (final o in g.items)
                                DropdownMenuItem(
                                    value: o.id,
                                    child: Text(objectDisplayName(o),
                                        style: AppText.body))
                          ],
                          onChanged: (v) => setSt(() {
                                if (v != objectId) locationId = null;
                                objectId = v;
                                touched = true;
                                placeSource = PlaceSource.none;
                              })),
                    ]),
                    if (!isEdit)
                      _PlaceHint(
                        source:
                            objectId == null ? PlaceSource.none : placeSource,
                        origin: origin,
                        nearbyM: nearbyM,
                        recent: objectId == null ? recent : const [],
                        onOther: () => setSt(() {
                          objectId = null;
                          locationId = null;
                          touched = true;
                          placeSource = PlaceSource.none;
                        }),
                        onPick: (o) => setSt(() {
                          objectId = o.id;
                          locationId = null;
                          touched = true;
                          placeSource = PlaceSource.none;
                        }),
                      ),
                    // Помещение выбранного объекта — с этажом («Лобби · 1 этаж»).
                    if (objectId != null)
                      AppGroup(header: l.formPlace, children: [
                        PlaceField(
                            key: ValueKey(objectId),
                            objectId: objectId!,
                            value: locationId,
                            onChanged: (v) => setSt(() => locationId = v)),
                      ]),
                    if (assetId != null &&
                        initialAssetName != null &&
                        locationId == initialLocation)
                      AppGroup(header: l.formAsset, children: [
                        AppRow(
                            leading: const LeadingIcon(AppIcons.wrench),
                            title: initialAssetName),
                      ]),
                    SectionHeader(l.fieldWorkType),
                    if (layersFailed)
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpace.rowH),
                        child:
                            Text(l.formLayersFailed, style: AppText.footnote),
                      )
                    else
                      Wrap(
                          spacing: AppSpace.s,
                          runSpacing: AppSpace.s,
                          children: [
                            for (final t in Layer.active(layers,
                                keepId: isEdit
                                    ? existing['layer_id'] as String?
                                    : null))
                              AppChip(
                                  label: t.label(locale),
                                  selected: layer?.id == t.id,
                                  onTap: () => setSt(() =>
                                      layer = layer?.id == t.id ? null : t))
                          ]),
                    SectionHeader(l.fieldPriority),
                    SegmentedControl<String>(
                      segments: [
                        for (final p in priorities) Segment(p, l.priority(p))
                      ],
                      selected: priority,
                      onChanged: (p) => setSt(() => priority = p),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    AppGroup(children: [
                      AppRow(
                        title: l.formRecurring,
                        trailing: Switch(
                            value: recurring,
                            onChanged: (v) => setSt(() => recurring = v)),
                      ),
                    ]),
                  ]),
            )),
            BottomActionBar(
                child: AppButton.primary(
                    onPressed: () => save(ctx),
                    label: isEdit ? l.commonSave : l.requestsCreate)),
          ]);
        },
      ),
    ),
  );
  sheetOpen = false;
  return result;
}

/// Под полем «Объект» новой заявки: откуда взялся объект («из карточки
/// объекта», «📍 Рядом с вами · 40 м» с «Другой объект») или, если объект
/// не выбран, кнопки «Недавние» — они ничего не подставляют сами.
class _PlaceHint extends StatelessWidget {
  const _PlaceHint(
      {required this.source,
      required this.origin,
      required this.nearbyM,
      required this.recent,
      required this.onOther,
      required this.onPick});
  final PlaceSource source;
  final PlaceOrigin? origin;
  final int? nearbyM;
  final List<Obj> recent;
  final VoidCallback onOther;
  final ValueChanged<Obj> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const pad = EdgeInsetsDirectional.fromSTEB(
        AppSpace.rowH, 0, AppSpace.rowH, AppSpace.group);
    switch (source) {
      case PlaceSource.context:
        final from = switch (origin) {
          PlaceOrigin.objectCard => l.formFromObjectCard,
          PlaceOrigin.map => l.formFromMap,
          PlaceOrigin.plan => l.formFromPlan,
          PlaceOrigin.equipment => l.formFromEquipment,
          PlaceOrigin.photo => l.formFromPhoto,
          PlaceOrigin.camera => l.formFromCamera,
          PlaceOrigin.order => l.formFromOrder,
          null => null,
        };
        if (from == null) return const SizedBox.shrink();
        return Padding(
            padding: pad, child: Text(from, style: AppText.footnote));
      case PlaceSource.gps:
        return Padding(
          padding: pad,
          child: Row(children: [
            const Icon(AppIcons.place, size: 16, color: AppColors.accentText),
            const SizedBox(width: AppSpace.xs),
            Expanded(
                child: Text(l.formNearby(nearbyM ?? 0),
                    style: AppText.footnote
                        .copyWith(color: AppColors.accentText))),
            AppButton.plain(
                small: true,
                expand: false,
                label: l.formOtherObject,
                onPressed: onOther),
          ]),
        );
      case PlaceSource.none:
        if (recent.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: pad,
          child: Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l.formRecent, style: AppText.footnote),
                for (final o in recent)
                  AppChip(
                      label: objectDisplayName(o),
                      selected: false,
                      onTap: () => onPick(o)),
              ]),
        );
    }
  }
}

/// Поле внутри белой группы: без своей заливки и рамки.
Widget _inp(TextEditingController c, String hint, {int lines = 1}) => TextField(
    controller: c,
    maxLines: lines,
    style: AppText.body,
    decoration: InputDecoration(
      hintText: hint,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ));

/// Выбор помещения объекта в форме заявки: «Без помещения» и помещения
/// с этажом («Переговорная · 3 этаж»), этаж — из планов этажей (0013).
class PlaceField extends StatefulWidget {
  const PlaceField(
      {super.key,
      required this.objectId,
      required this.value,
      required this.onChanged});
  final String objectId;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<PlaceField> {
  /// Помещения объекта по этажу и номеру ([sortPlacesForPicker]).
  List<PlanItem>? _places;
  Map<String, String> _floors = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = FloorRepo();
      final r = await Future.wait<Object>([
        repo.itemsOf(widget.objectId),
        repo.floorsOf(widget.objectId),
      ]);
      final floors = r[1] as List<Floor>;
      final items = sortPlacesForPicker([
        for (final i in r[0] as List<PlanItem>)
          if (i.isPlace) i
      ], floors);
      if (mounted) {
        setState(() {
          _places = items;
          _floors = {for (final f in floors) f.id: f.name};
        });
      }
    } catch (e) {
      debugPrint('PlaceField: ${e.runtimeType}');
      if (mounted) setState(() => _places = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final places = _places;
    if (places == null) {
      return const Padding(
          padding: EdgeInsets.all(AppSpace.m), child: AppLoader());
    }
    PlanItem? selected;
    for (final p in places) {
      if (p.id == widget.value) selected = p;
    }
    // «301 · Переговорная», этаж — серым под ним.
    return AppRow(
      title: selected?.label ?? l.formChoosePlace,
      titleStyle: selected == null
          ? AppText.body.copyWith(color: AppColors.secondary)
          : AppText.body,
      subtitle: selected == null ? null : _floors[selected.floorId],
      onTap: places.isEmpty
          ? null
          : () async {
              final picked = await showAppSheet<String>(
                  context: context,
                  builder: (_) => PlacePickerSheet(
                      places: places, floors: _floors, selected: widget.value));
              if (picked == null) return;
              widget.onChanged(picked.isEmpty ? null : picked);
            },
    );
  }
}

/// Окно выбора помещения: поиск по номеру и названию, «Без помещения»
/// сверху. Возвращает id; '' — без помещения; null — закрыли.
class PlacePickerSheet extends StatefulWidget {
  const PlacePickerSheet(
      {super.key,
      required this.places,
      required this.floors,
      required this.selected,
      this.noneLabel});
  final List<PlanItem> places;
  final Map<String, String> floors;
  final String? selected;

  /// Подпись строки «без помещения» (по умолчанию «Выберите помещение»).
  final String? noneLabel;

  @override
  State<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<PlacePickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = [
      for (final p in widget.places)
        if (placeMatchesQuery(p, _q)) p
    ];
    return ListPickerSheet(
      title: l.formPlace,
      search: widget.places.length < 6
          ? null
          : AppSearchField(
              hint: l.placeSearchHint,
              onChanged: (v) => setState(() => _q = v)),
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          if (_q.trim().isEmpty)
            AppCheckRow(
                title: widget.noneLabel ?? l.formChoosePlace,
                selected: widget.selected == null,
                onTap: () => Navigator.pop(context, '')),
          for (final p in list)
            AppCheckRow(
              title: p.label,
              subtitle: widget.floors[p.floorId],
              selected: p.id == widget.selected,
              onTap: () => Navigator.pop(context, p.id),
            ),
        ]),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(l.placeNotFound,
                textAlign: TextAlign.center, style: AppText.footnote),
          ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(
      {required this.value,
      required this.hint,
      required this.items,
      required this.onChanged});
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.rowH, vertical: AppSpace.xxs),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.field),
                icon: const Icon(AppIcons.chevronDown,
                    size: AppSizes.iconS, color: AppColors.secondary),
                hint: Text(hint,
                    style: AppText.body.copyWith(color: AppColors.secondary)),
                items: items,
                onChanged: items.isEmpty ? null : onChanged)));
  }
}
