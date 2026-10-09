import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../directory/object_picker.dart';
import 'order_filter.dart';

/// Пункт списка в окне фильтра.
class FilterOption {
  const FilterOption(this.id, this.label, {this.leading, this.child});
  final String id;
  final String label;
  final Widget? leading;

  /// Вместо текста (например капсула статуса).
  final Widget? child;
}

/// Варианты для окон фильтра: только то, что пользователь и так видит (RLS).
class FilterChoices {
  const FilterChoices({
    required this.objects,
    required this.contractors,
    required this.layers,
    required this.isExecutor,
    this.places = const [],
  });

  /// Объекты (в окне — по городам) и подрядчики — как в справочниках.
  final List<Obj> objects;
  final List<FilterOption> contractors;
  final List<FilterOption> layers;

  /// Помещения выбранного объекта (если выбран ровно один).
  final List<FilterOption> places;

  /// Исполнитель: показывать «Назначено мне».
  final bool isExecutor;
}

// ---------------------------------------------------------------------
// Подписи активных таблеток
// ---------------------------------------------------------------------

/// Подписи фильтра на языке интерфейса — чистые функции (тесты).
class OrderFilterLabels {
  const OrderFilterLabels(this.l);
  final AppLocalizations l;

  String periodPreset(PeriodPreset p) => switch (p) {
        PeriodPreset.today => l.filterPeriodToday,
        PeriodPreset.days7 => l.filterPeriod7,
        PeriodPreset.days30 => l.filterPeriod30,
        PeriodPreset.thisMonth => l.filterPeriodThisMonth,
        PeriodPreset.lastMonth => l.filterPeriodLastMonth,
        PeriodPreset.custom => l.filterPeriodCustom,
      };

  String sort(OrderSort s) => switch (s) {
        OrderSort.newest => l.sortNewest,
        OrderSort.oldest => l.sortOldest,
        OrderSort.due => l.sortDue,
        OrderSort.priority => l.sortPriority,
        OrderSort.status => l.sortStatus,
        OrderSort.object => l.sortObject,
      };

  String channel(String c) => switch (c) {
        'voice' => l.filterChannelVoice,
        'text' => l.filterChannelText,
        _ => l.filterChannelButton,
      };

  /// «1 окт. – 9 окт.» (год — если не текущий).
  String range(DateTime from, DateTime to, DateTime now) {
    final sameYear = from.year == now.year && to.year == now.year;
    final f = sameYear
        ? DateFormat.MMMd(l.localeName)
        : DateFormat.yMMMd(l.localeName);
    return l.filterRange(f.format(from), f.format(to));
  }

  String? period(OrderFilter f, DateTime now) {
    if (!f.hasPeriod) return null;
    final base = f.period == PeriodPreset.custom
        ? range(f.customFrom!, f.customTo!, now)
        : periodPreset(f.period!);
    return f.dateField == DateField.due ? l.filterDueLabel(base) : base;
  }

  /// Первый выбранный (в порядке [options]) и «+N».
  String? multi(Set<String> ids, List<FilterOption> options) {
    if (ids.isEmpty) return null;
    String? first;
    for (final o in options) {
      if (ids.contains(o.id)) {
        first = o.label;
        break;
      }
    }
    first ??= '…';
    return ids.length == 1 ? first : l.filterPlus(first, ids.length - 1);
  }

  /// Подписи выбранных пунктов «Ещё» по порядку.
  List<String> moreItems(OrderFilter f) => [
        if (f.recurrence == RecurrenceFilter.once) l.filterOnce,
        if (f.recurrence == RecurrenceFilter.recurring) l.filterRecurring,
        for (final c in kChannels)
          if (f.channels.contains(c)) channel(c),
        if (f.needsPhoto) l.filterNeedsPhoto,
        if (f.returned) l.filterReturned,
        if (f.createdByMe) l.filterCreatedByMe,
        if (f.assignedToMe) l.filterAssignedToMe,
      ];

