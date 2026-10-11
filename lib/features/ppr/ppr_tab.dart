import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../home/home_chrome.dart';
import '../requests/order_filter_bar.dart' show kSegmentOfFrom;
import 'ppr_card.dart';
import 'ppr_form.dart';
import 'ppr_logic.dart';
import 'ppr_repository.dart';
import 'ppr_text.dart';
import 'ppr_view.dart';

/// Справочники раздела «ППР»: объекты, системы, подрядчики, закрепления, роль.
class PprData {
  const PprData({
    required this.plans,
    required this.tasks,
    required this.objects,
    required this.layers,
    required this.contractors,
    required this.bindings,
    required this.isManager,
    required this.companyId,
  });

  final List<MaintenancePlan> plans;
  final List<PlanTask> tasks;
  final List<Obj> objects;
  final List<Layer> layers;
  final List<Contractor> contractors;
  final List<Binding> bindings;
  final bool isManager;
  final String? companyId;

  static Future<PprData> load({PprRepository? repo}) async {
    final r = repo ?? PprRepository();
    final dir = DirectoryRepo();
    final since = DateTime.now().subtract(const Duration(days: 400));
    final res = await Future.wait<Object?>([
      r.plans(),
      r.tasks(since: since),
      dir.objects(),
      dir.layers().catchError((_) => const <Layer>[]),
      dir.contractors(),
      dir.allBindings().catchError((_) => const <Binding>[]),
      dir.amIManager(),
      dir.myCompanyId(),
    ]);
    return PprData(
      plans: res[0] as List<MaintenancePlan>,
      tasks: res[1] as List<PlanTask>,
      objects: res[2] as List<Obj>,
      layers: res[3] as List<Layer>,
      contractors: res[4] as List<Contractor>,
      bindings: res[5] as List<Binding>,
      isManager: res[6] as bool,
      companyId: res[7] as String?,
    );
  }

  List<PlanView> views([DateTime? now]) => buildPlanViews(
      plans: plans,
      tasks: tasks,
      objects: objects,
      layers: layers,
      contractors: contractors,
      bindings: bindings,
      now: now);
}

/// Подсказка ⓘ «ППР».
Future<void> showPprInfo(BuildContext context) {
  final l = context.l10n;
  return showAppInfo(
      context: context,
      title: l.pprInfoTitle,
      lines: [l.pprInfo1, l.pprInfo2, l.pprInfo3, l.pprInfo4],
      closeLabel: l.commonGotIt);
}

/// Вкладка «ППР»: сводка за месяц, фильтры, планы по состоянию текущего
/// периода (просрочено → не начато → в работе → выполнено → приостановлен).
class PprTab extends StatefulWidget {
  const PprTab({super.key});

  @override
  State<PprTab> createState() => _PprTabState();
}

