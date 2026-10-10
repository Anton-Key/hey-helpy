import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/object_picker.dart';
import 'order_filter.dart';
import 'order_filter_bar.dart';

/// Помещения выбранного объекта — загружаются при открытии окна.
typedef PlacesLoader = Future<List<FilterOption>> Function(String objectId);

/// Сколько заявок подойдёт под фильтр (запрос только количества).
typedef OrderCounter = Future<int> Function(OrderFilter f);

/// У фильтра есть своё окно выбора (остальные — строки окна «Фильтры»).
bool hasOwnPicker(FilterKey k) => switch (k) {
      FilterKey.recurrence ||
      FilterKey.photo ||
      FilterKey.returned ||
      FilterKey.mine ||
      FilterKey.toMe =>
        false,
      _ => true,
    };

/// Открывает окно выбора одного фильтра [k] под [anchor] (на телефоне —
/// шторка). Возвращает новый фильтр или null (закрыли / у фильтра нет окна).
Future<OrderFilter?> pickFilter(
    BuildContext anchor, FilterKey k, OrderFilter f, FilterChoices choices,
    {PlacesLoader? loadPlaces}) async {
  final l = anchor.l10n;
  final lb = OrderFilterLabels(l);

  Future<Set<String>?> multi(List<FilterOption> options, Set<String> selected,
          {bool searchable = true}) =>
      showFilterPicker<Set<String>>(
        context: anchor,
        builder: (_) => MultiSelectPanel(
            title: lb.title(k),
            options: options,
            selected: selected,
            searchable: searchable),
      );

  switch (k) {
    case FilterKey.period:
      return showFilterPicker<OrderFilter>(
          context: anchor, builder: (_) => PeriodPanel(filter: f));
    case FilterKey.status:
      final r = await multi(lb.statusOptions(), f.statuses, searchable: false);
      return r == null ? null : f.copyWith(statuses: r);
    case FilterKey.object:
      final r = await showFilterPicker<Set<String>>(
        context: anchor,
        builder: (_) => ObjectPickerPanel(
            title: l.filterObject,
            objects: choices.objects,
            selected: f.objectIds),
      );
      return r == null ? null : f.copyWith(objectIds: r);
    case FilterKey.room:
      if (f.objectIds.length != 1) return null;
      final places = loadPlaces == null
          ? choices.places
          : await loadPlaces(f.objectIds.single);
      if (!anchor.mounted) return null;
      final r = await multi(places, f.locationIds);
      return r == null ? null : f.copyWith(locationIds: r);
    case FilterKey.contractor:
      final r = await multi(
          lb.contractorOptions(choices.contractors), f.contractorIds);
      return r == null ? null : f.copyWith(contractorIds: r);
    case FilterKey.layer:
      final r = await multi(choices.layers, f.layerIds);
      return r == null ? null : f.copyWith(layerIds: r);
    case FilterKey.priority:
      final r =
          await multi(lb.priorityOptions(), f.priorities, searchable: false);
      return r == null ? null : f.copyWith(priorities: r);
    case FilterKey.channel:
      final r = await multi(lb.channelOptions(), f.channels, searchable: false);
      return r == null ? null : f.copyWith(channels: r);
    case FilterKey.recurrence:
    case FilterKey.photo:
    case FilterKey.returned:
    case FilterKey.mine:
    case FilterKey.toMe:
      return null;
  }
}

/// Открывает окно «Фильтры» (телефон — шторка на весь экран, ПК — панель
/// справа). Возвращает новый фильтр («Показать N») или null.
Future<OrderFilter?> showOrderFilters(BuildContext context,
        {required OrderFilter filter,
        required FilterChoices choices,
        required OrderCounter count,
        PlacesLoader? loadPlaces}) =>
    showAppSidePanel<OrderFilter>(
      context: context,
      builder: (_) => OrderFiltersPanel(
          filter: filter,
          choices: choices,
          count: count,
          loadPlaces: loadPlaces),
    );

// ---------------------------------------------------------------------
// Строка управления
// ---------------------------------------------------------------------

/// Одна строка над списком заявок: поиск, «Фильтры · N» и сортировка.
/// На широком экране (≥ [AppSpace.wideFrom]) вместо одной кнопки —
/// таблетки главных фильтров ([kMainFilterKeys]) и «Все фильтры · N»,
/// у сортировки — подпись.
class OrderControlBar extends StatelessWidget {
  const OrderControlBar({
    super.key,
    required this.filter,
    required this.choices,
    required this.search,
    required this.onSearch,
    required this.onChanged,
    required this.onOpenAll,
    this.loadPlaces,
    this.searchFocus,
  });

