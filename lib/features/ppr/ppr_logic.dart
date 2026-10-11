import 'package:intl/intl.dart';

/// ППР — планово-предупредительные (регламентные) работы (шаг 16, 0015).
/// Чистые функции: границы и подписи периодов, состояние текущего периода,
/// фильтры списка планов. Тесты — `test/ppr_logic_test.dart`.
///
/// Границы периодов считаются так же, как функция базы `period_bounds`:
/// месяц, квартал, полугодие и год — календарные; «каждые N дней» —
/// от даты начала плана шагами по N дней.

/// Периодичность плана (maintenance_plans.period_kind).
enum PeriodKind {
  month('month'),
  quarter('quarter'),
  halfYear('half_year'),
  year('year'),
  days('days');

  const PeriodKind(this.code);

  /// Код в базе.
  final String code;

  static PeriodKind? fromCode(String? code) {
    for (final k in values) {
      if (k.code == code) return k;
    }
    return null;
  }
}

/// Начало и конец периода (даты без времени, включительно).
class PeriodBounds {
  const PeriodBounds(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodBounds && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PeriodBounds($start – $end)';
}

/// Дата без времени (UTC-полночь — сравнение и разница в днях без
/// перехода на летнее время).
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Дата из ответа базы ('2026-10-01').
DateTime? parseDate(Object? v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? null : dateOnly(d);
}

/// Период, в который попадает [on]. Для [PeriodKind.days] нужны [days] и
/// [startsOn]; дата раньше начала — предыдущий шаг (как в базе).
PeriodBounds periodBounds(PeriodKind kind,
    {int? days, DateTime? startsOn, required DateTime on}) {
  final d = dateOnly(on);
  switch (kind) {
    case PeriodKind.month:
      final s = DateTime.utc(d.year, d.month, 1);
      return PeriodBounds(s, DateTime.utc(d.year, d.month + 1, 0));
    case PeriodKind.quarter:
      final m = ((d.month - 1) ~/ 3) * 3 + 1;
      return PeriodBounds(
          DateTime.utc(d.year, m, 1), DateTime.utc(d.year, m + 3, 0));
    case PeriodKind.halfYear:
      final m = d.month > 6 ? 7 : 1;
      return PeriodBounds(
          DateTime.utc(d.year, m, 1), DateTime.utc(d.year, m + 6, 0));
    case PeriodKind.year:
      return PeriodBounds(
          DateTime.utc(d.year, 1, 1), DateTime.utc(d.year, 12, 31));
    case PeriodKind.days:
      final n = (days == null || days < 1) ? 1 : days;
      final base = dateOnly(startsOn ?? d);
      final diff = d.difference(base).inDays;
      final step = (diff / n).floor();
      final s = base.add(Duration(days: step * n));
      return PeriodBounds(s, s.add(Duration(days: n - 1)));
  }
}

/// Предыдущий период (для истории).
PeriodBounds previousPeriod(PeriodKind kind, PeriodBounds p,
        {int? days, DateTime? startsOn}) =>
    periodBounds(kind,
        days: days,
        startsOn: startsOn,
        on: p.start.subtract(const Duration(days: 1)));

const _roman = ['I', 'II', 'III', 'IV'];

/// Подпись периода: «октябрь 2026», «IV кв. 2026», «II полугодие 2026»,
/// «2026 год», «01.10–10.10.2026»; по-английски — «October 2026», «Q4 2026»,
/// «H2 2026», «2026». Слова для русского и английского — [words].
String periodLabel(PeriodKind kind, PeriodBounds p, PeriodWords words) {
  final y = p.start.year;
  switch (kind) {
    case PeriodKind.month:
      return '${DateFormat('LLLL', words.locale).format(p.start)} $y';
    case PeriodKind.quarter:
      final q = (p.start.month - 1) ~/ 3 + 1;
      return words.quarter(_roman[q - 1], q, y);
    case PeriodKind.halfYear:
      final h = p.start.month > 6 ? 2 : 1;
      return words.half(_roman[h - 1], h, y);
    case PeriodKind.year:
      return words.year(y);
    case PeriodKind.days:
      return '${DateFormat('dd.MM').format(p.start)}–'
          '${DateFormat('dd.MM.yyyy').format(p.end)}';
  }
}

/// Слова подписи периода на языке интерфейса (из переводов).
class PeriodWords {
  const PeriodWords(
      {required this.locale,
      required this.quarter,
      required this.half,
      required this.year});
  final String locale;
  final String Function(String roman, int n, int year) quarter;
  final String Function(String roman, int n, int year) half;
  final String Function(int year) year;
}

/// Короткая дата «до 31 окт.» — день и месяц.
String shortDay(DateTime d, String locale) => DateFormat.MMMd(locale).format(d);

/// Состояние текущего периода плана — цвет в списке.
enum PeriodState { done, inProgress, notStarted, overdue, paused }

/// Состояние периода по статусу его задачи. [task] — статус задачи периода
/// (null — задачи ещё нет). Просрочено — период закончился, а работа не
/// принята.
PeriodState periodState(
    {required bool active,
    String? task,
    required PeriodBounds period,
    DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final ended = today.isAfter(period.end);
  if (task == 'done') return PeriodState.done;
  if (!active) return PeriodState.paused;
  if (ended) return PeriodState.overdue;
  if (task == 'in_progress' || task == 'on_review') {
    return PeriodState.inProgress;
  }
  return PeriodState.notStarted;
}

/// Статус-капсула для состояния (цвета [StatusColors]).
String periodStateStatus(PeriodState s) => switch (s) {
      PeriodState.done => 'done',
      PeriodState.inProgress => 'in_progress',
      PeriodState.notStarted => 'new',
      PeriodState.overdue => 'overdue',
      PeriodState.paused => 'cancelled',
    };

/// Порядок групп в списке: сначала то, что требует внимания.
int periodStateOrder(PeriodState s) => switch (s) {
      PeriodState.overdue => 0,
      PeriodState.notStarted => 1,
      PeriodState.inProgress => 2,
      PeriodState.done => 3,
      PeriodState.paused => 4,
    };

/// «Выполнено N из M» за текущий месяц: планы, у которых период — месяц,
/// и все прочие активные планы, чей текущий период пересекается с месяцем.
({int done, int total}) monthSummary(
    Iterable<({bool active, PeriodState state})> plans) {
  var done = 0, total = 0;
  for (final p in plans) {
    if (!p.active && p.state != PeriodState.done) continue;
    total++;
    if (p.state == PeriodState.done) done++;
  }
  return (done: done, total: total);
}

/// Задача периода ППР: по plan_id или по recurrence.kind = 'ppr'.
bool isPprOrder(Map<String, dynamic> row) {
  if (row['plan_id'] != null) return true;
  final r = row['recurrence'];
  return r is Map && r['kind'] == 'ppr';
}

/// Периодичность задачи из recurrence ({"kind":"ppr","period":"month"}).
PeriodKind? pprKindOf(Object? recurrence) => recurrence is Map
    ? PeriodKind.fromCode(recurrence['period'] as String?)
    : null;

/// Порог: генерация задач не чаще раза в 10 минут.
const pprGenerateEvery = Duration(minutes: 10);

/// Пора ли снова вызывать генерацию.
bool pprGenerateDue(DateTime? last, DateTime now) =>
    last == null || now.difference(last) >= pprGenerateEvery;
