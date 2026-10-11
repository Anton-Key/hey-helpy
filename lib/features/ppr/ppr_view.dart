import '../directory/city.dart';
import '../directory/directory.dart';
import 'ppr_logic.dart';
import 'ppr_repository.dart';

/// План ППР вместе со справочниками для строки списка и карточки.
class PlanView {
  const PlanView({
    required this.plan,
    required this.period,
    required this.state,
    this.object,
    this.layer,
    this.contractor,
    this.current,
  });

  final MaintenancePlan plan;
  final Obj? object;
  final Layer? layer;

  /// Подрядчик по системе и объекту (закрепление на объект важнее
  /// закрепления «на все объекты») — тот же, кого назначит база.
  final Contractor? contractor;

  /// Текущий период и задача этого периода (если уже создана).
  final PeriodBounds period;
  final PlanTask? current;
  final PeriodState state;

  String get objectLabel =>
      object == null ? '' : objectDisplayName(object!, withCity: true);
}

/// Подрядчик плана по закреплениям: сначала на этот объект, потом «на все».
Contractor? planContractor(
    MaintenancePlan p, List<Binding> bindings, List<Contractor> contractors) {
  Binding? pick;
  for (final b in bindings) {
    if (b.layer?.id != p.layerId) continue;
    if (b.objectId == p.objectId) {
      pick = b;
      break;
    }
    if (b.objectId == null) pick ??= b;
  }
  if (pick == null) return null;
  for (final c in contractors) {
    if (c.id == pick.contractorId) return c;
  }
  return null;
}

/// Планы, которые видит исполнитель: его подрядчик по закреплениям или
/// у плана есть задача, видимая ему (база показывает только заявки своего
/// подрядчика). Иначе в «ППР» исполнителя были бы чужие планы со
/// статусом «Не начато» и неверной сводкой.
List<MaintenancePlan> plansOfExecutor({
  required List<MaintenancePlan> plans,
  required List<PlanTask> tasks,
  required List<Binding> bindings,
  required List<Contractor> contractors,
  required Set<String> myContractorIds,
}) {
  final withTasks = {for (final t in tasks) t.planId};
  return [
    for (final p in plans)
      if (withTasks.contains(p.id) ||
          myContractorIds
              .contains(planContractor(p, bindings, contractors)?.id))
        p
  ];
}

/// Собрать строки списка: текущий период, его задача и состояние.
List<PlanView> buildPlanViews({
  required List<MaintenancePlan> plans,
  required List<PlanTask> tasks,
  required List<Obj> objects,
  required List<Layer> layers,
  required List<Contractor> contractors,
  required List<Binding> bindings,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final byPlanPeriod = <String, PlanTask>{};
  for (final k in tasks) {
    byPlanPeriod['${k.planId}|${k.period.start}'] = k;
  }
  final out = <PlanView>[];
  for (final p in plans) {
    final period = p.currentPeriod(t);
    final cur = byPlanPeriod['${p.id}|${period.start}'];
    Obj? obj;
    for (final o in objects) {
      if (o.id == p.objectId) obj = o;
    }
    Layer? layer;
    for (final y in layers) {
      if (y.id == p.layerId) layer = y;
    }
    out.add(PlanView(
      plan: p,
      object: obj,
      layer: layer,
      contractor: planContractor(p, bindings, contractors),
      period: period,
      current: cur,
      state: periodState(
          active: p.active, task: cur?.status, period: period, now: t),
    ));
  }
  out.sort((a, b) {
    final s = periodStateOrder(a.state).compareTo(periodStateOrder(b.state));
    if (s != 0) return s;
    final o =
        a.objectLabel.toLowerCase().compareTo(b.objectLabel.toLowerCase());
    if (o != 0) return o;
    return a.plan.title.toLowerCase().compareTo(b.plan.title.toLowerCase());
  });
  return out;
}

/// Фильтр списка планов: объекты, системы, подрядчики, состояния периода.
/// Пустое множество — без ограничения.
class PprFilter {
  const PprFilter({
    this.objects = const {},
    this.layers = const {},
    this.contractors = const {},
    this.states = const {},
  });

  final Set<String> objects;
  final Set<String> layers;

  /// id подрядчиков; '' — «без подрядчика».
  final Set<String> contractors;
  final Set<PeriodState> states;

  int get activeCount =>
      (objects.isEmpty ? 0 : 1) +
      (layers.isEmpty ? 0 : 1) +
      (contractors.isEmpty ? 0 : 1) +
      (states.isEmpty ? 0 : 1);

  bool get isEmpty => activeCount == 0;

  bool matches(PlanView v) {
    if (objects.isNotEmpty && !objects.contains(v.plan.objectId)) return false;
    if (layers.isNotEmpty && !layers.contains(v.plan.layerId)) return false;
    if (contractors.isNotEmpty &&
        !contractors.contains(v.contractor?.id ?? '')) {
      return false;
    }
    if (states.isNotEmpty && !states.contains(v.state)) return false;
    return true;
  }

  PprFilter copyWith({
    Set<String>? objects,
    Set<String>? layers,
    Set<String>? contractors,
    Set<PeriodState>? states,
  }) =>
      PprFilter(
        objects: objects ?? this.objects,
        layers: layers ?? this.layers,
        contractors: contractors ?? this.contractors,
        states: states ?? this.states,
      );
}

/// Сводка над списком — по текущему месяцу: планы с периодом «месяц» и
/// остальные, чей текущий период включает сегодняшний день.
({int done, int total}) pprMonthSummary(List<PlanView> views) => monthSummary(
    [for (final v in views) (active: v.plan.active, state: v.state)]);
