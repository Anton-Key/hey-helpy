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
/// Ширина, с которой у выбранного сегмента — «12 из 72» (уже — «12»).
const kSegmentOfFrom = 400.0;

/// Число у сегмента «Все / Открытые / Просрочено». У выбранного, когда
/// фильтры или поиск сужают список ([narrowed]), — «12 из 72» (на ширине
/// < [kSegmentOfFrom] — «12»). [total] — все заявки, тот же источник, что у
/// подписи для диктора «Найдено 12 из 72».
String segmentCountText(AppLocalizations l,
        {required int count,
        required int total,
        required bool selected,
        required bool narrowed,
        required double width}) =>
    selected && narrowed && width >= kSegmentOfFrom
        ? l.reqSegOf(count, total)
        : '$count';

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

  /// Короткая подпись сортировки (кнопка рядом с фильтрами на ПК).
  String sortShort(OrderSort s) => switch (s) {
        OrderSort.newest => l.sortShortNewest,
        OrderSort.oldest => l.sortShortOldest,
        OrderSort.due => l.sortShortDue,
        OrderSort.priority => l.sortShortPriority,
        OrderSort.status => l.sortShortStatus,
        OrderSort.object => l.sortShortObject,
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

  /// Название фильтра (строка окна «Фильтры», подпись для диктора).
  String title(FilterKey k) => switch (k) {
        FilterKey.period => l.filterPeriod,
        FilterKey.status => l.filterStatus,
        FilterKey.object => l.filterObject,
        FilterKey.room => l.filterRoom,
        FilterKey.contractor => l.filterContractor,
        FilterKey.layer => l.filterWorkType,
        FilterKey.priority => l.filterPriority,
        FilterKey.recurrence => l.filterType,
        FilterKey.channel => l.filterSource,
        FilterKey.photo => l.filterNeedsPhoto,
        FilterKey.returned => l.filterReturned,
        FilterKey.mine => l.filterCreatedByMe,
        FilterKey.toMe => l.filterAssignedToMe,
      };

  List<FilterOption> channelOptions() =>
      [for (final c in kChannels) FilterOption(c, channel(c))];

  /// Подпись выбранного значения фильтра [k] («Москва (5)», «Просрочено +1»,
  /// «30 дней»). null — фильтр не выбран.
  String? value(FilterKey k, OrderFilter f, FilterChoices c, DateTime now) =>
      switch (k) {
        FilterKey.period => period(f, now),
        FilterKey.status => multi(f.statuses, statusOptions()),
        FilterKey.object => objectsSelectionLabel(l, f.objectIds, c.objects),
        FilterKey.room => f.effectiveLocationIds.isEmpty
            ? null
            : multi(f.effectiveLocationIds, c.places),
        FilterKey.contractor =>
          multi(f.contractorIds, contractorOptions(c.contractors)),
        FilterKey.layer => multi(f.layerIds, c.layers),
        FilterKey.priority => multi(f.priorities, priorityOptions()),
        FilterKey.recurrence => switch (f.recurrence) {
            RecurrenceFilter.once => l.filterOnce,
            RecurrenceFilter.recurring => l.filterRecurring,
            null => null,
          },
        FilterKey.channel => multi(f.channels, channelOptions()),
        FilterKey.photo => f.needsPhoto ? l.filterNeedsPhoto : null,
        FilterKey.returned => f.returned ? l.filterReturned : null,
        FilterKey.mine => f.createdByMe ? l.filterCreatedByMe : null,
        FilterKey.toMe => f.assignedToMe ? l.filterAssignedToMe : null,
      };

  /// Таблетки строки применённых фильтров: (фильтр, подпись) по порядку
  /// [OrderFilter.activeKeys]; [skip] — те, что уже стоят таблетками
  /// рядом с поиском (широкий экран).
  List<(FilterKey, String)> applied(
          OrderFilter f, FilterChoices c, DateTime now,
          {Set<FilterKey> skip = const {}}) =>
      [
        for (final k in f.activeKeys)
          if (!skip.contains(k)) (k, value(k, f, c, now) ?? title(k)),
      ];

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
