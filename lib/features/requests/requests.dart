import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../core/paging.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../photos/photo_capture.dart';
import '../photos/photo_repository.dart';
import '../photos/photo_section.dart';
import '../visits/visit_repository.dart';
import '../visits/visit_section.dart';
import 'contractor_picker.dart';
import 'order_filter.dart';
import 'order_menu.dart';
import 'work_order.dart';
import '../../core/app_message.dart';
import '../directory/city.dart';

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
    final r =
        await _c.from('profiles').select('role').eq('id', id).maybeSingle();
    return r?['role'] as String?;
  }

  /// Заявки подрядчика, объекта или помещения (сначала новые). Сколько видно —
  /// решает RLS: менеджер — все, заявитель — свои, исполнитель — своего подрядчика.
  Future<List<Map<String, dynamic>>> listBy(
      {String? contractorId,
      String? objectId,
      String? locationId,
      int limit = 200}) async {
    var q = _c.from('work_orders').select(
        'id,title,work_type,layer_id,priority,status,recurrence,object_id,location_id,'
        'assigned_contractor_id,created_at,accepted_at,return_count,locations(name)');
    if (contractorId != null) q = q.eq('assigned_contractor_id', contractorId);
    if (objectId != null) q = q.eq('object_id', objectId);
    if (locationId != null) q = q.eq('location_id', locationId);
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
    final rows = await fetchAll(() => applyServerConds(
            _c.from('work_orders').select(WorkOrder.listColumns), conds)
        .order('created_at', ascending: false)
        .order('id'));
    return rows.map(WorkOrder.fromMap).toList();
  }

  /// Сколько заявок подходит под условия — только число, без строк
  /// («Показать N заявок» в окне «Фильтры»).
  Future<int> countFiltered(List<ServerCond> conds) =>
      applyServerConds(_c.from('work_orders').count(CountOption.exact), conds);

  /// Сколько всего заявок видно пользователю (без фильтров) — «из M».
  Future<int> countAll() => _c.from('work_orders').count(CountOption.exact);

  /// Мои записи исполнителя (executors.id) — для «Назначено мне».
  Future<List<String>> myExecutorIds() async {
    final id = uid;
    if (id == null) return const [];
    final rows = await _c.from('executors').select('id').eq('profile_id', id);
    return [for (final r in rows) r['id'] as String];
  }

  Future<Map<String, dynamic>?> detail(String id) async {
    return await _c
        .from('work_orders')
        .select('*,locations(name)')
        .eq('id', id)
        .maybeSingle();
  }

  Future<void> create(
      {required String companyId,
      required String title,
      String? description,
      Layer? layer,
      required String priority,
      String? objectId,
      required bool recurring,
      String? locationId,
      String inputChannel = 'button'}) async {
    // Слой передаём явно: тогда назначение подрядчика не зависит от языка интерфейса.
    await _c.from('work_orders').insert({
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
      'recurrence': recurring ? {'kind': 'regular'} : null,
      'created_by': uid,
    });
  }

  Future<void> update(String id,
      {required String title,
      String? description,
      Layer? layer,
      required String priority,
      String? objectId,
      required bool recurring}) async {
    await _c.from('work_orders').update({
      'title': title,
      'description': description,
      'work_type': layer?.name,
      'layer_id': layer?.id,
      'priority': priority,
      'object_id': objectId,
      'recurrence': recurring ? {'kind': 'regular'} : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Имя конкретного исполнителя заявки (executors → profiles).
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
  }

  Future<void> setStatus(String id, String status) async {
    await _c.from('work_orders').update({'status': status}).eq('id', id);
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
        .select('storage_path')
        .eq('work_order_id', id);
    final paths = [
      for (final r in rows)
        if (r['storage_path'] is String) r['storage_path'] as String,
    ];
    var removed = 0;
    if (paths.isNotEmpty) {
      removed =
          (await _c.storage.from(PhotoRepository.bucket).remove(paths)).length;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

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
        _loadPhotos(),
        if (_isManager) _loadVisits(),
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
      if (mounted) setState(() => _photosFailed = true);
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
  Future<void> _startWork() async {
    final l = context.l10n;
    final d = _d!;
    final recordVisit = _isExecutor && d['object_id'] != null;
    setState(() => _starting = true);
    try {
      // Координаты ищутся, пока меняется статус.
      final positionFuture = recordVisit
          ? ensureLocationPermission()
              .then((ok) => ok ? currentPosition() : null)
          : Future.value(null);
      try {
        await widget.repo.setStatus(widget.order.id, 'in_progress');
      } catch (e) {
        _ok(l.statusError(e), type: AppMessageType.error);
        return;
      }
      var message = l.toastInProgress;
      if (recordVisit) {
        final position = await positionFuture;
        try {
          await _visitRepo.start(
              workOrderId: widget.order.id,
              companyId: widget.companyId ?? (d['company_id'] as String),
              position: position);
          if (position == null) message = l.visitNoLocation;
        } on PostgrestException catch (e) {
          // 23505 — у человека уже есть открытый визит по заявке (uq_visits_open,
          // миграция 0009): кнопку нажали повторно или с устаревшего экрана.
          debugPrint('visit: $e');
          message = e.code == '23505' ? l.visitAlreadyOpen : l.visitNotRecorded;
        } catch (e) {
          debugPrint('visit: $e');
          message = l.visitNotRecorded;
        }
      }
      await _load();
      // Работа начата, но визит без координат или не записан — это не успех.
      _ok(message,
          type: message == l.toastInProgress
              ? AppMessageType.success
              : AppMessageType.info);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  bool get _hasAfterPhoto => _photos.any((p) => p.stage != 'before');

  /// Съёмка и загрузка фото «до» (автор) или «после» (исполнитель).
  Future<void> _addPhoto(String stage) async {
    final l = context.l10n;
    final companyId = widget.companyId ?? (_d!['company_id'] as String);
    final CapturedPhoto? photo;
    try {
      photo = await capturePhoto();
    } on CaptureException catch (e) {
      _ok(
          e.problem == CaptureProblem.cameraDenied
              ? l.photoCameraDenied
              : l.photoCameraFailed,
          type: AppMessageType.error);
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await _photoRepo.upload(
          companyId: companyId,
          workOrderId: widget.order.id,
          stage: stage,
          photo: photo);
      await _loadPhotos();
      _ok(l.photoUploaded);
    } catch (e) {
      debugPrint('upload: $e');
      _ok(l.photoUploadFailed, type: AppMessageType.error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool get _isAuthor => widget.uid != null && _d?['created_by'] == widget.uid;
  bool get _isManager => widget.role == 'admin' || widget.role == 'manager';
  bool get _isExecutor =>
      widget.role == 'executor' || widget.role == 'contractor';
  bool get _canEdit => _d != null && (_isAuthor || widget.role == 'admin');

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
      await _load();
      _ok(okText);
    } catch (e) {
      _ok(l.statusError(e), type: AppMessageType.error);
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
      await _load();
      _ok(l.toastReturned);
    } catch (e) {
      _ok(l.statusError(e), type: AppMessageType.error);
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
    final status = (d['status'] ?? 'new') as String;
    final priority = (d['priority'] ?? 'normal') as String;
    final recurring = d['recurrence'] != null;
    final title = (d['title'] ?? '') as String;
    final desc = (d['description'] ?? '') as String?;
    final workType = _workTypeLabel(widget.layers, context.localeCode,
        layerId: d['layer_id'] as String?, workType: d['work_type'] as String?);
    final objId = d['object_id'] as String?;
    final place = (d['locations'] as Map<String, dynamic>?)?['name'] as String?;
    final contractorId = d['assigned_contractor_id'] as String?;
    final created = DateTime.tryParse('${d['created_at']}');
    final createdText = created == null ? '—' : l.dateTime(created);
    final due = DateTime.tryParse('${d['due_at'] ?? ''}');
    final open = status != 'done' && status != 'cancelled';
    final overdue = open && due != null && due.isBefore(DateTime.now());
    final channel = switch (d['input_channel']) {
      'voice' => l.reqViaVoice,
      'text' => l.reqViaText,
      _ => null,
    };
    final noDesc = desc == null || desc.isEmpty;
    final actions = _actions(status);

    return [
      Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
        StatusPill(status, large: true),
        PriorityPill(priority, large: true),
        if (overdue) StatusPill('overdue', label: l.statusOverdue, large: true),
      ]),
      const SizedBox(height: AppSpace.m),
      Text(title + (recurring ? '  · ${l.requestRecurringTag}' : ''),
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
          trailing: _canAssign(status)
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
        if (due != null)
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
      AppGroup(children: [
        AppRow(
            title: l.fieldKind,
            value: recurring ? l.kindRecurring : l.kindOneOff),
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
      if (_photos.isNotEmpty ||
          _photosFailed ||
          _canAddBefore(status) ||
          _canAddAfter(status))
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpace.group),
          child: WorkPhotosSection(
            photos: _photos,
            loadFailed: _photosFailed,
            busy: _uploading,
            onAddBefore:
                _canAddBefore(status) ? () => _addPhoto('before') : null,
            onAddAfter: _canAddAfter(status) ? () => _addPhoto('after') : null,
          ),
        ),
      if (_isManager && (_visits.isNotEmpty || _visitsFailed))
        VisitsSection(visits: _visits, loadFailed: _visitsFailed),
      if (actions.isNotEmpty) ...[
        SectionHeader(l.actionsTitle),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s),
          actions[i],
        ],
      ],
    ];
  }

  // Те же правила проверяет база (миграция 0006).
  bool _canAddBefore(String status) =>
      (status == 'new' || status == 'assigned') && (_isAuthor || _isManager);
  bool _canAddAfter(String status) =>
      status == 'in_progress' && (_isExecutor || _isManager);

  /// Менеджер назначает или меняет подрядчика, пока работу не начали.
  /// Те же правила проверяет база (trg_wo_guard, trg_wo_status_flow).
  bool _canAssign(String status) =>
      _isManager &&
      (status == 'new' || status == 'assigned' || status == 'returned');

  bool _canStart(String status) =>
      (_isExecutor || _isManager) &&
      (status == 'new' || status == 'assigned' || status == 'returned');

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
        onPressed: _needPhoto
            ? null
            : () => _setStatus('on_review', context.l10n.toastSubmitted),
        icon: AppIcons.check,
        label: context.l10n.actionSubmit,
      );

  Widget _acceptButton() => AppButton.primary(
        onPressed: () => _setStatus('done', context.l10n.toastAccepted),
        icon: AppIcons.verified,
        label: context.l10n.actionAccept,
      );

  Widget _returnButton() => AppButton.destructive(
        onPressed: _returnForRework,
        icon: AppIcons.undo,
        label: context.l10n.actionReturn,
      );

  /// Главное действие нижней панели и необязательное круглое вторичное.
  /// Менеджер: «Новая» → назначить; «На проверке» → принять (вернуть —
  /// круглая кнопка). Исполнитель: «Назначена» / «Возвращена» → начать;
  /// «В работе» → фото «после» (пока его нет), затем сдать.
  (Widget?, Widget?) _primary() {
    final d = _d;
    if (d == null) return (null, null);
    final l = context.l10n;
    final status = (d['status'] ?? 'new') as String;
    if (_isManager) {
      if (status == 'new') {
        return (
          AppButton.primary(
              onPressed: _assign,
              icon: AppIcons.userAdd,
              label: l.actionAssign),
          null
        );
      }
      if (status == 'on_review') {
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
      return (null, null);
    }
    if (_isExecutor) {
      if (_canStart(status)) return (_startButton(status), null);
      if (status == 'in_progress') {
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
    }
    return (null, null);
  }

  /// Отменить можно автору и менеджеру, пока заявка не принята и не отменена.
  bool get _canCancel {
    final status = _d?['status'] as String? ?? widget.order.status;
    return (_isAuthor || _isManager) &&
        status != 'done' &&
        status != 'cancelled';
  }

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

  /// Остальные действия — в блоке «Действия» (без повторов с нижней панелью).
  /// Те же правила проверяет база.
  List<Widget> _actions(String status) {
    final canAccept = _isAuthor || _isManager;
    final l = context.l10n;
    final inBar = _isManager || _isExecutor;
    return [
      // Менеджер может начать и сдать работу сам — эти кнопки у него здесь.
      if (_isManager && _canStart(status)) _startButton(status),
      if (_isManager && status == 'in_progress') ...[
        if (_needPhoto) _photoButton(primary: false),
        _submitButton(),
      ],
      if (_needPhoto && status == 'in_progress' && (_isManager || _isExecutor))
        Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.xs),
          child: Text(l.photoNeededHint, style: AppText.footnote),
        ),
      // Заявитель принимает свою работу здесь: нижней панели у него нет.
      if (!inBar && canAccept && status == 'on_review') ...[
        _acceptButton(),
        _returnButton(),
      ],
      if (canAccept && status != 'done' && status != 'cancelled')
        AppButton.destructive(
          onPressed: () => _setStatus('cancelled', l.toastCancelled),
          icon: AppIcons.close,
          label: l.actionCancel,
        ),
    ];
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
      text: isEdit ? (existing['title'] ?? '') as String : '');
  final descC = TextEditingController(
      text: isEdit ? (existing['description'] ?? '') as String? ?? '' : '');
  Layer? layer = isEdit
      ? Layer.find(layers,
          id: existing['layer_id'] as String?,
          name: existing['work_type'] as String?)
      : null;
  String priority =
      isEdit ? (existing['priority'] ?? 'normal') as String : 'normal';
  String? objectId = isEdit
      ? existing['object_id'] as String?
      : objects.any((o) => o.id == initialObjectId)
          ? initialObjectId
          : null;
  bool recurring = isEdit ? existing['recurrence'] != null : false;

  const priorities = ['low', 'normal', 'high', 'critical'];
  final l = context.l10n;
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
            recurring: recurring);
      } else {
        await repo.create(
            companyId: companyId,
            title: titleC.text.trim(),
            description: descC.text.trim().isEmpty ? null : descC.text.trim(),
            layer: layer,
            priority: priority,
            objectId: objectId,
            recurring: recurring);
      }
      if (ctx.mounted) Navigator.pop(ctx, true);
    } catch (_) {
      if (!ctx.mounted) return;
      showAppMessage(ctx, l.formSaveFailed, type: AppMessageType.error);
    }
  }

  return showAppSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        // Поля прокручиваются, кнопка «Создать» / «Сохранить» закреплена
        // внизу окна и видна при любой высоте и с открытой клавиатурой.
        builder: (ctx, setSt) =>
            Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: formTitle, cancelLabel: l.commonCancel),
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.l),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        onChanged: (v) => setSt(() => objectId = v)),
                  ]),
                  SectionHeader(l.fieldWorkType),
                  if (layersFailed)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpace.rowH),
                      child: Text(l.formLayersFailed, style: AppText.footnote),
                    )
                  else
                    Wrap(
                        spacing: AppSpace.s,
                        runSpacing: AppSpace.s,
                        children: [
                          for (final t in layers)
                            AppChip(
                                label: t.label(locale),
                                selected: layer?.id == t.id,
                                onTap: () => setSt(
                                    () => layer = layer?.id == t.id ? null : t))
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
        ]),
      ),
    ),
  );
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
