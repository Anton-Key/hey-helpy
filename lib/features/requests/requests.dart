import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../directory/directory.dart';
import '../voice/voice_record_screen.dart';
import '../voice/wake_word_service.dart';

class WorkOrder {
  final String id;
  final String title;
  final String? workType;
  final String priority;
  final String status;
  final String? objectId;
  final bool recurring;
  WorkOrder({required this.id, required this.title, this.workType, required this.priority,
      required this.status, this.objectId, required this.recurring});
  factory WorkOrder.fromMap(Map<String, dynamic> m) {
    return WorkOrder(
      id: m['id'] as String,
      title: (m['title'] ?? '') as String,
      workType: m['work_type'] as String?,
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
    final r = await _c.from('profiles').select('role').eq('id', id).maybeSingle();
    return r?['role'] as String?;
  }

  Future<List<WorkOrder>> list() async {
    final rows = await _c
        .from('work_orders')
        .select('id,title,work_type,priority,status,recurrence,object_id')
        .order('created_at', ascending: false);
    return (rows as List).map((e) => WorkOrder.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> detail(String id) async {
    return await _c.from('work_orders').select().eq('id', id).maybeSingle();
  }

  Future<void> create({required String companyId, required String title, String? description,
      String? workType, required String priority, String? objectId, required bool recurring,
      String? locationId, String inputChannel = 'button'}) async {
    await _c.from('work_orders').insert({
      'company_id': companyId, 'title': title, 'description': description, 'work_type': workType,
      'priority': priority, 'status': 'new', 'input_channel': inputChannel, 'object_id': objectId,
      'location_id': locationId,
      'recurrence': recurring ? {'kind': 'regular'} : null, 'created_by': uid,
    });
  }

  Future<void> update(String id, {required String title, String? description,
      String? workType, required String priority, String? objectId, required bool recurring}) async {
    await _c.from('work_orders').update({
      'title': title, 'description': description, 'work_type': workType,
      'priority': priority, 'object_id': objectId,
      'recurrence': recurring ? {'kind': 'regular'} : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> assign(String id, String contractorId) async {
    await _c.from('work_orders').update({
      'assigned_contractor_id': contractorId, 'status': 'assigned', 'assigned_by': 'manager',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> setStatus(String id, String status) async {
    await _c.from('work_orders').update({'status': status}).eq('id', id);
  }

  /// Вернуть работу на доработку с комментарием (только автор или менеджер).
  Future<void> returnForRework(String id, String reason) async {
    await _c.from('work_orders').update({'status': 'returned', 'return_reason': reason}).eq('id', id);
  }
}

/// Понятный текст для ошибок, которые возвращает база при смене статуса.
String humanizeStatusError(Object e) {
  final m = '$e';
  if (m.contains('photo required')) return 'Нужно фото выполненной работы';
  if (m.contains('return reason required')) return 'Напишите, что нужно исправить';
  if (m.contains('not allowed')) return 'Это действие недоступно для вашей роли или текущего статуса';
  return 'Не получилось: $m';
}

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _onBrand = Color(0xFF06342A);

BoxDecoration _card() => BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line));

String _statusLabel(String s) => const {
      'new': 'Новая', 'assigned': 'Назначена', 'in_progress': 'В работе',
      'on_review': 'На проверке', 'returned': 'Возвращена',
      'done': 'Принята', 'cancelled': 'Отменена', 'overdue': 'Просрочено',
    }[s] ?? s;

String _priorityLabel(String p) => const {
      'low': 'Низкий', 'normal': 'Обычный', 'high': 'Высокий', 'critical': 'Критический',
    }[p] ?? p;

List<Color> _statusColors(String s) {
  switch (s) {
    case 'in_progress':
    case 'assigned':
      return const [Color(0xFFFBF0D9), Color(0xFFA9790C)];
    case 'on_review':
      return const [Color(0xFFE6EEFC), Color(0xFF2F6FE0)];
    case 'overdue':
    case 'returned':
      return const [Color(0xFFFBE8E8), Color(0xFFC24444)];
    case 'done':
    case 'cancelled':
      return const [Color(0xFFEAECEF), Color(0xFF6B7480)];
    default:
      return const [Color(0xFFE8F6F2), Color(0xFF249F88)];
  }
}

String _objNameIn(List<Obj> objects, String? id) {
  if (id == null) return 'Без объекта';
  for (final o in objects) { if (o.id == id) return o.name; }
  return 'Объект';
}

String _contractorNameIn(List<Contractor> list, String? id) {
  if (id == null) return 'не назначен';
  for (final c in list) { if (c.id == id) return c.orgName; }
  return 'исполнитель';
}

String _fmtDate(String? s) {
  if (s == null) return '—';
  final d = DateTime.tryParse(s)?.toLocal();
  if (d == null) return '—';
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
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
    setState(() { _loading = true; _error = null; });
    try {
      _companyId ??= await _dir.myCompanyId();
      _role ??= await _repo.myRole();
      final objs = await _dir.objects();
      final cons = await _dir.contractors();
      final data = await _repo.list();
      if (!mounted) return;
      setState(() { _objects = objs; _contractors = cons; _items = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  String _statusText() {
    if (_loading) return 'Загрузка…';
    if (_error != null) return 'Ошибка загрузки';
    return 'Заявок: ${_items.length}';
  }

  Future<void> _openDetail(WorkOrder w) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => WorkOrderDetailScreen(
        order: w, objects: _objects, contractors: _contractors,
        uid: _repo.uid, role: _role, repo: _repo, companyId: _companyId,
      ),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Stack(children: [
      Positioned.fill(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Text(_statusText(),
                style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Expanded(child: _body()),
        ]),
      ),
      Positioned(
        right: 4, bottom: 8,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          FloatingActionButton.small(
            heroTag: 'refreshReq', backgroundColor: Colors.white, foregroundColor: brand,
            onPressed: _load, child: const Icon(Icons.refresh)),
          const SizedBox(height: 10),
          Tooltip(message: 'Нажми и говори',
            child: FloatingActionButton.large(
              heroTag: 'voiceReq', backgroundColor: brand, foregroundColor: _onBrand,
              onPressed: _wake.trigger, child: const Icon(Icons.mic, size: 44))),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'addReq', backgroundColor: brand, foregroundColor: _onBrand,
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            label: const Text('Создать заявку', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
    ]);
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Не удалось загрузить заявки:\n$_error',
            style: const TextStyle(color: Color(0xFFC24444))),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('Пока нет заявок.\nНажми «Создать заявку».',
              textAlign: TextAlign.center, style: TextStyle(color: _muted)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final w = _items[i];
        final c = _statusColors(w.status);
        final high = w.priority == 'high' || w.priority == 'critical';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _openDetail(w),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _card(),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(width: 6, decoration: BoxDecoration(
                      color: high ? const Color(0xFFC24444) : const Color(0xFFD7DBE0),
                      borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.title + (w.recurring ? '  · регламент' : ''),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('${_objNameIn(_objects, w.objectId)}'
                        '${w.workType != null && w.workType!.isNotEmpty ? ' · ${w.workType}' : ''}',
                        style: const TextStyle(color: _muted, fontSize: 13)),
                  ])),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(20)),
                      child: Text(_statusLabel(w.status),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c[1]))),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: _muted, size: 20),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCreate() async {
    if (_companyId == null) { _snack('Профиль без компании (сделай себя админом).'); return; }
    final ok = await showOrderForm(
      context: context, repo: _repo, objects: _objects, companyId: _companyId!, existing: null);
    if (ok == true) { await _load(); _snackOk('Заявка создана'); }
  }

  Future<void> _openVoice() async {
    if (_voiceOpen || !mounted) return;
    if (_companyId == null) { _snack('Профиль без компании (сделай себя админом).'); return; }
    _voiceOpen = true;
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(
        builder: (_) => VoiceRecordScreen(companyId: _companyId!, objects: _objects)));
    _voiceOpen = false;
    if (ok == true) { await _load(); _snackOk('Заявка создана'); }
  }

  void _snack(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }
  void _snackOk(String m) {
    if (!mounted) return;
    final brand = Theme.of(context).colorScheme.primary;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: brand), const SizedBox(width: 10), Text(m),
    ])));
  }
}