  String? more(OrderFilter f) {
    final items = moreItems(f);
    if (items.isEmpty) return null;
    return items.length == 1 ? items.single : l.filterMoreCount(items.length);
  }

  List<FilterOption> priorityOptions() => [
        for (final p in kPriorityOrder)
          FilterOption(p, l.priority(p), leading: PriorityDot(p)),
      ];

  List<FilterOption> statusOptions() => [
        for (final s in kStatusOrder)
          FilterOption(s, s == kOverdue ? l.filterOverdue : l.status(s),
              child:
                  StatusPill(s, label: s == kOverdue ? l.filterOverdue : null)),
      ];

  List<FilterOption> contractorOptions(List<FilterOption> contractors) => [
        ...contractors,
        FilterOption(kNoContractor, l.filterNoContractor),
      ];
}

// ---------------------------------------------------------------------
// Строка фильтров
// ---------------------------------------------------------------------

/// Строка «таблеток» над списком заявок: горизонтальная прокрутка, справа —
/// сортировка. Каждая таблетка открывает окно выбора ([showFilterPicker]).
class OrderFilterBar extends StatelessWidget {
  const OrderFilterBar({
    super.key,
    required this.filter,
    required this.choices,
    required this.onChanged,
    this.loadPlaces,
  });

  final OrderFilter filter;
  final FilterChoices choices;
  final ValueChanged<OrderFilter> onChanged;

  /// Помещения выбранного объекта — загружаются при открытии окна.
  final Future<List<FilterOption>> Function(String objectId)? loadPlaces;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lb = OrderFilterLabels(l);
    final now = DateTime.now();
    final f = filter;

