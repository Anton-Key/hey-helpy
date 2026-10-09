import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';

enum _OrderMenuItem { cancel, delete }

/// Меню «⋯» в шапке карточки заявки: «Отменить» и «Удалить» видны сразу,
/// без прокрутки до блока «Действия». Пустое меню не показывается.
class OrderMenu extends StatelessWidget {
  const OrderMenu(
      {super.key,
      required this.canCancel,
      required this.canDelete,
      required this.onCancel,
      required this.onDelete});
  final bool canCancel, canDelete;
  final VoidCallback onCancel, onDelete;

  Future<void> _open(BuildContext context) async {
    final l = context.l10n;
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = Rect.fromPoints(
      box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final chosen = await showMenu<_OrderMenuItem>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        if (canCancel)
          PopupMenuItem(
            value: _OrderMenuItem.cancel,
            child: _MenuRow(icon: AppIcons.close, text: l.actionCancel),
          ),
        if (canDelete)
          PopupMenuItem(
            value: _OrderMenuItem.delete,
            child: _MenuRow(
                icon: AppIcons.delete, text: l.actionDelete, danger: true),
          ),
      ],
    );
    switch (chosen) {
      case _OrderMenuItem.cancel:
        onCancel();
      case _OrderMenuItem.delete:
        onDelete();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canCancel && !canDelete) return const SizedBox.shrink();
    return Builder(
      builder: (context) => AppIconButton(
        icon: AppIcons.more,
        label: context.l10n.detailMore,
        onPressed: () => _open(context),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text, this.danger = false});
  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return Row(children: [
      Expanded(child: Text(text, style: AppText.body.copyWith(color: color))),
      const SizedBox(width: AppSpace.l),
      Icon(icon, size: AppSizes.icon, color: color),
    ]);
  }
}

/// Подтверждение удаления заявки. true — человек нажал «Удалить».
Future<bool> confirmDeleteOrder(BuildContext context) async {
  final l = context.l10n;
  // Вопрос — заголовком, пояснение — текстом под ним.
  final text = l.deleteOrderConfirm;
  final cut = text.indexOf('?');
  final ok = await showAppDialog<bool>(
    context: context,
    title: cut < 0 ? text : text.substring(0, cut + 1),
    message: cut < 0 ? null : text.substring(cut + 1).trim(),
    actions: [
      AppDialogAction(l.actionDelete, true, destructive: true),
      AppDialogAction(l.commonCancel, false),
    ],
  );
  return ok ?? false;
}