class WorkOrderDetailScreen extends StatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.order, required this.objects,
      required this.contractors, required this.uid, required this.role,
      required this.repo, required this.companyId});
  final WorkOrder order;
  final List<Obj> objects;
  final List<Contractor> contractors;
  final String? uid;
  final String? role;
  final RequestsRepo repo;
  final String? companyId;

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await widget.repo.detail(widget.order.id);
      if (!mounted) return;
      setState(() { _d = d; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  bool get _isAuthor => widget.uid != null && _d?['created_by'] == widget.uid;
  bool get _isManager => widget.role == 'admin' || widget.role == 'manager';
  bool get _isExecutor => widget.role == 'executor' || widget.role == 'contractor';
  bool get _canEdit => _d != null && (_isAuthor || widget.role == 'admin');

  Future<void> _edit() async {
    final ok = await showOrderForm(
      context: context, repo: widget.repo, objects: widget.objects,
      companyId: widget.companyId ?? (_d!['company_id'] as String), existing: _d);
    if (ok == true) { await _load(); _ok('Сохранено'); }
  }

  Future<void> _assign() async {
    if (widget.contractors.isEmpty) {
      _ok('Сначала добавь подрядчика во вкладке «Исполнитель»');
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(4))),
          const Padding(padding: EdgeInsets.only(bottom: 6),
              child: Text('Назначить исполнителя', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final c in widget.contractors)
            ListTile(
              leading: const Icon(Icons.business),
              title: Text(c.orgName),
              onTap: () => Navigator.pop(ctx, c.id),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (chosen != null) {
      try { await widget.repo.assign(widget.order.id, chosen); await _load(); _ok('Исполнитель назначен'); }
      catch (e) { _ok('Ошибка: $e'); }
    }
  }

  Future<void> _setStatus(String status, String okText) async {
    try { await widget.repo.setStatus(widget.order.id, status); await _load(); _ok(okText); }
    catch (e) { _ok(humanizeStatusError(e)); }
  }

  Future<void> _returnForRework() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вернуть на доработку'),
        content: TextField(controller: c, autofocus: true, maxLines: 3,
            decoration: const InputDecoration(hintText: 'Что нужно исправить?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Вернуть')),
        ],
      ),
    );
    if (reason == null) return;
    if (reason.isEmpty) { _ok('Напишите, что нужно исправить'); return; }
    try { await widget.repo.returnForRework(widget.order.id, reason); await _load(); _ok('Возвращено исполнителю'); }
    catch (e) { _ok(humanizeStatusError(e)); }
  }

  void _ok(String m) {
    if (!mounted) return;
    final brand = Theme.of(context).colorScheme.primary;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: brand), const SizedBox(width: 10), Flexible(child: Text(m)),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявка'),
        actions: [
          if (_canEdit)
            IconButton(tooltip: 'Редактировать', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(padding: const EdgeInsets.all(24),
                  child: Text('Ошибка: $_error', style: const TextStyle(color: Color(0xFFC24444))))
              : _content(),
    );
  }

  Widget _content() {
    final d = _d!;
    final status = (d['status'] ?? 'new') as String;
    final c = _statusColors(status);
    final priority = (d['priority'] ?? 'normal') as String;
    final recurring = d['recurrence'] != null;
    final title = (d['title'] ?? '') as String;
    final desc = (d['description'] ?? '') as String?;
    final workType = (d['work_type'] ?? '') as String?;
    final objId = d['object_id'] as String?;
    final contractorId = d['assigned_contractor_id'] as String?;
    final mineNote = _isAuthor ? ' (вы)' : '';
    final brand = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(children: [
          Expanded(child: Text(title + (recurring ? '  · регламент' : ''),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel(status),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c[1]))),
        ]),
        const SizedBox(height: 20),
        _row('Объект', _objNameIn(widget.objects, objId)),
        _row('Исполнитель', _contractorNameIn(widget.contractors, contractorId)),
        _row('Вид работ', (workType == null || workType.isEmpty) ? '—' : workType),
        _row('Приоритет', _priorityLabel(priority)),
        _row('Тип', recurring ? 'Регламентная' : 'Разовая'),
        _row('Фотоподтверждение', (d['requires_photo'] == true) ? 'Требуется' : 'Не требуется'),
        _row('Создана', _fmtDate(d['created_at'] as String?) + mineNote),
        const SizedBox(height: 16),
        const Text('Описание', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _card(),
          child: Text((desc == null || desc.isEmpty) ? 'Без описания' : desc,
              style: TextStyle(color: (desc == null || desc.isEmpty) ? _muted : _ink, fontSize: 14)),
        ),
        if ((d['return_reason'] as String?)?.isNotEmpty == true && status == 'returned') ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFBE8E8), borderRadius: BorderRadius.circular(14)),
            child: Text('Возвращено: ${d['return_reason']}',
                style: const TextStyle(color: Color(0xFFC24444), fontWeight: FontWeight.w600)),
          ),
        ],
        if (_actions(status, contractorId, brand).isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Действия', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: _actions(status, contractorId, brand)),
        ],
      ],
    );
  }

  /// Кнопки зависят от роли и статуса. Те же правила проверяет база.
  List<Widget> _actions(String status, String? contractorId, Color brand) {
    final canWork = _isExecutor || _isManager;
    final canAccept = _isAuthor || _isManager;
    final filled = FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand);
    return [
      if (_isManager && (status == 'new' || status == 'assigned' || status == 'returned'))
        OutlinedButton.icon(
          onPressed: _assign,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: Text(contractorId == null ? 'Назначить исполнителя' : 'Сменить исполнителя'),
        ),
      if (canWork && (status == 'new' || status == 'assigned' || status == 'returned'))
        FilledButton.icon(
          onPressed: () => _setStatus('in_progress', 'Заявка в работе'),
          style: filled,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(status == 'returned' ? 'Взять на доработку' : 'Взять в работу'),
        ),
      if (canWork && status == 'in_progress')
        FilledButton.icon(
          onPressed: () => _setStatus('on_review', 'Отправлено на проверку'),
          style: filled,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Выполнено, на проверку'),
        ),
      if (canAccept && status == 'on_review') ...[
        FilledButton.icon(
          onPressed: () => _setStatus('done', 'Работа принята'),
          style: filled,
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: const Text('Принять работу'),
        ),
        OutlinedButton.icon(
          onPressed: _returnForRework,
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC24444)),
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text('Вернуть на доработку'),
        ),
      ],
      if (canAccept && status != 'done' && status != 'cancelled')
        OutlinedButton.icon(
          onPressed: () => _setStatus('cancelled', 'Заявка отменена'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC24444)),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Отменить'),
        ),
    ];
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: _muted, fontSize: 14))),
          Expanded(child: Text(v, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600))),
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
  // Виды работ = слои компании из базы. Если база недоступна — список по умолчанию.
  List<String> workTypes = const ['Климат', 'Электрика', 'Сантехника', 'Клининг',
      'Системы безопасности', 'Мебель', 'Другое'];
  try {
    final fromDb = await DirectoryRepo().layerNames();
    if (fromDb.isNotEmpty) workTypes = fromDb;
  } catch (_) {}
  if (!context.mounted) return null;

  final isEdit = existing != null;
  final titleC = TextEditingController(text: isEdit ? (existing['title'] ?? '') as String : '');
  final descC = TextEditingController(text: isEdit ? (existing['description'] ?? '') as String? ?? '' : '');
  String? workType = isEdit ? existing['work_type'] as String? : null;
  String priority = isEdit ? (existing['priority'] ?? 'normal') as String : 'normal';
  String? objectId = isEdit ? existing['object_id'] as String? : null;
  bool recurring = isEdit ? existing['recurrence'] != null : false;

  const priorities = [['low', 'Низкий'], ['normal', 'Обычный'], ['high', 'Высокий'], ['critical', 'Критич.']];
  final brand = Theme.of(context).colorScheme.primary;

  return showModalBottomSheet<bool>(
    context: context, isScrollControlled: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(4)))),
              Text(isEdit ? 'Редактировать заявку' : 'Новая заявка',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              _lbl('Что случилось?'),
              _inp(titleC, 'Например, Протекает кран'),
              _lbl('Описание'),
              _inp(descC, 'Подробности', lines: 3),
              _lbl('Объект'),
              _Dropdown(
                value: objectId,
                hint: objects.isEmpty ? 'Нет объектов (добавь во вкладке Локации)' : 'Выбери объект',
                items: [for (final o in objects) DropdownMenuItem(value: o.id, child: Text(o.name))],
                onChanged: (v) => setSt(() => objectId = v)),
              _lbl('Вид работ'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in workTypes) _chip(t, workType == t, brand, () => setSt(() => workType = t))]),
              _lbl('Приоритет'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in priorities) _chip(p[1], priority == p[0], brand, () => setSt(() => priority = p[0]))]),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Text('Регламентная (повторяющаяся)', style: TextStyle(fontSize: 15))),
                Switch(value: recurring, activeTrackColor: brand, onChanged: (v) => setSt(() => recurring = v))]),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand),
                onPressed: () async {
                  if (titleC.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Впиши, что случилось')));
                    return;
                  }
                  try {
                    if (isEdit) {
                      await repo.update(existing['id'] as String,
                          title: titleC.text.trim(),
                          description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                          workType: workType, priority: priority, objectId: objectId, recurring: recurring);
                    } else {
                      await repo.create(companyId: companyId, title: titleC.text.trim(),
                          description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                          workType: workType, priority: priority, objectId: objectId, recurring: recurring);
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (_) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Не удалось сохранить заявку. Проверьте интернет и попробуйте ещё раз.')));
                  }
                },
                child: Text(isEdit ? 'Сохранить' : 'Создать заявку',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      ),
    ),
  );
}

Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)));

Widget _inp(TextEditingController c, String hint, {int lines = 1}) => TextField(
    controller: c, maxLines: lines,
    decoration: InputDecoration(hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14)));

Widget _chip(String label, bool on, Color brand, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: on ? const Color(0xFFE8F6F2) : Colors.white,
            borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? brand : _line)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: on ? const Color(0xFF249F88) : _ink))));

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.hint, required this.items, required this.onChanged});
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: _muted, fontSize: 15)),
          items: items, onChanged: items.isEmpty ? null : onChanged)));
  }
}