  /// Фокус поиска снаружи (горячая клавиша «/»).
  final FocusNode? searchFocus;

  final OrderFilter filter;
  final FilterChoices choices;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final ValueChanged<OrderFilter> onChanged;
  final VoidCallback onOpenAll;
  final PlacesLoader? loadPlaces;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lb = OrderFilterLabels(l);
    final f = filter;
    final wide = MediaQuery.sizeOf(context).width >= AppSpace.wideFrom;
    final n = f.activeCount;
    final now = DateTime.now();

    // На узком телефоне — короткая подсказка «Поиск».
    final searchField = AppSearchField(
        controller: search,
        focusNode: searchFocus,
        hint: MediaQuery.sizeOf(context).width < kSegmentOfFrom
            ? l.reqSearchShort
            : l.reqSearchHint,
        onChanged: onSearch);

    Widget allButton(String label, String countLabel) => AppFilterChip(
          icon: AppIcons.filter,
          label: label,
          activeLabel: n > 0 ? countLabel : null,
          strong: n > 0,
          chevron: false,
          onTap: onOpenAll,
        );

    final sort = Builder(
      builder: (anchor) => AppFilterChip(
        icon: AppIcons.sort,
        label: wide ? lb.sortShort(f.sort) : lb.sort(f.sort),
        // На телефоне — только значок: строке нужно место.
        compact: !wide,
        chevron: wide,
        onTap: () async {
          final r = await showFilterPicker<OrderSort>(
              context: anchor, builder: (_) => SortPanel(sort: f.sort));
          if (r != null) onChanged(f.copyWith(sort: r));
        },
      ),
    );

    if (!wide) {
      return Row(children: [
        Expanded(child: searchField),
        const SizedBox(width: AppSpace.s),
        allButton(l.filterAll, l.filterAllCount(n)),
        const SizedBox(width: AppSpace.xs),
        sort,
      ]);
    }

    return Row(children: [
      SizedBox(width: 240, child: searchField),
      const SizedBox(width: AppSpace.m),
      Expanded(
        child: AppFadingScroll(
          child: Row(children: [
            for (final k in kMainFilterKeys) ...[
              Builder(
                builder: (anchor) => AppFilterChip(
                  label: lb.title(k),
                  activeLabel: lb.value(k, f, choices, now),
                  clearLabel: l.filterClearOne(lb.title(k)),
                  onClear: () => onChanged(f.without(k)),
                  onTap: () async {
                    final r = await pickFilter(anchor, k, f, choices,
                        loadPlaces: loadPlaces);
                    if (r != null) onChanged(r);
                  },
                ),
              ),
              if (k != kMainFilterKeys.last) const SizedBox(width: AppSpace.s),
            ],
          ]),
        ),
      ),
      const SizedBox(width: AppSpace.s),
      allButton(l.filterAllWide, l.filterAllWideCount(n)),
      const SizedBox(width: AppSpace.xs),
      sort,
    ]);
  }
}

/// Строка применённых фильтров («Москва (5) ×», «Просрочено ×», …,
/// «Сбросить всё»): прокручивается и гаснет у края. Нажатие на таблетку —
/// окно этого фильтра, «×» — снять его. Показывается, только если
/// [OrderFilterLabels.applied] не пуст.
class AppliedFiltersRow extends StatelessWidget {
  const AppliedFiltersRow({
    super.key,
    required this.filter,
    required this.choices,
    required this.onChanged,
    required this.onOpenAll,
    this.skip = const {},
    this.loadPlaces,
  });

  final OrderFilter filter;
  final FilterChoices choices;
  final ValueChanged<OrderFilter> onChanged;
  final VoidCallback onOpenAll;
  final Set<FilterKey> skip;
  final PlacesLoader? loadPlaces;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lb = OrderFilterLabels(l);
    final f = filter;
    final items = lb.applied(f, choices, DateTime.now(), skip: skip);
    return AppFadingScroll(
      child: Row(children: [
        for (final (k, label) in items) ...[
          Builder(
            builder: (anchor) => AppFilterChip(
              label: lb.title(k),
              activeLabel: label,
              clearLabel: l.filterClearOne(lb.title(k)),
              onClear: () => onChanged(f.without(k)),
              onTap: () async {
                if (!hasOwnPicker(k)) return onOpenAll();
                final r = await pickFilter(anchor, k, f, choices,
                    loadPlaces: loadPlaces);
                if (r != null) onChanged(r);
              },
            ),
          ),
          const SizedBox(width: AppSpace.s),
        ],
        Pressable(
          onTap: () => onChanged(f.cleared().copyWith(segment: f.segment)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTap),
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
      ]),
    );
  }
}

// ---------------------------------------------------------------------
// Окно «Фильтры»
// ---------------------------------------------------------------------