class _PprTabState extends State<PprTab> {
  final _repo = PprRepository();
  PprData? _data;
  bool _loading = true;
  bool _failed = false;
  bool _missing = false;
  PprFilter _filter = const PprFilter();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool generate = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (generate && (_data?.isManager ?? false)) {
        final n = await _repo.generate();
        if (n > 0 && mounted) {
          showAppMessage(context, context.l10n.pprGenerated(n),
              type: AppMessageType.success);
        }
      }
      final d = await PprData.load(repo: _repo);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _missing = false;
      });
    } on MigrationMissing {
      if (mounted) {
        setState(() {
          _loading = false;
          _missing = true;
        });
      }
    } catch (e) {
      debugPrint('PprTab: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _openCard(PlanView v) async {
    final d = _data;
    if (d == null) return;
    await Navigator.push(
        context,
        appRoute((_) => PprPlanCardScreen(planId: v.plan.id, data: d),
            title: context.l10n.tabPpr));
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final d = _data;
    if (d == null) return;
    final saved = await Navigator.push<bool>(
        context,
        appRoute((_) => PprPlanFormScreen(data: d),
            title: context.l10n.tabPpr));
    if (saved == true && mounted) {
      showAppMessage(context, context.l10n.pprSaved,
          type: AppMessageType.success);
      await _load(generate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _data;
    return CustomScrollView(slivers: [
      HomeHeader(
        title: l.tabPpr,
        onRefresh: () => _load(generate: true),
        actions: [
          AppIconButton(
              icon: AppIcons.info,
              label: l.pprInfoTitle,
              onPressed: () => showPprInfo(context)),
          if (d?.isManager == true)
            AppIconButton(
                icon: AppIcons.add, label: l.commonAdd, onPressed: _create),
        ],
      ),
      ..._body(l),
      const SliverBottomInset(),
    ]);
  }

  List<Widget> _body(AppLocalizations l) {
    if (_missing) {
      return [
        SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
                icon: AppIcons.calendar, text: l.migrationNeeded('0015'))),
      ];
    }
    if (_loading && _data == null) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: AppLoader())
      ];
    }
    if (_failed && _data == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.pprLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load),
        ),
      ];
    }
    final d = _data!;
    final all = d.views();
    if (all.isEmpty) {
      return [
        SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(icon: AppIcons.calendar, text: l.pprEmpty)),
      ];
    }
    final list = [
      for (final v in all)
        if (_filter.matches(v)) v
    ];
    final sum = pprMonthSummary(list);
    final month = DateFormat('LLLL', l.localeName).format(DateTime.now());
    final monthCap =
        month.isEmpty ? month : month[0].toUpperCase() + month.substring(1);

    final groups = <PeriodState, List<PlanView>>{};
    for (final v in list) {
      groups.putIfAbsent(v.state, () => []).add(v);
    }
    final order = groups.keys.toList()
      ..sort((a, b) => periodStateOrder(a).compareTo(periodStateOrder(b)));

    return [
      SliverContent(
        top: AppSpace.s,
        sliver: SliverList.list(children: [
          _filterRow(l, d, all),
          const SizedBox(height: AppSpace.s),
          AppCard(
            child: Row(children: [
              const LeadingIcon(AppIcons.checklist),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Text(l.pprSummary(monthCap, sum.done, sum.total),
                    style: AppText.headline),
              ),
            ]),
          ),
          const SizedBox(height: AppSpace.group),
          if (list.isEmpty)
            AppEmptyState(icon: AppIcons.search, text: l.pprEmptyFiltered),
          for (final s in order)
            AppGroup(
              header: '${pprStateLabel(l, s)} · ${groups[s]!.length}',
              children: [for (final v in groups[s]!) _row(l, v)],
            ),
        ]),
      ),
    ];
  }

  Widget _row(AppLocalizations l, PlanView v) {
    final narrow = MediaQuery.sizeOf(context).width < kSegmentOfFrom;
    final layer = v.layer?.label(l.localeName);
    final period = pprPeriodText(l, v.plan.kind, v.period);
    return AppRow(
      leading: const LeadingIcon(AppIcons.calendar),
      title: v.plan.title,
      subtitle: [
        [v.objectLabel, if (layer != null) layer].join(' · '),
        [
          pprEvery(l, v.plan.kind, v.plan.days),
          period,
          v.contractor?.orgName ?? l.filterNoContractor,
        ].join(' · '),
      ].join('\n'),
      subtitleMaxLines: 3,
      // Узкий телефон: статус — под названием, название во всю ширину
      // (как в списке заявок).
      extra: narrow
          ? Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpace.xxs),
              child: StatusPill(periodStateStatus(v.state),
                  label: pprStateLabel(l, v.state)),
            )
          : null,
      trailing: narrow
          ? null
          : StatusPill(periodStateStatus(v.state),
              label: pprStateLabel(l, v.state)),
      onTap: () => _openCard(v),
    );
  }

  Widget _filterRow(AppLocalizations l, PprData d, List<PlanView> all) {
    final n = _filter.activeCount;
    final tags = <Widget>[
      for (final id in _filter.objects)
        _tag(
            l,
            _objectName(d, id),
            () => _setFilter(
                _filter.copyWith(objects: {..._filter.objects}..remove(id)))),
      for (final id in _filter.layers)
        _tag(
            l,
            _layerName(l, d, id),
            () => _setFilter(
                _filter.copyWith(layers: {..._filter.layers}..remove(id)))),
      for (final id in _filter.contractors)
        _tag(
            l,
            _contractorName(l, d, id),
            () => _setFilter(_filter.copyWith(
                contractors: {..._filter.contractors}..remove(id)))),
      for (final s in _filter.states)
        _tag(
            l,
            pprStateLabel(l, s),
            () => _setFilter(
                _filter.copyWith(states: {..._filter.states}..remove(s)))),
    ];
    return Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppFilterChip(
          label: n == 0 ? l.pprFilters : l.pprFiltersCount(n),
          icon: AppIcons.filter,
          chevron: false,
          strong: n > 0,
          onTap: () => _openFilters(d, all),
        ),
        ...tags,
        if (n > 1)
          AppButton.plain(
              label: l.filterResetAll,
              small: true,
              expand: false,
              onPressed: () => _setFilter(const PprFilter())),
      ],
    );
  }

  Widget _tag(AppLocalizations l, String label, VoidCallback onClear) =>
      FilterTag(label: label, onClear: onClear, clearLabel: l.filterReset);

  void _setFilter(PprFilter f) => setState(() => _filter = f);

  String _objectName(PprData d, String id) {
    for (final o in d.objects) {
      if (o.id == id) return objectDisplayName(o);
    }
    return '—';
  }

  String _layerName(AppLocalizations l, PprData d, String id) {
    for (final y in d.layers) {
      if (y.id == id) return y.label(l.localeName);
    }
    return '—';
  }

  String _contractorName(AppLocalizations l, PprData d, String id) {
    if (id.isEmpty) return l.filterNoContractor;
    for (final c in d.contractors) {
      if (c.id == id) return c.orgName;
    }
    return '—';
  }

  Future<void> _openFilters(PprData d, List<PlanView> all) async {
    final l = context.l10n;
    final objectIds = <String>{for (final v in all) v.plan.objectId};
    final objects = [
      for (final o in d.objects)
        if (objectIds.contains(o.id)) o
    ]..sort((a, b) => objectDisplayName(a)
        .toLowerCase()
        .compareTo(objectDisplayName(b).toLowerCase()));
    final layerIds = <String>{for (final v in all) v.plan.layerId};
    final layers = [
      for (final y in d.layers)
        if (layerIds.contains(y.id)) y
    ];
    final contractorIds = <String>{for (final v in all) v.contractor?.id ?? ''};
    final contractors = [
      for (final c in d.contractors)
        if (contractorIds.contains(c.id)) c
    ]..sort(
        (a, b) => a.orgName.toLowerCase().compareTo(b.orgName.toLowerCase()));

    var f = _filter;
    Set<T> toggle<T>(Set<T> s, T v) =>
        s.contains(v) ? ({...s}..remove(v)) : {...s, v};

    final result = await showAppSidePanel<PprFilter>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final count = [
          for (final v in all)
            if (f.matches(v)) v
        ].length;
        return AppFilterPanel(
          title: l.pprFilters,
          resetLabel: l.filterReset,
          applyLabel: l.pprFiltersShow(count),
          onReset: f.isEmpty ? null : () => setSt(() => f = const PprFilter()),
          onApply: () => Navigator.pop(ctx, f),
          children: [
            AppPanelGroup(header: l.pprFilterState, children: [
              for (final s in PeriodState.values)
                AppCheckRow(
                  title: pprStateLabel(l, s),
                  selected: f.states.contains(s),
                  onTap: () =>
                      setSt(() => f = f.copyWith(states: toggle(f.states, s))),
                  child: StatusPill(periodStateStatus(s),
                      label: pprStateLabel(l, s)),
                ),
            ]),
            AppPanelGroup(header: l.pprFilterObject, children: [
              for (final o in objects)
                AppCheckRow(
                  title: objectDisplayName(o),
                  selected: f.objects.contains(o.id),
                  onTap: () => setSt(
                      () => f = f.copyWith(objects: toggle(f.objects, o.id))),
                ),
            ]),
            AppPanelGroup(header: l.pprFilterSystem, children: [
              for (final y in layers)
                AppCheckRow(
                  title: y.label(l.localeName),
                  selected: f.layers.contains(y.id),
                  onTap: () => setSt(
                      () => f = f.copyWith(layers: toggle(f.layers, y.id))),
                ),
            ]),
            AppPanelGroup(header: l.pprFilterContractor, children: [
              for (final c in contractors)
                AppCheckRow(
                  title: c.orgName,
                  selected: f.contractors.contains(c.id),
                  onTap: () => setSt(() =>
                      f = f.copyWith(contractors: toggle(f.contractors, c.id))),
                ),
              if (contractorIds.contains(''))
                AppCheckRow(
                  title: l.filterNoContractor,
                  selected: f.contractors.contains(''),
                  onTap: () => setSt(() =>
                      f = f.copyWith(contractors: toggle(f.contractors, ''))),
                ),
            ]),
          ],
        );
      }),
    );
    if (result != null && mounted) _setFilter(result);
  }
}
