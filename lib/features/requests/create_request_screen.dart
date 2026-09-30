import 'package:flutter/material.dart';

import '../directory/directory.dart';
import 'requests.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _onBrand = Color(0xFF06342A);
const _danger = Color(0xFFC24444);

const workTypes = ['Сантехника', 'Электрика', 'Климат', 'Клининг', 'Мебель', 'Другое'];
const _priorities = [['low', 'Низкий'], ['normal', 'Обычный'], ['high', 'Высокий'], ['critical', 'Критич.']];
const _periods = [['day', 'Ежедневно'], ['week', 'Еженедельно'], ['month', 'Ежемесячно']];

/// Экран создания и редактирования заявки.
///
/// Возвращает `true` через Navigator.pop, если заявка сохранена.
/// При создании заявка и чек-лист пишутся одной транзакцией (RPC create_work_order).
class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key, required this.repo, required this.objects, this.existing});

  final RequestsRepo repo;
  final List<Obj> objects;

  /// Строка work_orders для редактирования; null — новая заявка.
  final Map<String, dynamic>? existing;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  final _checkItem = TextEditingController();
  final _checklist = <String>[];

  String? _workType;
  String _priority = 'normal';
  String? _objectId;
  String? _period;
  DateTime? _dueAt;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?['title'] as String? ?? '');
    _desc = TextEditingController(text: e?['description'] as String? ?? '');
    if (e != null) {
      _workType = e['work_type'] as String?;
      _priority = (e['priority'] ?? 'normal') as String;
      _period = recurrencePeriod(e['recurrence']);
      _dueAt = DateTime.tryParse(e['due_at'] as String? ?? '')?.toLocal();
    }
    // Объект мог быть удалён — тогда DropdownButton упал бы на неизвестном value.
    final objectId = e?['object_id'] as String?;
    if (widget.objects.any((o) => o.id == objectId)) _objectId = objectId;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _checkItem.dispose();
    super.dispose();
  }

  void _addCheckItem() {
    final text = _checkItem.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(text);
      _checkItem.clear();
    });
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? DateTime(now.year, now.month, now.day, 18)),
    );
    if (!mounted) return;
    final t = time ?? const TimeOfDay(hour: 18, minute: 0);
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    // Недописанный пункт чек-листа тоже сохраняем, а не теряем молча.
    if (_checkItem.text.trim().isNotEmpty) _addCheckItem();

    final draft = WorkOrderDraft(
      title: _title.text,
      description: _desc.text,
      workType: _workType,
      priority: _priority,
      objectId: _objectId,
      period: _period,
      dueAt: _dueAt,
      checklist: List.of(_checklist),
    );

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.repo.update(widget.existing!['id'] as String, draft);
      } else {
        await widget.repo.createOrder(draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeSaveError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(_isEdit ? 'Редактировать заявку' : 'Новая заявка')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _label('Что случилось?'),
              TextFormField(
                controller: _title,
                enabled: !_saving,
                autofocus: !_isEdit,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: _deco('Например, протекает кран'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Опишите проблему в двух словах' : null,
              ),
              _label('Описание'),
              TextFormField(
                controller: _desc,
                enabled: !_saving,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('Подробности: где именно, что уже пробовали'),
              ),
              _label('Объект'),
              DropdownButtonFormField<String>(
                initialValue: _objectId,
                isExpanded: true,
                decoration: _deco(widget.objects.isEmpty
                    ? 'Нет объектов (добавьте во вкладке «Локации»)'
                    : 'Выберите объект'),
                items: [
                  for (final o in widget.objects) DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: _saving || widget.objects.isEmpty ? null : (v) => setState(() => _objectId = v),
              ),
              _label('Вид работ'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in workTypes)
                  _chip(t, _workType == t, brand,
                      () => setState(() => _workType = _workType == t ? null : t)),
              ]),
              _label('Приоритет'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _priorities)
                  _chip(p[1], _priority == p[0], brand, () => setState(() => _priority = p[0])),
              ]),
              _label('Срок'),
              _DueTile(
                dueAt: _dueAt,
                onPick: _saving ? null : _pickDue,
                onClear: _saving || _dueAt == null ? null : () => setState(() => _dueAt = null),
              ),
              _label('Тип заявки'),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Разовая'), icon: Icon(Icons.bolt_outlined)),
                  ButtonSegment(value: true, label: Text('Регламентная'), icon: Icon(Icons.event_repeat)),
                ],
                selected: {_period != null},
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() => _period = s.first ? (_period ?? 'week') : null),
              ),
              if (_period != null) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in _periods)
                    _chip(p[1], _period == p[0], brand, () => setState(() => _period = p[0])),
                ]),
              ],
              if (!_isEdit) ..._checklistSection(brand),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('submitRequest'),
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(_isEdit ? 'Сохранить' : 'Создать заявку',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _checklistSection(Color brand) => [
        _label('Чек-лист'),
        for (var i = 0; i < _checklist.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
            child: Row(children: [
              Icon(Icons.check_box_outline_blank, size: 20, color: brand),
              const SizedBox(width: 10),
              Expanded(child: Text(_checklist[i], style: const TextStyle(fontSize: 14))),
              IconButton(
                tooltip: 'Убрать пункт',
                icon: const Icon(Icons.close, size: 18, color: _muted),
                onPressed: _saving ? null : () => setState(() => _checklist.removeAt(i)),
              ),
            ]),
          ),
        TextField(
          controller: _checkItem,
          enabled: !_saving,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addCheckItem(),
          decoration: _deco('Добавить пункт, например «Перекрыть воду»').copyWith(
            suffixIcon: IconButton(
              tooltip: 'Добавить пункт',
              icon: Icon(Icons.add_circle, color: brand),
              onPressed: _saving ? null : _addCheckItem,
            ),
          ),
        ),
      ];
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.dueAt, required this.onPick, required this.onClear});
  final DateTime? dueAt;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final overdue = dueAt != null && dueAt!.isBefore(DateTime.now());
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 4, 4, 4),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
        child: Row(children: [
          const Icon(Icons.event_outlined, size: 20, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dueAt == null ? 'Без срока' : 'До ${formatDateTime(dueAt!)}',
              style: TextStyle(
                  fontSize: 15, color: dueAt == null ? _muted : (overdue ? _danger : _ink)),
            ),
          ),
          if (onClear != null)
            IconButton(tooltip: 'Убрать срок', icon: const Icon(Icons.close, size: 18), onPressed: onClear),
        ]),
      ),
    );
  }
}

InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14));

Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)));

Widget _chip(String label, bool on, Color brand, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: on ? const Color(0xFFE8F6F2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? brand : _line)),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: on ? const Color(0xFF249F88) : _ink))));
