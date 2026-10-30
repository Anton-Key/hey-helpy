import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../offline/offline_logic.dart';
import '../offline/offline_service.dart';

/// Чек-лист заявки (шаг 27). Пункты заводит менеджер (ППР — из плана),
/// отмечает только исполнитель назначенного подрядчика, пока заявка «в
/// работе» (0023, `trg_checklist_guard`). Без сети — отметка уходит в
/// очередь телефона и видна сразу со значком «ждёт отправки».
class OrderChecklistSection extends StatefulWidget {
  const OrderChecklistSection(
      {super.key,
      required this.orderId,
      required this.canCheck,
      this.pending = const {}});
  final String orderId;
  final bool canCheck;

  /// Отметки, которые ещё не ушли на сервер: item_id → отмечен.
  final Map<String, bool> pending;

  @override
  State<OrderChecklistSection> createState() => OrderChecklistSectionState();
}

class OrderChecklistSectionState extends State<OrderChecklistSection> {
  final _off = OfflineService.instance;
  List<Map<String, dynamic>> _items = const [];
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final rows = await _off.cachedJson(
          'checklist:${widget.orderId}',
          () => Supabase.instance.client
              .from('checklist_items')
              .select('id,work_order_id,text,is_done,done_at,created_at')
              .eq('work_order_id', widget.orderId)
              .order('created_at'));
      if (!mounted) return;
      setState(() => _items = [
            for (final r in (rows as List?) ?? const [])
              Map<String, dynamic>.from(r as Map)
          ]);
    } catch (e) {
      debugPrint('checklist: ${e.runtimeType}');
    }
  }

  bool _done(Map<String, dynamic> i) =>
      widget.pending[i['id']] ?? (i['is_done'] == true);

  Future<void> _toggle(Map<String, dynamic> i) async {
    final l = context.l10n;
    final id = i['id'] as String;
    final value = !_done(i);
    setState(() => _busy.add(id));
    try {
      final queued = await _off.runOrQueue(
          orderId: widget.orderId,
          kind: OfflineKind.check,
          payload: {'item_id': id, 'done': value},
          online: () => Supabase.instance.client
              .from('checklist_items')
              .update({'is_done': value}).eq('id', id));
      if (!queued) await reload();
    } catch (e) {
      debugPrint('checklist toggle: $e');
      if (mounted) {
        showAppMessage(context, l.checklistSaveFailed,
            type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final done = _items.where(_done).length;
    return AppGroup(
      header:
          '${l.checklistTitle} · ${l.checklistProgress(done, _items.length)}',
      children: [
        for (final i in _items)
          AppRow(
            key: ValueKey('check-${i['id']}'),
            leading: Icon(_done(i) ? AppIcons.checkboxOn : AppIcons.checkboxOff,
                color: _done(i) ? AppColors.accentText : AppColors.secondary),
            title: '${i['text'] ?? ''}',
            subtitle:
                widget.pending.containsKey(i['id']) ? l.offPendingBadge : null,
            trailing: widget.pending.containsKey(i['id'])
                ? const Icon(AppIcons.uploadPending,
                    size: 18, color: AppColors.secondary)
                : null,
            chevron: false,
            onTap: widget.canCheck && !_busy.contains(i['id'])
                ? () => _toggle(i)
                : null,
          ),
      ],
    );
  }
}

/// Снимки «после», которые ещё на телефоне: миниатюры «ждёт отправки».
class PendingPhotosRow extends StatelessWidget {
  const PendingPhotosRow(
      {super.key, required this.actions, this.before = false});
  final List<OfflineAction> actions;

  /// Фото «до» (шаг 32), иначе «после».
  final bool before;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppGroup(
      header:
          '${before ? l.offKindPhotoBefore : l.offKindPhoto} · ${l.offPendingBadge}',
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpace.m),
          child: Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
            for (final a in actions)
              FutureBuilder(
                future: OfflineService.instance.photoBytes(a),
                builder: (context, snap) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.group / 2),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: snap.data == null
                        ? const ColoredBox(color: AppColors.fill)
                        : Image.memory(snap.data!, fit: BoxFit.cover),
                  ),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}