    Widget chip(
        {required String label,
        required String? active,
        required Future<OrderFilter?> Function(BuildContext anchor) open,
        required OrderFilter Function() clear}) {
      return _ChipSlot(
          active: active != null,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpace.s),
            child: Builder(
              builder: (anchor) => AppFilterChip(
                label: label,
                activeLabel: active,
                clearLabel: l.filterClearOne(label),
                onTap: () async {
                  final r = await open(anchor);
                  if (r != null) onChanged(r);
                },
                onClear: () => onChanged(clear()),
              ),
            ),
          ));
    }

    Future<Set<String>?> pickMulti(BuildContext anchor, String title,
        List<FilterOption> options, Set<String> selected,
        {bool searchable = true}) {
      return showFilterPicker<Set<String>>(
        context: anchor,
        builder: (_) => MultiSelectPanel(
            title: title,
            options: options,
            selected: selected,
            searchable: searchable),
      );
    }

    final contractors = lb.contractorOptions(choices.contractors);
    final chips = <Widget>[
      chip(
        label: l.filterPeriod,
        active: lb.period(f, now),
        open: (a) => showFilterPicker<OrderFilter>(
            context: a, builder: (_) => PeriodPanel(filter: f)),
        clear: () =>
            f.copyWith(clearPeriod: true, dateField: DateField.created),
      ),
      chip(
        label: l.filterObject,
        active: objectsSelectionLabel(l, f.objectIds, choices.objects),
        open: (a) async {
          final r = await showFilterPicker<Set<String>>(
            context: a,
            builder: (_) => ObjectPickerPanel(
                title: l.filterObject,
                objects: choices.objects,
                selected: f.objectIds),
          );
          return r == null ? null : f.copyWith(objectIds: r);
        },
        clear: () => f.copyWith(objectIds: const {}),
      ),
      if (f.objectIds.length == 1)
        chip(
          label: l.filterRoom,
          active: f.effectiveLocationIds.isEmpty
              ? null
              : lb.multi(f.effectiveLocationIds, choices.places),
          open: (a) async {
            final places = loadPlaces == null
                ? choices.places
                : await loadPlaces!(f.objectIds.single);
            if (!a.mounted) return null;
            final r = await pickMulti(a, l.filterRoom, places, f.locationIds);
            return r == null ? null : f.copyWith(locationIds: r);
          },
          clear: () => f.copyWith(locationIds: const {}),
        ),
      chip(
        label: l.filterContractor,
        active: lb.multi(f.contractorIds, contractors),
        open: (a) async {
          final r = await pickMulti(
              a, l.filterContractor, contractors, f.contractorIds);
          return r == null ? null : f.copyWith(contractorIds: r);
        },
        clear: () => f.copyWith(contractorIds: const {}),
      ),
      chip(
        label: l.filterPriority,
        active: lb.multi(f.priorities, lb.priorityOptions()),
        open: (a) async {
          final r = await pickMulti(
              a, l.filterPriority, lb.priorityOptions(), f.priorities);
          return r == null ? null : f.copyWith(priorities: r);
        },
        clear: () => f.copyWith(priorities: const {}),
      ),
      chip(
        label: l.filterStatus,
        active: lb.multi(f.statuses, lb.statusOptions()),
        open: (a) async {
          final r = await pickMulti(
              a, l.filterStatus, lb.statusOptions(), f.statuses,
              searchable: false);
          return r == null ? null : f.copyWith(statuses: r);
        },
        clear: () => f.copyWith(statuses: const {}),
      ),
      chip(
        label: l.filterWorkType,
        active: lb.multi(f.layerIds, choices.layers),
        open: (a) async {
          final r =
              await pickMulti(a, l.filterWorkType, choices.layers, f.layerIds);
          return r == null ? null : f.copyWith(layerIds: r);
        },
        clear: () => f.copyWith(layerIds: const {}),
      ),
      chip(
        label: l.filterMore,
        active: lb.more(f),
        open: (a) => showFilterPicker<OrderFilter>(
            context: a,
            builder: (_) =>
                MorePanel(filter: f, isExecutor: choices.isExecutor)),
        clear: () => f.copyWith(
            clearRecurrence: true,
            channels: const {},
            needsPhoto: false,
            returned: false,
            createdByMe: false,
            assignedToMe: false),
      ),
      if (f.hasFilters)
        Pressable(
          onTap: () => onChanged(f.cleared().copyWith(segment: f.segment)),
          child: SizedBox(
            height: AppSizes.filterChip,
            child: Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                child: Text(l.filterResetAll,
                    style: AppText.footnote.copyWith(
                        fontSize: 14,
                        color: AppColors.accentText,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
    ];

    return Row(children: [
      Expanded(
        // Сортировка — отдельно справа, а строка таблеток прокручивается
        // и плавно гаснет у края: видно, что за ним есть ещё фильтры.
        child: AppFadingScroll(
          // Выбранные фильтры — первыми: на телефоне их видно без прокрутки.
          child: Row(children: [
            for (final c in chips)
              if (c is _ChipSlot && c.active) c,
            for (final c in chips)
              if (c is! _ChipSlot || !c.active) c,
          ]),
        ),
      ),
      const SizedBox(width: AppSpace.m),
      Builder(
        builder: (anchor) => AppFilterChip(
          icon: AppIcons.sort,
          label: lb.sort(f.sort),
          // На телефоне — только значок: строке фильтров нужно место.
          compact: MediaQuery.sizeOf(context).width < 600,
          onTap: () async {
            final r = await showFilterPicker<OrderSort>(
                context: anchor, builder: (_) => SortPanel(sort: f.sort));
            if (r != null) onChanged(f.copyWith(sort: r));
          },
        ),
      ),
    ]);
  }
}

/// Таблетка в строке и признак «выбрана» (для порядка).
class _ChipSlot extends StatelessWidget {
  const _ChipSlot({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

// ---------------------------------------------------------------------
// Окна выбора
// ---------------------------------------------------------------------

/// Множественный выбор с галочками; поиск — если пунктов больше 7.
/// Возвращает выбранные id (Navigator.pop) или null (закрыли).
class MultiSelectPanel extends StatefulWidget {
  const MultiSelectPanel(
      {super.key,
      required this.title,
      required this.options,
      required this.selected,
      this.searchable = true});
  final String title;
  final List<FilterOption> options;
  final Set<String> selected;

  /// Поиск — если пунктов больше 7 и список не постоянный (статусы — нет).
  final bool searchable;

  @override
  State<MultiSelectPanel> createState() => _MultiSelectPanelState();
}

class _MultiSelectPanelState extends State<MultiSelectPanel> {
  late final Set<String> _sel = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty || o.label.toLowerCase().contains(q)) o
    ];
    return AppFilterPanel(
      title: widget.title,
      searchHint: l.filterSearchHint,
      onSearch: widget.searchable && widget.options.length > 7
          ? (v) => setState(() => _q = v)
          : null,
      resetLabel: l.filterReset,
      onReset: _sel.isEmpty ? null : () => setState(_sel.clear),
      applyLabel:
          _sel.isEmpty ? l.filterApply : l.filterApplyCount(_sel.length),
      onApply: () => Navigator.pop(context, {..._sel}),
      children: [
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(l.reqNothingFound,
                textAlign: TextAlign.center, style: AppText.footnote),
          )
        else
          AppPanelGroup(children: [
            for (final o in shown)
              AppCheckRow(
                title: o.label,
                leading: o.leading,
                selected: _sel.contains(o.id),
                onTap: () => setState(() =>
                    _sel.contains(o.id) ? _sel.remove(o.id) : _sel.add(o.id)),
                child: o.child,
              ),
          ]),
      ],
    );
  }
}

/// Период: «по дате создания / по сроку», пресеты и «Свой период…».
class PeriodPanel extends StatefulWidget {
  const PeriodPanel({super.key, required this.filter});
  final OrderFilter filter;

  @override
  State<PeriodPanel> createState() => _PeriodPanelState();
}

class _PeriodPanelState extends State<PeriodPanel> {
  late OrderFilter _f = widget.filter;

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = _f.range(now) ??
        const OrderFilter(period: PeriodPreset.days30).range(now)!;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
          start: r.from, end: r.to.subtract(const Duration(days: 1))),
      helpText: context.l10n.filterPickDates,
      // На широком экране — карточкой по центру, а не на весь экран.
      builder: (ctx, child) => MediaQuery.sizeOf(ctx).width < AppSpace.wideFrom
          ? child!
          : Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420, maxHeight: 640),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.group),
                    child: child),
              ),
            ),
    );
    if (picked == null || !mounted) return;
    setState(() => _f = _f.copyWith(
        period: PeriodPreset.custom,
        customFrom: picked.start,
        customTo: picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lb = OrderFilterLabels(l);
    final now = DateTime.now();
    return AppFilterPanel(
      title: l.filterPeriod,
      header: SegmentedControl<DateField>(
        segments: [
          Segment(DateField.created, l.filterByCreated),
          Segment(DateField.due, l.filterByDue),
        ],
        selected: _f.dateField,
        onChanged: (d) => setState(() => _f = _f.copyWith(dateField: d)),
      ),
      resetLabel: l.filterReset,
      onReset: _f.period == null
          ? null
          : () => setState(() => _f = _f.copyWith(clearPeriod: true)),
      applyLabel: _f.hasPeriod ? l.filterApplyCount(1) : l.filterApply,
      onApply: () => Navigator.pop(
          context,
          // «Свой период» без дат — как «без периода».
          _f.hasPeriod ? _f : _f.copyWith(clearPeriod: true)),
      children: [
        AppPanelGroup(children: [
          for (final p
              in PeriodPreset.values.where((p) => p != PeriodPreset.custom))
            AppCheckRow(
              title: lb.periodPreset(p),
              selected: _f.period == p,
              onTap: () => setState(() => _f = _f.period == p
                  ? _f.copyWith(clearPeriod: true)
                  : _f.copyWith(period: p)),
            ),
          AppCheckRow(
            title: l.filterPeriodCustom,
            subtitle: _f.period == PeriodPreset.custom && _f.hasPeriod
                ? lb.range(_f.customFrom!, _f.customTo!, now)
                : null,
            leading: const Icon(AppIcons.calendar,
                size: AppSizes.iconS, color: AppColors.accentText),
            selected: _f.period == PeriodPreset.custom && _f.hasPeriod,
            onTap: _pickCustom,
          ),
        ]),
      ],
    );
  }
}

