import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n_ext.dart';

enum PeriodKind { week, last30, month, custom }

/// Период для отчётов и истории: неделя (с понедельника), последние 30 дней
/// (по сегодня включительно), календарный месяц или свой диапазон дат.
/// [to] — не включительно (начало следующего дня).
class Period {
  const Period(this.kind, [this.custom]);
  final PeriodKind kind;
  final DateTimeRange? custom;

  ({DateTime from, DateTime to}) range([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    switch (kind) {
      case PeriodKind.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (
          from: monday,
          to: DateTime(monday.year, monday.month, monday.day + 7)
        );
      case PeriodKind.last30:
        return (
          from: DateTime(today.year, today.month, today.day - 29),
          to: DateTime(today.year, today.month, today.day + 1)
        );
      case PeriodKind.month:
        return (
          from: DateTime(n.year, n.month),
          to: DateTime(n.year, n.month + 1)
        );
      case PeriodKind.custom:
        final r = custom ??
            DateTimeRange(
                start: today.subtract(const Duration(days: 29)), end: today);
        return (
          from: DateTime(r.start.year, r.start.month, r.start.day),
          to: DateTime(r.end.year, r.end.month, r.end.day + 1)
        );
    }
  }

  /// «1 окт. 2026 г. – 31 окт. 2026 г.» по языку интерфейса.
  String label(BuildContext context) {
    final l = context.l10n;
    final r = range();
    final date = DateFormat.yMMMd(l.localeName);
    return l.reportsRange(date.format(r.from),
        date.format(r.to.subtract(const Duration(days: 1))));
  }
}

/// Переключатель «Неделя / 30 дней / Месяц / Свой» и строка с датами.
/// Нажатие на даты открывает календарь.
class PeriodBar extends StatelessWidget {
  const PeriodBar({super.key, required this.period, required this.onChanged});
  final Period period;
  final ValueChanged<Period> onChanged;

  Future<void> _pick(BuildContext context, PeriodKind kind) async {
    if (kind != PeriodKind.custom) {
      onChanged(Period(kind));
      return;
    }
    final now = DateTime.now();
    // Свой период, пока его не выбирали, начинается с последних 30 дней.
    final r = period.kind == PeriodKind.custom
        ? period.range()
        : const Period(PeriodKind.last30).range();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
          start: r.from, end: r.to.subtract(const Duration(days: 1))),
    );
    if (picked != null) onChanged(Period(PeriodKind.custom, picked));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<PeriodKind>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
                value: PeriodKind.week, label: Text(l.reportsPeriodWeek)),
            ButtonSegment(
                value: PeriodKind.last30, label: Text(l.reportsPeriod30)),
            ButtonSegment(
                value: PeriodKind.month, label: Text(l.reportsPeriodMonth)),
            ButtonSegment(
                value: PeriodKind.custom, label: Text(l.reportsPeriodCustom)),
          ],
          selected: {period.kind},
          onSelectionChanged: (s) => _pick(context, s.first),
        ),
      ),
      const SizedBox(height: 6),
      // Даты — тоже кнопка: так календарь открывается и когда «Свой период» уже выбран.
      TextButton.icon(
        onPressed: () => _pick(context, PeriodKind.custom),
        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
        label: Text(period.label(context),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    ]);
  }
}
