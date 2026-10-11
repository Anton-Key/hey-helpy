import '../../l10n/app_localizations.dart';
import 'ppr_logic.dart';

/// Подписи ППР на языке интерфейса.

/// Слова для [periodLabel]: по-русски квартал и полугодие — римскими цифрами.
PeriodWords pprWords(AppLocalizations l) {
  final ru = l.localeName.startsWith('ru');
  return PeriodWords(
    locale: l.localeName,
    quarter: (roman, n, y) => l.pprQuarterLabel(ru ? roman : '$n', '$y'),
    half: (roman, n, y) => l.pprHalfLabel(ru ? roman : '$n', '$y'),
    year: (y) => l.pprYearLabel('$y'),
  );
}

/// «октябрь 2026», «IV кв. 2026»…
String pprPeriodText(AppLocalizations l, PeriodKind kind, PeriodBounds p) =>
    periodLabel(kind, p, pprWords(l));

/// «каждый месяц», «каждые 10 дней».
String pprEvery(AppLocalizations l, PeriodKind kind, int? days) =>
    switch (kind) {
      PeriodKind.month => l.pprEveryMonth,
      PeriodKind.quarter => l.pprEveryQuarter,
      PeriodKind.halfYear => l.pprEveryHalfYear,
      PeriodKind.year => l.pprEveryYear,
      PeriodKind.days => l.pprEveryDays(days ?? 1),
    };

/// Название вида периода в форме («Месяц», «Квартал»…).
String pprKindName(AppLocalizations l, PeriodKind kind) => switch (kind) {
      PeriodKind.month => l.pprKindMonth,
      PeriodKind.quarter => l.pprKindQuarter,
      PeriodKind.halfYear => l.pprKindHalfYear,
      PeriodKind.year => l.pprKindYear,
      PeriodKind.days => l.pprKindDays,
    };

String pprStateLabel(AppLocalizations l, PeriodState s) => switch (s) {
      PeriodState.done => l.pprStateDone,
      PeriodState.inProgress => l.pprStateInProgress,
      PeriodState.notStarted => l.pprStateNotStarted,
      PeriodState.overdue => l.pprStateOverdue,
      PeriodState.paused => l.pprStatePaused,
    };

/// «ППР · октябрь 2026 · до 31 окт.» — строка задачи периода в списке и
/// карточке заявки. null — у заявки нет периода (не ППР или база без 0015).
String? pprTaskLine(AppLocalizations l,
    {required Object? recurrence,
    required Object? periodStart,
    required Object? periodEnd}) {
  final s = parseDate(periodStart);
  final e = parseDate(periodEnd);
  if (s == null || e == null) return null;
  final kind = pprKindOf(recurrence) ?? _guessKind(s, e);
  final period = pprPeriodText(l, kind, PeriodBounds(s, e));
  return l.pprTaskLine(period, shortDay(e, l.localeName));
}

/// Вид периода по его границам (если в recurrence его нет).
PeriodKind _guessKind(DateTime s, DateTime e) {
  for (final k in const [
    PeriodKind.month,
    PeriodKind.quarter,
    PeriodKind.halfYear,
    PeriodKind.year
  ]) {
    if (periodBounds(k, on: s) == PeriodBounds(s, e)) return k;
  }
  return PeriodKind.days;
}