/// «Ещё»: тип, источник и отметки.
class MorePanel extends StatefulWidget {
  const MorePanel({super.key, required this.filter, required this.isExecutor});
  final OrderFilter filter;
  final bool isExecutor;

  @override
  State<MorePanel> createState() => _MorePanelState();
}

class _MorePanelState extends State<MorePanel> {
  late OrderFilter _f = widget.filter;

  void _set(OrderFilter f) => setState(() => _f = f);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lb = OrderFilterLabels(l);
    final count = _f.moreCount;
    AppCheckRow rec(RecurrenceFilter r, String title) => AppCheckRow(
          title: title,
          selected: _f.recurrence == r,
          onTap: () => _set(_f.recurrence == r
              ? _f.copyWith(clearRecurrence: true)
              : _f.copyWith(recurrence: r)),
        );
    return AppFilterPanel(
      title: l.filterMore,
      resetLabel: l.filterReset,
      onReset: count == 0
          ? null
          : () => _set(_f.copyWith(
              clearRecurrence: true,
              channels: const {},
              needsPhoto: false,
              returned: false,
              createdByMe: false,
              assignedToMe: false)),
      applyLabel: count == 0 ? l.filterApply : l.filterApplyCount(count),
      onApply: () => Navigator.pop(context, _f),
      children: [
        AppPanelGroup(header: l.filterType, children: [
          rec(RecurrenceFilter.once, l.filterOnce),
          rec(RecurrenceFilter.recurring, l.filterRecurring),
        ]),
        AppPanelGroup(header: l.filterSource, children: [
          for (final c in kChannels)
            AppCheckRow(
              title: lb.channel(c),
              selected: _f.channels.contains(c),
              onTap: () => _set(_f.copyWith(
                  channels: _f.channels.contains(c)
                      ? ({..._f.channels}..remove(c))
                      : {..._f.channels, c})),
            ),
        ]),
        AppPanelGroup(header: l.filterOptions, children: [
          AppCheckRow(
              title: l.filterNeedsPhoto,
              selected: _f.needsPhoto,
              onTap: () => _set(_f.copyWith(needsPhoto: !_f.needsPhoto))),
          AppCheckRow(
              title: l.filterReturned,
              selected: _f.returned,
              onTap: () => _set(_f.copyWith(returned: !_f.returned))),
          AppCheckRow(
              title: l.filterCreatedByMe,
              selected: _f.createdByMe,
              onTap: () => _set(_f.copyWith(createdByMe: !_f.createdByMe))),
          if (widget.isExecutor || _f.assignedToMe)
            AppCheckRow(
                title: l.filterAssignedToMe,
                selected: _f.assignedToMe,
                onTap: () => _set(_f.copyWith(assignedToMe: !_f.assignedToMe))),
        ]),
      ],
    );
  }
}

/// Сортировка: выбор сразу применяется и закрывает окно.
class SortPanel extends StatelessWidget {
  const SortPanel({super.key, required this.sort});
  final OrderSort sort;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lb = OrderFilterLabels(l);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, 10, AppSpace.screen, 10),
          child: Semantics(
            header: true,
            child: Text(l.filterSort,
                textAlign: TextAlign.center, style: AppText.headline),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, 0, AppSpace.screen, AppSpace.screen),
            child: SafeArea(
              top: false,
              child: AppPanelGroup(children: [
                for (final s in OrderSort.values)
                  AppCheckRow(
                    title: lb.sort(s),
                    selected: s == sort,
                    onTap: () => Navigator.pop(context, s),
                  ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
