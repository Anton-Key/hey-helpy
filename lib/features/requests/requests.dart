import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/directional.dart';
import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../core/status_style.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../photos/photo_capture.dart';
import '../photos/photo_repository.dart';
import '../photos/photo_section.dart';
import '../visits/visit_repository.dart';
import '../visits/visit_section.dart';
import '../voice/voice_record_screen.dart';
import 'contractor_picker.dart';
import '../voice/wake_word_service.dart';

class WorkOrder {
  final String id;
  final String title;
  final String? workType;
  final String? layerId;
  final String priority;
  final String status;
  final String? objectId;
  final bool recurring;
  WorkOrder(
      {required this.id,
      required this.title,
      this.workType,
      this.layerId,
      required this.priority,
      required this.status,
      this.objectId,
      required this.recurring});
  factory WorkOrder.fromMap(Map<String, dynamic> m) {
    return WorkOrder(
      id: m['id'] as String,
      title: (m['title'] ?? '') as String,
      workType: m['work_type'] as String?,
      layerId: m['layer_id'] as String?,
      priority: (m['priority'] ?? 'normal') as String,
      status: (m['status'] ?? 'new') as String,
      objectId: m['object_id'] as String?,
      recurring: m['recurrence'] != null,
    );
  }
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

  Future<List<WorkOrder>> list() async {
    final rows = await _c
        .from('work_orders')
        .select(
            'id,title,work_type,layer_id,priority,status,recurrence,object_id')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => WorkOrder.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> detail(String id) async {
    return await _c.from('work_orders').select().eq('id', id).maybeSingle();
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

  /// Вернуть работу на доработку с комментарием (только автор или менеджер).
  Future<void> returnForRework(String id, String reason) async {
    await _c
        .from('work_orders')
        .update({'status': 'returned', 'return_reason': reason}).eq('id', id);
  }
}

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _onBrand = Color(0xFF06342A);

BoxDecoration _card() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _line));

