import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../home/home_actions.dart';
import '../home/home_chrome.dart';
import '../voice/voice_record_screen.dart';
import '../voice/wake_word_service.dart';
import 'order_filter.dart';
import 'order_filter_bar.dart';
import 'order_filter_store.dart';
import 'order_filters_panel.dart';
import 'requests.dart';

/// Ширина колонки вкладки «Заявки» на ПК: рядом с поиском помещаются
/// таблетки главных фильтров.
const kRequestsMaxWidth = 960.0;

/// Вкладка «Заявки»: поиск, строка фильтров, сегменты «Все / Открытые /
/// Просрочено» (у выбранного при фильтрах — «12 из 72») и список (группы —
/// по смыслу сортировки, подписи — если групп больше одной).
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key, this.objectFilter, this.onClearObjectFilter});

  /// Объект из карты (кнопка «Заявки»): становится фильтром «Объект».
  /// Срабатывает один раз, потом вызывается [onClearObjectFilter].
  final Obj? objectFilter;
  final VoidCallback? onClearObjectFilter;

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final _repo = RequestsRepo();
  final _dir = DirectoryRepo();
  final _store = const OrderFilterStore();
  final _search = TextEditingController();

  /// Сейчас — кнопка «Нажми и говори»; позже сюда же подключится «Эй, Хелпи».
  final _wake = PushToTalkWakeWord();
  StreamSubscription<void>? _wakeSub;
  bool _voiceOpen = false;

  List<WorkOrder> _items = [];
  int _total = 0;
  List<Obj> _objects = const [];
  List<Contractor> _contractors = const [];
  List<Layer> _layers = const [];
  List<String> _execIds = const [];
  String? _companyId;
  String? _role;
  bool _refsLoaded = false;

  OrderFilter _filter = OrderFilter.empty;
  bool _filterReady = false;
  final Map<String, List<FilterOption>> _places = {};

  bool _loading = true;
  String? _error;
  String _query = '';

  /// Номер последнего запроса: ответы старых запросов не показываем.
  int _req = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    _wakeSub = _wake.detections.listen((_) => _openVoice());
    _wake.start();
  }

  HomeActions? _homeActions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final a = HomeChrome.maybeOf(context)?.actions;
    if (a != _homeActions) {
      _homeActions?.removeListener(_onHomeAction);
      _homeActions = a?..addListener(_onHomeAction);
    }
  }

  /// Кнопки бокового меню ПК и горячие клавиши: выполнить, когда
  /// справочники загружены (иначе — после загрузки, см. [_load]).
  void _onHomeAction() {
    final a = _homeActions;
    if (a == null || !mounted || !_refsLoaded) return;
    switch (a.take()) {
      case HomeAction.create:
        _openCreate();
      case HomeAction.voice:
        _wake.trigger();
      case HomeAction.search:
        a.searchFocus.requestFocus();
      case null:
        break;
    }
  }

  @override
  void didUpdateWidget(RequestsTab old) {
    super.didUpdateWidget(old);
    final o = widget.objectFilter;
    if (_filterReady && o != null && o.id != old.objectFilter?.id) {
      _applyObjectFromMap(o);
    }
  }

  @override
  void dispose() {
    _homeActions?.removeListener(_onHomeAction);
    _wakeSub?.cancel();
    _wake.dispose();
    _search.dispose();
    _store.clearUrl();
    super.dispose();
  }

  Future<void> _init() async {
    var f = await _store.load(_repo.uid);
    final o = widget.objectFilter;
    if (o != null) f = f.copyWith(objectIds: {o.id});
    if (!mounted) return;
    setState(() {
      _filter = f;
      _filterReady = true;
    });
    unawaited(_store.save(_repo.uid, f));
    if (o != null) widget.onClearObjectFilter?.call();
    _ensurePlaces(f);
    await _load();
  }

  void _applyObjectFromMap(Obj o) {
    _setFilter(_filter.copyWith(objectIds: {o.id}));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onClearObjectFilter?.call());
  }

  /// Справочники (один раз и по «Обновить») и заявки по фильтру.
  Future<void> _load({bool refs = true}) async {
    final req = ++_req;
    setState(() {
      if (_items.isEmpty) _loading = true;
      _error = null;
    });
    try {
      if (refs || !_refsLoaded) {
        _companyId ??= await _dir.myCompanyId();
        _role ??= await _repo.myRole();
        final r = await Future.wait<Object>([
          _dir.objects(),
          _dir.contractors(),
          _dir.layers().catchError((_) => _layers),
          _repo.myExecutorIds().catchError((_) => const <String>[]),
        ]);
        _objects = r[0] as List<Obj>;
        _contractors = r[1] as List<Contractor>;
        _layers = r[2] as List<Layer>;
        _execIds = r[3] as List<String>;
        _refsLoaded = true;
      }
      final conds = _filter.serverConditions(
          now: DateTime.now(), uid: _repo.uid, myExecutorIds: _execIds);
      final r = await Future.wait<Object>(
          [_repo.listFiltered(conds), _repo.countAll()]);
      if (!mounted || req != _req) return;
      setState(() {
        _items = r[0] as List<WorkOrder>;
        _total = r[1] as int;
        _loading = false;
      });
      // Бейдж «Главная» в боковом меню — просроченные без фильтров.
      if (!_filter.hasFilters) {
        _homeActions?.setOverdue(
            _items.where((w) => w.isOverdue(DateTime.now())).length);
      }
      _onHomeAction();
    } catch (e) {
      debugPrint('RequestsTab: $e');
      if (!mounted || req != _req) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Новый фильтр: сохранить (устройство и адрес) и, если поменялось то,
  /// что уходит на сервер, перечитать заявки.
  void _setFilter(OrderFilter f) {
    OrderFilter server(OrderFilter x) =>
        x.copyWith(sort: OrderSort.newest, segment: OrderSegment.all);
    final reload = server(f) != server(_filter);
    setState(() => _filter = f);
    unawaited(_store.save(_repo.uid, f));
    _ensurePlaces(f);
    if (reload) _load(refs: false);
  }

  /// Запрос только количества для «Показать N заявок».
  Future<int> _count(OrderFilter f) {
    final now = DateTime.now();
    return _repo.countFiltered([
      ...f.serverConditions(now: now, uid: _repo.uid, myExecutorIds: _execIds),
      ...f.segmentConditions(now),
    ]);
  }

  Future<void> _openFilters() async {
    final r = await showOrderFilters(context,
        filter: _filter,
        choices: _choices(),
        count: _count,
        loadPlaces: _loadPlaces);
    if (r != null && mounted) _setFilter(r);
  }

  void _resetAll() {
    _search.clear();
    setState(() => _query = '');
    _setFilter(_filter.cleared());
  }

  /// Помещения выбранного объекта (для окна и подписи таблетки).
  void _ensurePlaces(OrderFilter f) {
    if (f.objectIds.length != 1) return;
    final id = f.objectIds.single;
    if (_places.containsKey(id)) return;
    _loadPlaces(id).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<List<FilterOption>> _loadPlaces(String objectId) async {
    final cached = _places[objectId];
    if (cached != null) return cached;
    try {
      final list = await _dir.placesOf(objectId);
      return _places[objectId] = [
        for (final p in list) FilterOption(p.id, p.name),
      ];
    } catch (e) {
      debugPrint('RequestsTab places: $e');
      return const [];
    }
  }

  /// «Москва · Офис 3» — в разных городах бывают одинаковые названия.
  String _objName(AppLocalizations l, String? id) {
    if (id == null) return l.objectNone;
    for (final o in _objects) {
      if (o.id == id) return objectDisplayName(o);
    }
    return l.objectUnknown;
  }

  String? _workType(WorkOrder w) {
    final layer = Layer.find(_layers, id: w.layerId, name: w.workType);
    if (layer != null) return layer.label(context.localeCode);
    final t = w.workType;
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Поиск по названию, объекту, помещению и виду работ.
  bool _matches(WorkOrder w) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      w.title,
      _objName(context.l10n, w.objectId),
      w.placeName ?? '',
      _workType(w) ?? '',
    ].any((t) => t.toLowerCase().contains(q));
  }

  FilterChoices _choices() {
    final locale = context.localeCode;
    final placeKey =
        _filter.objectIds.length == 1 ? _filter.objectIds.single : null;
    return FilterChoices(
      objects: _objects,
      contractors: [
        for (final c in _contractors) FilterOption(c.id, c.orgName)
      ],
      layers: [for (final y in _layers) FilterOption(y.id, y.label(locale))],
      places: placeKey == null ? const [] : (_places[placeKey] ?? const []),
      isExecutor: _role == 'executor' || _role == 'contractor',
    );
  }

  Future<void> _openDetail(WorkOrder w) async {
    await Navigator.push(
        context,
        appRoute(
          (_) => WorkOrderDetailScreen(
            order: w,
            objects: _objects,
            contractors: _contractors,
            layers: _layers,
            uid: _repo.uid,
            role: _role,
            repo: _repo,
            companyId: _companyId,
          ),
          title: context.l10n.tabRequests,
        ));
    _load(refs: false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = DateTime.now();
    final view = buildOrderList(_items, _filter,
        now: now,
        uid: _repo.uid,
        myExecutorIds: _execIds,
        search: _matches,
        objectName: (id) => _objName(l, id));
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppSpace.wideFrom;
    final desktop = HomeChrome.maybeOf(context)?.desktop ?? wide;
    // Фильтры или поиск сужают список: у выбранного сегмента — «12 из 72».
    final narrowed =
        _filterReady && (_filter.hasFilters || _query.trim().isNotEmpty);
    String seg(OrderSegment s, int n) => segmentCountText(l,
        count: n,
        total: _total,
        selected: _filter.segment == s,
        narrowed: narrowed && !_loading,
        width: width);
    final choices = _choices();
    final skip = wide ? kMainFilterKeys.toSet() : const <FilterKey>{};
    final applied = _filterReady &&
        OrderFilterLabels(l)
            .applied(_filter, choices, now, skip: skip)
            .isNotEmpty;
    // Строка поиска и фильтров (+ строка применённых) закреплена под шапкой.
    final barHeight = AppSpace.xs * 2 + AppSizes.minTap * (applied ? 2 : 1);
    return Stack(children: [
      Positioned.fill(
        child: CustomScrollView(slivers: [
          HomeHeader(
            title: l.tabRequests,
            maxWidth: kRequestsMaxWidth,
            onRefresh: _loading ? null : _load,
          ),
          AppSliverBar(
            height: barHeight,
            maxWidth: kRequestsMaxWidth,
            child: Padding(
              padding:
                  const EdgeInsetsDirectional.symmetric(vertical: AppSpace.xs),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_filterReady)
                      OrderControlBar(
                        filter: _filter,
                        choices: choices,
                        search: _search,
                        onSearch: (v) => setState(() => _query = v),
                        onChanged: _setFilter,
                        onOpenAll: _openFilters,
                        loadPlaces: _loadPlaces,
                        searchFocus: _homeActions?.searchFocus,
                      )
                    else
                      SizedBox(
                        height: AppSizes.minTap,
                        child: Center(
                          child: AppSearchField(
                              controller: _search,
                              hint: l.reqSearchHint,
                              onChanged: (v) => setState(() => _query = v)),
                        ),
                      ),
                    if (applied)
                      AppliedFiltersRow(
                        filter: _filter,
                        choices: choices,
                        onChanged: _setFilter,
                        onOpenAll: _openFilters,
                        skip: skip,
                        loadPlaces: _loadPlaces,
                      ),
                  ]),
            ),
          ),
          // Сегменты прячутся при прокрутке вниз и возвращаются вверх.
          AppSliverBar(
            floating: true,
            height: AppSizes.segmentHeight + AppSpace.s * 2,
            maxWidth: kRequestsMaxWidth,
            child: Center(
              // Диктору — полный текст «Найдено 12 из 72» (строки «Найдено»
              // на экране больше нет: числа — в сегментах).
              child: Semantics(
                container: true,
                label: narrowed && !_loading
                    ? l.filterFound(view.items.length, _total)
                    : null,
                child: SegmentedControl<OrderSegment>(
                  segments: [
                    Segment(OrderSegment.all,
                        l.reqSegAll(seg(OrderSegment.all, view.all))),
                    Segment(OrderSegment.open,
                        l.reqSegOpen(seg(OrderSegment.open, view.open))),
                    Segment(
                        OrderSegment.overdue,
                        l.reqSegOverdue(
                            seg(OrderSegment.overdue, view.overdue))),
                  ],
                  selected: _filter.segment,
                  onChanged: (s) => _setFilter(_filter.copyWith(segment: s)),
                ),
              ),
            ),
          ),
          ..._body(view, now),
          // Телефон: под последней заявкой — место для плавающих кнопок.
          SliverBottomInset(
              extra: desktop ? AppSpace.xl : AppSizes.fabClearance),
        ]),
      ),
      // Телефон: голосовая кнопка и «+» — над нижним меню (оно поверх
      // содержимого). ПК: эти кнопки — в боковом меню слева.
      if (!desktop)
        PositionedDirectional(
          end: AppSpace.screen,
          bottom: MediaQuery.paddingOf(context).bottom + AppSpace.l,
          child: VoiceButton(
            label: l.appName,
            semanticLabel: l.requestsVoice,
            onVoice: _wake.trigger,
            addLabel: l.requestsCreate,
            onAdd: _openCreate,
          ),
        ),
    ]);
  }

  String? _groupLabel(AppLocalizations l, String key) => switch (_filter.sort) {
        OrderSort.newest ||
        OrderSort.oldest =>
          key == 'today' ? l.reqGroupToday : l.reqGroupEarlier,
        OrderSort.priority => l.priority(key),
        OrderSort.status => key == kOverdue ? l.filterOverdue : l.status(key),
        OrderSort.object => key.isEmpty ? l.objectNone : _objName(l, key),
        OrderSort.due => null,
      };

  List<Widget> _body(OrderListView view, DateTime now) {
    final l = context.l10n;
    if (_loading) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: AppLoader())
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.requestsLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load),
        )
      ];
    }
    if (view.items.isEmpty) {
      final narrowed = _filter.hasFilters ||
          _filter.segment != OrderSegment.all ||
          _query.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: narrowed
              ? AppEmptyState(
                  text: l.reqNothingFound,
                  icon: AppIcons.search,
                  actionLabel: l.filterResetFilters,
                  onAction: _resetAll)
              : AppEmptyState(text: l.requestsEmpty),
        )
      ];
    }

    final narrowRow = MediaQuery.sizeOf(context).width < kSegmentOfFrom;
    Widget row(WorkOrder w) {
      final workType = _workType(w);
      // «Москва · Офис 3 · Лобби · Климат» — объект всегда с городом.
      final place = [
        _objName(l, w.objectId),
        if (w.placeName != null && w.placeName!.isNotEmpty)
          placeWithFloor(w.placeName!, w.floorName,
              w.floorLevel == null ? null : l.floorShort(w.floorLevel!)),
      ].join(' · ');
      final overdue = w.isOverdue(now);
      final overdueText = Text(l.statusOverdue,
          style: AppText.footnote
              .copyWith(color: AppColors.danger, fontWeight: FontWeight.w600));
      final due = _filter.sort == OrderSort.due && w.dueAt != null
          ? '${l.reqFieldDue}: ${l.dateTime(w.dueAt!)}'
          : null;
      return AppRow(
        leading: PriorityDot(w.priority),
        title: w.title + (w.recurring ? '  · ${l.requestRecurringTag}' : ''),
        subtitle: [
          [place, if (workType != null) workType].join(' · '),
          if (due != null) due,
        ].join('\n'),
        subtitleMaxLines: due == null ? 2 : 3,
        // Капсула — всегда настоящий статус; просрочка — красной подписью
        // под строкой (иначе не видно, новая заявка или уже в работе).
        extra: narrowRow
            ? Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpace.xxs),
                child: Wrap(
                    spacing: AppSpace.s,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [StatusPill(w.status), if (overdue) overdueText]),
              )
            : (overdue ? overdueText : null),
        // Узкий телефон: статус — под названием, название во всю ширину.
        trailing: narrowRow ? null : StatusPill(w.status),
        onTap: () => _openDetail(w),
      );
    }

    final groups = groupOrders(view.items, _filter.sort, now: now);
    final headers = showGroupHeaders(groups);
    return [
      SliverContent(
        top: headers ? 0 : AppSpace.xs,
        maxWidth: kRequestsMaxWidth,
        sliver: SliverList.list(children: [
          for (final g in groups)
            AppGroup(
                header: headers ? _groupLabel(l, g.key) : null,
                compactHeader: true,
                children: [for (final w in g.items) row(w)]),
        ]),
      ),
    ];
  }

  Future<void> _openCreate() async {
    if (_companyId == null) {
      _snack(context.l10n.requestsNoCompany, type: AppMessageType.error);
      return;
    }
    final ok = await showOrderForm(
        context: context,
        repo: _repo,
        objects: _objects,
        companyId: _companyId!,
        existing: null,
        initialObjectId:
            _filter.objectIds.length == 1 ? _filter.objectIds.single : null);
    if (ok == true) {
      await _load(refs: false);
      if (mounted) _snackOk(context.l10n.requestsCreated);
    }
  }

  Future<void> _openVoice() async {
    if (_voiceOpen || !mounted) return;
    if (_companyId == null) {
      _snack(context.l10n.requestsNoCompany, type: AppMessageType.error);
      return;
    }
    _voiceOpen = true;
    final ok = await Navigator.push<bool>(
        context,
        appRoute(
            (_) => VoiceRecordScreen(companyId: _companyId!, objects: _objects),
            title: context.l10n.tabRequests));
    _voiceOpen = false;
    if (ok == true) {
      await _load(refs: false);
      if (mounted) _snackOk(context.l10n.requestsCreated);
    }
  }

  void _snack(String m, {AppMessageType type = AppMessageType.info}) {
    if (mounted) showAppMessage(context, m, type: type);
  }

  void _snackOk(String m) {
    if (mounted) showAppMessage(context, m, type: AppMessageType.success);
  }
}