/// Все фильтры списком: строка на фильтр с текущим значением справа (её
/// окно выбора открывается поверх), «Тип» и «Условия» — галочками. Внизу
/// закреплены «Сбросить» и «Показать N заявок»: N считает сервер через
/// ~300 мс после изменения; пока считает или при ошибке — «Показать».
class OrderFiltersPanel extends StatefulWidget {
  const OrderFiltersPanel({
    super.key,
    required this.filter,
    required this.choices,
    required this.count,
    this.loadPlaces,
    this.debounce = const Duration(milliseconds: 300),
  });

  final OrderFilter filter;
  final FilterChoices choices;
  final OrderCounter count;
  final PlacesLoader? loadPlaces;
  final Duration debounce;

  @override
  State<OrderFiltersPanel> createState() => _OrderFiltersPanelState();
}

class _OrderFiltersPanelState extends State<OrderFiltersPanel> {
  late OrderFilter _f = widget.filter;
  int? _count;
  Timer? _timer;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _set(OrderFilter f) {
    setState(() => _f = f);
    _recount();
  }

  void _recount() {
    _timer?.cancel();
    final seq = ++_seq;
    setState(() => _count = null);
    _timer = Timer(widget.debounce, () async {
      try {
        final n = await widget.count(_f);
        if (mounted && seq == _seq) setState(() => _count = n);
      } catch (e) {
        debugPrint('OrderFiltersPanel count: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lb = OrderFilterLabels(l);
    final now = DateTime.now();
    final c = widget.choices;

    Widget row(FilterKey k, IconData icon) => Builder(
          builder: (anchor) => AppRow(
            leading: LeadingIcon(icon),
            title: lb.title(k),
            value: lb.value(k, _f, c, now) ?? l.filterAny,
            onTap: () async {
              final r = await pickFilter(anchor, k, _f, c,
                  loadPlaces: widget.loadPlaces);
              if (r != null && mounted) _set(r);
            },
          ),
        );

    AppCheckRow rec(RecurrenceFilter r, String title) => AppCheckRow(
          title: title,
          selected: _f.recurrence == r,
          onTap: () => _set(_f.recurrence == r
              ? _f.copyWith(clearRecurrence: true)
              : _f.copyWith(recurrence: r)),
        );

    final n = _count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppSizes.navBar + 4,
          child: NavigationToolbar(
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpace.s),
              child: AppIconButton(
                  icon: AppIcons.close,
                  label: l.commonClose,
                  filled: true,
                  size: 32,
                  onPressed: () => Navigator.pop(context)),
            ),
            middle: Semantics(
              header: true,
              child: Text(l.filterAll, style: AppText.headline),
            ),
            trailing: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpace.xs),
              child: AppInfoButton(
                title: l.infoFiltersTitle,
                lines: [l.infoFilters1, l.infoFilters2, l.infoFilters3],
                closeLabel: l.commonGotIt,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
            children: [
              AppGroup(children: [
                row(FilterKey.period, AppIcons.calendar),
                row(FilterKey.status, AppIcons.checklist),
                row(FilterKey.object, AppIcons.building),
                if (_f.objectIds.length == 1)
                  row(FilterKey.room, AppIcons.room),
                row(FilterKey.contractor, AppIcons.contractor),
                row(FilterKey.layer, AppIcons.workType),
                row(FilterKey.priority, AppIcons.warning),
                row(FilterKey.channel, AppIcons.inbox),
              ]),
              AppPanelGroup(header: l.filterType, children: [
                rec(RecurrenceFilter.once, l.filterOnce),
                rec(RecurrenceFilter.recurring, l.filterRecurring),
              ]),
              const SizedBox(height: AppSpace.group),
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
                    onTap: () =>
                        _set(_f.copyWith(createdByMe: !_f.createdByMe))),
                if (c.isExecutor || _f.assignedToMe)
                  AppCheckRow(
                      title: l.filterAssignedToMe,
                      selected: _f.assignedToMe,
                      onTap: () =>
                          _set(_f.copyWith(assignedToMe: !_f.assignedToMe))),
              ]),
            ],
          ),
        ),
        BottomActionBar(
          // «Сбросить» — текстом: «Показать 12 заявок» не обрезается и на 360.
          child: Row(children: [
            AppBarTextButton(
                label: l.filterReset,
                onPressed: _f.hasFilters
                    ? () => _set(_f.cleared().copyWith(segment: _f.segment))
                    : null),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: AppButton.primary(
                  label: n == null ? l.filterShow : l.filterShowCount(n),
                  onPressed: () => Navigator.pop(context, _f)),
            ),
          ]),
        ),
      ],
    );
  }
}
