import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';

const _danger = Color(0xFFC24444);

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

  @override
  Widget build(BuildContext context) {
    if (!canCancel && !canDelete) return const SizedBox.shrink();
    final l = context.l10n;
    return PopupMenuButton<_OrderMenuItem>(
      tooltip: l.detailMore,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (v) => switch (v) {
        _OrderMenuItem.cancel => onCancel(),
        _OrderMenuItem.delete => onDelete(),
      },
      itemBuilder: (_) => [
        if (canCancel)
          PopupMenuItem(
              value: _OrderMenuItem.cancel,
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.close_rounded),
                  title: Text(l.actionCancel))),
        if (canDelete)
          PopupMenuItem(
              value: _OrderMenuItem.delete,
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  iconColor: _danger,
                  textColor: _danger,
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(l.actionDelete))),
      ],
    );
  }
}

/// Подтверждение удаления заявки. true — человек нажал «Удалить».
Future<bool> confirmDeleteOrder(BuildContext context) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(l.deleteOrderConfirm,
          style: const TextStyle(fontSize: 16, height: 1.4)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel)),
        FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionDelete)),
      ],
    ),
  );
  return ok ?? false;
}