String _objNameIn(AppLocalizations l, List<Obj> objects, String? id) {
  if (id == null) return l.objectNone;
  for (final o in objects) {
    if (o.id == id) return o.name;
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

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});
  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final _repo = RequestsRepo();
  final _dir = DirectoryRepo();

  /// Сейчас — кнопка «Нажми и говори»; позже сюда же подключится «Эй, Хелпи».
  final _wake = PushToTalkWakeWord();
  StreamSubscription<void>? _wakeSub;
  bool _voiceOpen = false;
  List<WorkOrder> _items = [];
  List<Obj> _objects = const [];
  List<Contractor> _contractors = const [];
  List<Layer> _layers = const [];
  String? _companyId;
  String? _role;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _wakeSub = _wake.detections.listen((_) => _openVoice());
    _wake.start();
  }

  @override
  void dispose() {
    _wakeSub?.cancel();
    _wake.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _companyId ??= await _dir.myCompanyId();
      _role ??= await _repo.myRole();
      final objs = await _dir.objects();
      final cons = await _dir.contractors();
      final data = await _repo.list();
      List<Layer> layers = _layers;
      try {
        layers = await _dir.layers();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _objects = objs;
        _contractors = cons;
        _layers = layers;
        _items = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('RequestsTab: $e');
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _statusText() {
    final l = context.l10n;
    if (_loading) return l.requestsLoading;
    if (_error != null) return l.requestsLoadErrorShort;
    return l.requestsCount(_items.length);
  }

  Future<void> _openDetail(WorkOrder w) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkOrderDetailScreen(
            order: w,
            objects: _objects,
            contractors: _contractors,
            layers: _layers,
            uid: _repo.uid,
            role: _role,
            repo: _repo,
            companyId: _companyId,
          ),
        ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const brand = HeyHelpyTheme.brand;
    return Stack(children: [
      Positioned.fill(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 6),
            child: Text(_statusText(),
                style: const TextStyle(
                    color: _muted, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Expanded(child: _body()),
        ]),
      ),
      PositionedDirectional(
        end: 4,
        bottom: 8,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                  heroTag: 'refreshReq',
                  backgroundColor: Colors.white,
                  foregroundColor: HeyHelpyTheme.link,
                  tooltip: context.l10n.commonRefresh,
                  onPressed: _load,
                  child: const Icon(Icons.refresh)),
              const SizedBox(height: 10),
              Tooltip(
                  message: context.l10n.requestsVoice,
                  child: FloatingActionButton.large(
                      heroTag: 'voiceReq',
                      backgroundColor: brand,
                      foregroundColor: _onBrand,
                      onPressed: _wake.trigger,
                      // Подпись — имя кнопки для экранного чтеца
                      // (и для /screens: Tooltip его не задаёт).
                      child: Icon(Icons.mic,
                          size: 44,
                          semanticLabel: context.l10n.requestsVoice))),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                  heroTag: 'addReq',
                  backgroundColor: brand,
                  foregroundColor: _onBrand,
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.requestsCreate,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
      ),
    ]);
  }

  Widget _body() {
    final l = context.l10n;
    final locale = context.localeCode;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.requestsLoadFailed,
            style: const TextStyle(color: Color(0xFFC24444))),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(l.requestsEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted)),
        ),
      );
    }
    // Снизу — место под плавающие кнопки (обновить 40 + микрофон 96 +
    // «Создать заявку» 48 + промежутки ≈ 212): последняя карточка
    // прокручивается выше них.
    return ListView.builder(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 240),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final w = _items[i];
        final high = w.priority == 'high' || w.priority == 'critical';
        final workType = _workTypeLabel(_layers, locale,
            layerId: w.layerId, workType: w.workType);
        return TapCard(
          onTap: () => _openDetail(w),
          chevron: false,
          radius: 18,
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                  width: 6,
                  decoration: BoxDecoration(
                      color: high
                          ? StatusStyle.urgentAccent
                          : const Color(0xFFD7DBE0),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        w.title +
                            (w.recurring ? '  · ${l.requestRecurringTag}' : ''),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                        '${_objNameIn(l, _objects, w.objectId)}'
                        '${workType != null ? ' · $workType' : ''}',
                        style: const TextStyle(color: _muted, fontSize: 13)),
                  ])),
              const SizedBox(width: 8),
              Center(child: StatusPill(w.status)),
              const SizedBox(width: 4),
              const ChevronEnd(color: _muted, size: 20),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _openCreate() async {
    if (_companyId == null) {
      _snack(context.l10n.requestsNoCompany);
      return;
    }
    final ok = await showOrderForm(
        context: context,
        repo: _repo,
        objects: _objects,
        companyId: _companyId!,
        existing: null);
    if (ok == true) {
      await _load();
      if (mounted) _snackOk(context.l10n.requestsCreated);
    }
  }

  Future<void> _openVoice() async {
    if (_voiceOpen || !mounted) return;
    if (_companyId == null) {
      _snack(context.l10n.requestsNoCompany);
      return;
    }
    _voiceOpen = true;
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                VoiceRecordScreen(companyId: _companyId!, objects: _objects)));
    _voiceOpen = false;
    if (ok == true) {
      await _load();
      if (mounted) _snackOk(context.l10n.requestsCreated);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  void _snackOk(String m) {
    if (!mounted) return;
    const brand = HeyHelpyTheme.brand;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_rounded, color: brand),
      const SizedBox(width: 10),
      Text(m),
    ])));
  }
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
        _ok(l.statusError(e));
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
      _ok(message);
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
      _ok(e.problem == CaptureProblem.cameraDenied
          ? l.photoCameraDenied
          : l.photoCameraFailed);
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
      _ok(l.photoUploadFailed);
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
      _ok(l.assignNoContractors(l.tabContractors));
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
      _ok(l.errorGeneric);
    }
  }

  Future<void> _setStatus(String status, String okText) async {
    final l = context.l10n;
    try {
      await widget.repo.setStatus(widget.order.id, status);
      await _load();
      _ok(okText);
    } catch (e) {
      _ok(l.statusError(e));
    }
  }

  Future<void> _returnForRework() async {
    final l = context.l10n;
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.actionReturn),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(hintText: l.returnHint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(l.returnConfirm)),
        ],
      ),
    );
    if (reason == null) return;
    if (reason.isEmpty) {
      _ok(l.returnReasonRequired);
      return;
    }
    try {
      await widget.repo.returnForRework(widget.order.id, reason);
      await _load();
      _ok(l.toastReturned);
    } catch (e) {
      _ok(l.statusError(e));
    }
  }

  void _ok(String m) {
    if (!mounted) return;
    const brand = HeyHelpyTheme.brand;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_rounded, color: brand),
      const SizedBox(width: 10),
      Flexible(child: Text(m)),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.detailTitle),
        actions: [
          if (_canEdit)
            IconButton(
                tooltip: l.detailEdit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.detailLoadFailed,
                      style: const TextStyle(color: Color(0xFFC24444))))
              : _content(),
      bottomNavigationBar: _loading || _error != null ? null : _bottomBar(),
    );
  }

  /// Главные действия по роли и статусу — внизу экрана, не уезжают при
  /// прокрутке. У заявителя панели нет (его кнопки — в блоке «Действия»).
  Widget? _bottomBar() {
    final buttons = _primary();
    if (buttons.isEmpty) return null;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white, border: Border(top: BorderSide(color: _line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
          child: Row(children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: buttons[i]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _content() {
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
    final contractorId = d['assigned_contractor_id'] as String?;
    final created = DateTime.tryParse('${d['created_at']}');
    final createdText = created == null ? '—' : l.dateTime(created);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
      children: [
        Row(children: [
          Expanded(
              child: Text(
                  title + (recurring ? '  · ${l.requestRecurringTag}' : ''),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800))),
          StatusPill(status, large: true),
        ]),
        const SizedBox(height: 20),
        _row(l.fieldObject, _objNameIn(l, widget.objects, objId)),
        _row(l.fieldContractor,
            _contractorNameIn(l, widget.contractors, contractorId),
            action: _canAssign(status)
                ? TextButton.icon(
                    onPressed: _assign,
                    icon: Icon(
                        contractorId == null
                            ? Icons.person_add_alt_1_outlined
                            : Icons.swap_horiz,
                        size: 18),
                    label: Text(contractorId == null
                        ? l.assignInline
                        : l.assignChangeInline))
                : null),
        if (_executorName != null && _executorName!.isNotEmpty)
          _row(l.fieldExecutor, _executorName!),
        _row(l.fieldWorkType, workType ?? '—'),
        _row(l.fieldPriority, l.priority(priority)),
        _row(l.fieldKind, recurring ? l.kindRecurring : l.kindOneOff),
        _row(
            l.fieldPhotoProof,
            (d['requires_photo'] == true)
                ? l.photoRequired
                : l.photoNotRequired),
        _row(l.fieldCreated,
            _isAuthor ? l.createdByYou(createdText) : createdText),
        const SizedBox(height: 16),
        Text(l.fieldDescription,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _card(),
          child: Text((desc == null || desc.isEmpty) ? l.noDescription : desc,
              style: TextStyle(
                  color: (desc == null || desc.isEmpty) ? _muted : _ink,
                  fontSize: 14)),
        ),
        if ((d['return_reason'] as String?)?.isNotEmpty == true &&
            status == 'returned') ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFFBE8E8),
                borderRadius: BorderRadius.circular(14)),
            child: Text(l.returnedWithReason('${d['return_reason']}'),
                style: const TextStyle(
                    color: Color(0xFFC24444), fontWeight: FontWeight.w600)),
          ),
        ],
        if (_photos.isNotEmpty ||
            _photosFailed ||
            _canAddBefore(status) ||
            _canAddAfter(status)) ...[
          const SizedBox(height: 20),
          WorkPhotosSection(
            photos: _photos,
            loadFailed: _photosFailed,
            busy: _uploading,
            onAddBefore:
                _canAddBefore(status) ? () => _addPhoto('before') : null,
            onAddAfter: _canAddAfter(status) ? () => _addPhoto('after') : null,
          ),
        ],
        if (_isManager && (_visits.isNotEmpty || _visitsFailed)) ...[
          const SizedBox(height: 20),
          VisitsSection(visits: _visits, loadFailed: _visitsFailed),
        ],
        if (_actions(status).isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l.actionsTitle,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: _actions(status)),
        ],
      ],
    );
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

  ButtonStyle get _filled => FilledButton.styleFrom(
      backgroundColor: HeyHelpyTheme.brand,
      foregroundColor: _onBrand,
      minimumSize: const Size.fromHeight(48));

  Widget _startButton(String status) => FilledButton.icon(
        onPressed: _starting ? null : _startWork,
        style: _filled,
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: Text(status == 'returned'
            ? context.l10n.actionRestart
            : context.l10n.actionStart),
      );

  Widget _photoButton() => FilledButton.icon(
        onPressed: _uploading ? null : () => _addPhoto('after'),
        style: _filled,
        icon: const Icon(Icons.photo_camera_outlined, size: 18),
        label: Text(context.l10n.photoTakeResult),
      );

  Widget _submitButton() => FilledButton.icon(
        onPressed: _needPhoto
            ? null
            : () => _setStatus('on_review', context.l10n.toastSubmitted),
        style: _filled,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: Text(context.l10n.actionSubmit),
      );

  Widget _acceptButton() => FilledButton.icon(
        onPressed: () => _setStatus('done', context.l10n.toastAccepted),
        style: _filled,
        icon: const Icon(Icons.verified_outlined, size: 18),
        label: Text(context.l10n.actionAccept),
      );

  Widget _returnButton() => OutlinedButton.icon(
        onPressed: _returnForRework,
        style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC24444),
            minimumSize: const Size.fromHeight(48)),
        icon: const Icon(Icons.undo_rounded, size: 18),
        label: Text(context.l10n.actionReturn),
      );

  /// 1–2 главных действия для нижней панели.
  /// Менеджер: «Новая» → назначить; «На проверке» → принять / вернуть.
  /// Исполнитель: «Назначена» / «Возвращена» → начать; «В работе» → фото и сдать.
  List<Widget> _primary() {
    final d = _d;
    if (d == null) return const [];
    final l = context.l10n;
    final status = (d['status'] ?? 'new') as String;
    if (_isManager) {
      if (status == 'new') {
        return [
          FilledButton.icon(
            onPressed: _assign,
            style: _filled,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text(l.actionAssign),
          ),
        ];
      }
      if (status == 'on_review') return [_returnButton(), _acceptButton()];
      return const [];
    }
    if (_isExecutor) {
      if (_canStart(status)) return [_startButton(status)];
      if (status == 'in_progress') {
        return [if (_needPhoto) _photoButton(), _submitButton()];
      }
    }
    return const [];
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
        if (_needPhoto) _photoButton(),
        _submitButton(),
      ],
      if (_needPhoto && status == 'in_progress' && (_isManager || _isExecutor))
        Text(l.photoNeededHint,
            style: const TextStyle(color: _muted, fontSize: 13)),
      // Заявитель принимает свою работу здесь: нижней панели у него нет.
      if (!inBar && canAccept && status == 'on_review') ...[
        _acceptButton(),
        _returnButton(),
      ],
      if (canAccept && status != 'done' && status != 'cancelled')
        OutlinedButton.icon(
          onPressed: () => _setStatus('cancelled', l.toastCancelled),
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC24444)),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(l.actionCancel),
        ),
    ];
  }

  /// Строка сведений «подпись — значение»; [action] — кнопка в конце строки.
  Widget _row(String k, String v, {Widget? action}) => Padding(
        padding: EdgeInsets.symmetric(vertical: action == null ? 8 : 2),
        child: Row(
            crossAxisAlignment: action == null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              SizedBox(
                  width: 150,
                  child: Text(k,
                      style: const TextStyle(color: _muted, fontSize: 14))),
              Expanded(
                  child: Text(v,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600))),
              if (action != null) action,
            ]),
      );
}

