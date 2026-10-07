import 'package:flutter/material.dart';

import 'l10n_ext.dart';

/// Цвета плашки статуса: фон и текст. Единственный источник для всех экранов
/// (список заявок, карточка, «История», отчёты). Правило — раздел «Дизайн»
/// в CLAUDE.md. Контраст текста к фону — не ниже 4.5:1 (в скобках).
class StatusStyle {
  const StatusStyle(this.background, this.foreground);
  final Color background;
  final Color foreground;

  /// Новая — жёлтый (6.1:1).
  static const yellow = StatusStyle(Color(0xFFFBF0D9), Color(0xFF7A5300));

  /// Назначена, в работе, на проверке — синий (5.9:1).
  static const blue = StatusStyle(Color(0xFFE6EEFC), Color(0xFF1F55B8));

  /// Срочная, просрочена, возвращена — красный (5.6:1).
  static const red = StatusStyle(Color(0xFFFBE8E8), Color(0xFFB02A2A));

  /// Принята — тёмно-серый, с галочкой (8.0:1).
  static const done = StatusStyle(Color(0xFF4A515B), Colors.white);

  /// Отменена — серый (5.5:1).
  static const grey = StatusStyle(Color(0xFFEEF0F2), Color(0xFF5A616B));

  /// Красная полоса срочной заявки в списке.
  static const urgentAccent = Color(0xFFB02A2A);

  static StatusStyle of(String status) => switch (status) {
        'new' => yellow,
        'assigned' || 'in_progress' || 'on_review' => blue,
        'returned' || 'overdue' || 'urgent' => red,
        'done' => done,
        _ => grey,
      };
}

/// Плашка статуса заявки. [large] — для заголовка карточки заявки.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.large = false});
  final String status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = StatusStyle.of(status);
    final size = large ? 12.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 10, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
          color: c.background, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == 'done') ...[
          Icon(Icons.check_rounded, size: size + 2, color: c.foreground),
          const SizedBox(width: 3),
        ],
        Text(context.l10n.status(status),
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: c.foreground)),
      ]),
    );
  }
}