Future<bool?> showOrderForm({
  required BuildContext context,
  required RequestsRepo repo,
  required List<Obj> objects,
  required String companyId,
  Map<String, dynamic>? existing,
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
  String? objectId = isEdit ? existing['object_id'] as String? : null;
  bool recurring = isEdit ? existing['recurrence'] != null : false;

  const priorities = ['low', 'normal', 'high', 'critical'];
  const brand = HeyHelpyTheme.brand;
  final l = context.l10n;
  final locale = context.localeCode;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsetsDirectional.only(bottom: 14),
                          decoration: BoxDecoration(
                              color: _line,
                              borderRadius: BorderRadius.circular(4)))),
                  Text(isEdit ? l.formEditTitle : l.formNewTitle,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  _lbl(l.formWhat),
                  _inp(titleC, l.formWhatHint),
                  _lbl(l.fieldDescription),
                  _inp(descC, l.formDetailsHint, lines: 3),
                  _lbl(l.fieldObject),
                  _Dropdown(
                      value: objectId,
                      hint: objects.isEmpty
                          ? l.formNoObjects(l.tabLocations)
                          : l.formChooseObject,
                      items: [
                        for (final o in objects)
                          DropdownMenuItem(value: o.id, child: Text(o.name))
                      ],
                      onChanged: (v) => setSt(() => objectId = v)),
                  _lbl(l.fieldWorkType),
                  if (layersFailed)
                    Text(l.formLayersFailed,
                        style: const TextStyle(color: _muted))
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in layers)
                        _chip(
                            t.label(locale),
                            layer?.id == t.id,
                            brand,
                            () => setSt(
                                () => layer = layer?.id == t.id ? null : t))
                    ]),
                  _lbl(l.fieldPriority),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in priorities)
                      _chip(l.priority(p), priority == p, brand,
                          () => setSt(() => priority = p))
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Text(l.formRecurring,
                            style: const TextStyle(fontSize: 15))),
                    Switch(
                        value: recurring,
                        activeTrackColor: brand,
                        onChanged: (v) => setSt(() => recurring = v))
                  ]),
                  const SizedBox(height: 10),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: brand, foregroundColor: _onBrand),
                      onPressed: () async {
                        if (titleC.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l.formWhatRequired)));
                          return;
                        }
                        try {
                          if (isEdit) {
                            await repo.update(existing['id'] as String,
                                title: titleC.text.trim(),
                                description: descC.text.trim().isEmpty
                                    ? null
                                    : descC.text.trim(),
                                layer: layer,
                                priority: priority,
                                objectId: objectId,
                                recurring: recurring);
                          } else {
                            await repo.create(
                                companyId: companyId,
                                title: titleC.text.trim(),
                                description: descC.text.trim().isEmpty
                                    ? null
                                    : descC.text.trim(),
                                layer: layer,
                                priority: priority,
                                objectId: objectId,
                                recurring: recurring);
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (_) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l.formSaveFailed)));
                        }
                      },
                      child: Text(isEdit ? l.commonSave : l.requestsCreate,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
          ),
        ),
      ),
    ),
  );
}

Widget _lbl(String t) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 16, bottom: 8),
    child: Text(t,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: _ink)));

Widget _inp(TextEditingController c, String hint, {int lines = 1}) => TextField(
    controller: c,
    maxLines: lines,
    decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 14)));

Widget _chip(String label, bool on, Color brand, VoidCallback onTap) =>
    ChoiceTag(label: label, selected: on, onTap: onTap);

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
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line)),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                hint: Text(hint,
                    style: const TextStyle(color: _muted, fontSize: 15)),
                items: items,
                onChanged: items.isEmpty ? null : onChanged)));
  }
}
