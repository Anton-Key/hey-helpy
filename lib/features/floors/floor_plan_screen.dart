import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../map/map_logic.dart';
import '../map/map_parts.dart';
import '../requests/order_list.dart';
import '../requests/requests.dart';
import 'floor_models.dart';
import 'floor_repository.dart';
import 'floors_section.dart';
import 'plan_canvas.dart';
import 'plan_logic.dart';
import 'plan_sheets.dart';

/// Экран «План этажа»: картинка плана с масштабом, маркеры помещений и
/// оборудования, фильтр, список «На плане / Не размещены», шторка маркера
/// с заявками. У менеджера — режим расстановки.
///
/// Адрес: `/objects/<objectId>/floors/<floorId>?focus=place:<id>&edit=1`.
class FloorPlanScreen extends StatefulWidget {
  const FloorPlanScreen({
    super.key,
    required this.objectId,
    required this.floorId,
    this.focus,
    this.startEditing = false,
    this.updateUrl = true,
  });

  /// false — открыт внутри области справа от бокового меню (ПК): адрес
  /// страницы при смене этажа не меняется.
  final bool updateUrl;

  final String objectId;
  final String floorId;

  /// Маркер, на котором открыть план ([PlanItem.key]).
  final String? focus;
  final bool startEditing;

  @override
  State<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

enum _MarkerAction { create, allOrders, rename, unplace, delete }

enum _EmptyAction { newPlace, newAsset, putHere }

class _FloorPlanScreenState extends State<FloorPlanScreen> {
  final _repo = FloorRepo();
  final _canvas = PlanCanvasController();
  final _sheet = DraggableScrollableController();

  OrderContext? _ctx;
  Obj? _obj;
  List<Floor> _floors = const [];
  late String _floorId = widget.floorId;
  List<PlanItem> _items = const [];
  List<PlanOrder> _orders = const [];
  bool _loading = true;
  bool _failed = false;
  bool _notFound = false;
  PlanFilter _filter = PlanFilter.all;
  late bool _editing = widget.startEditing;
  late String? _highlight = widget.focus;
  String _query = '';

  bool get _isManager => _ctx?.isManager ?? false;
  bool get _wide => MediaQuery.sizeOf(context).width >= AppSpace.wideFrom;

  Floor? get _floor {
    for (final f in _floors) {
      if (f.id == _floorId) return f;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await Future.wait<Object?>([
        _ctx == null ? OrderContext.load() : Future.value(_ctx),
        DirectoryRepo().object(widget.objectId),
        _repo.floorsOf(widget.objectId),
        _repo.itemsOf(widget.objectId),
        _repo.openOrdersOf(widget.objectId),
      ]);
      if (!mounted) return;
      setState(() {
        _ctx = r[0] as OrderContext;
        _obj = r[1] as Obj?;
        _floors = r[2] as List<Floor>;
        _items = r[3] as List<PlanItem>;
        _orders = r[4] as List<PlanOrder>;
        _notFound = _obj == null || _floor == null;
        _editing = _editing && _isManager;
        _loading = false;
      });
    } catch (e) {
      debugPrint('FloorPlan: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// После изменений: маркеры и заявки (этажи и роль — те же).
  Future<void> _reloadItems() async {
    try {
      final r = await Future.wait<Object>([
        _repo.itemsOf(widget.objectId),
        _repo.openOrdersOf(widget.objectId),
      ]);
      if (!mounted) return;
      setState(() {
        _items = r[0] as List<PlanItem>;
        _orders = r[1] as List<PlanOrder>;
      });
    } catch (e) {
      debugPrint('FloorPlan reload: ${e.runtimeType}');
    }
  }

  void _msg(String text, {AppMessageType type = AppMessageType.info}) {
    if (mounted) showAppMessage(context, text, type: type);
  }

  void _fail(Object e) {
    logPlanError('FloorPlan', e);
    _msg(planErrorText(context.l10n, e, isManager: _isManager),
        type: AppMessageType.error);
  }

  // ------------------------------------------------------------ этажи

  void _switchFloor(String id) {
    if (id == _floorId) return;
    setState(() {
      _floorId = id;
      _highlight = null;
    });
    // Адрес страницы — новый этаж (ссылкой можно поделиться).
    if (!widget.updateUrl) return;
    SystemNavigator.routeInformationUpdated(
        uri: Uri.parse(floorPlanLocation(widget.objectId, id)), replace: true);
  }

  Future<void> _pickFloor(BuildContext anchor) async {
    final l = context.l10n;
    final id = await showFilterPicker<String>(
      context: anchor,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
          child: Text(l.planFloorPicker, style: AppText.headline),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, 0, AppSpace.screen, AppSpace.screen),
            child: SafeArea(
              top: false,
              child: AppPanelGroup(children: [
                for (final f in _floors)
                  AppCheckRow(
                    title: f.name,
                    subtitle: floorSummary(l, f, _items, _orders),
                    selected: f.id == _floorId,
                    onTap: () => Navigator.pop(ctx, f.id),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
    if (id != null) _switchFloor(id);
  }

  // ------------------------------------------------------------ маркеры

  String _itemLabel(AppLocalizations l, PlanItem i) {
    final n = planStats(_orders, DateTime.now())[i.key]?.open ?? 0;
    return '${i.name}, ${l.floorOpenOrders(n)}';
  }

  PlanItem? _placeOf(PlanItem asset) {
    for (final i in _items) {
      if (i.isPlace && i.id == asset.locationId) return i;
    }
    return null;
  }

  String? _floorName(String? id) {
    for (final f in _floors) {
      if (f.id == id) return f.name;
    }
    return null;
  }

  void _toggleSheet() {
    if (!_sheet.isAttached) return;
    final open = _sheet.size > 0.3;
    _sheet.animateTo(open ? 0.14 : 0.6,
        duration: AppMotion.normal, curve: Curves.easeOutCubic);
  }

  void _focus(PlanItem i) {
    if (i.isOn(_floorId)) {
      setState(() => _highlight = i.key);
      _canvas.centerOn(i);
      if (!_wide && _sheet.isAttached) {
        _sheet.animateTo(0.14,
            duration: AppMotion.normal, curve: Curves.easeOutCubic);
      }
      return;
    }
    if (_editing) {
      final c = _canvas.viewCenter();
      if (c != null) _move(i, c.$1, c.$2);
      return;
    }
    _showMarker(i);
  }

  bool _uploading = false;

  /// «Загрузить / Заменить план» прямо с экрана плана: та же проверка файла
  /// и тот же код загрузки, что в «⋯» карточки объекта. План появляется
  /// сразу; превью в карточке обновится при возврате.
  Future<void> _uploadPlan() async {
    final floor = _floor;
    if (floor == null || _uploading) return;
    final l = context.l10n;
    final p = await pickPlanFile(context);
    if (p == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final f = await _repo.uploadPlan(floor, p.bytes, p.info);
      if (!mounted) return;
      setState(() {
        _floors = [for (final x in _floors) x.id == f.id ? f : x];
      });
      _msg(l.planUploaded, type: AppMessageType.success);
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// «Не размещены · N» в режиме расстановки: выбрать — встанет в центр
  /// видимой части плана, дальше перетащить.
  Future<void> _pickUnplaced() async {
    final l = context.l10n;
    final unplaced = unplacedFor(_floorId, _items);
    if (unplaced.isEmpty) {
      _msg(l.planNothingUnplaced);
      return;
    }
    final pick = await showActionSheet<PlanItem>(context,
        title: l.planPickUnplaced,
        actions: [
          for (final i in unplaced) SheetAction(i, i.name, equipmentIcon(i)),
        ]);
    if (pick != null && mounted) _focus(pick);
  }

  Future<void> _move(PlanItem i, double fx, double fy) async {
    final l = context.l10n;
    final before = i;
    setState(() {
      _items = [
        for (final x in _items)
          x.key == i.key ? x.copyWith(floorId: _floorId, x: fx, y: fy) : x
      ];
      _highlight = i.key;
    });
    try {
      await _repo.setPoint(i, _floorId, fx, fy);
      if (!mounted) return;
      showAppMessage(context, l.planSaved,
          type: AppMessageType.success,
          actionLabel: l.planUndo, onAction: () async {
        try {
          await _repo.restore(before);
        } catch (e) {
          _fail(e);
        }
        await _reloadItems();
      });
    } catch (e) {
      _fail(e);
      await _reloadItems();
    }
  }

  Future<void> _showMarker(PlanItem i) async {
    final l = context.l10n;
    final now = DateTime.now();
    final orders = ordersOf(i, _orders, now);
    final place = i.isPlace ? i : _placeOf(i);
    final details = [
      if (!i.isPlace && i.category != null) l.assetCategory(i.category!),
      if (!i.isPlace && place != null) place.name,
      if (_floorName(i.floorId) case final f?) f,
      if (!i.placed) l.placeNotOnPlan,
    ].join(' · ');
    final a = await showAppSheet<_MarkerAction>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                LeadingIcon(equipmentIcon(i)),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                            header: true,
                            child: Text(i.name, style: AppText.title2)),
                        if (details.isNotEmpty)
                          Text(details, style: AppText.footnote),
                      ]),
                ),
              ]),
              const SizedBox(height: AppSpace.m),
              if (!i.isPlace && i.inventoryNo != null)
                AppGroup(children: [
                  AppRow(
                      leading: const LeadingIcon.neutral(AppIcons.key),
                      title: l.planAssetInventory,
                      value: i.inventoryNo),
                ]),
              AppGroup(header: l.planOpenOrders, children: [
                if (orders.isEmpty)
                  AppRow(title: l.planNoOpenOrders, titleStyle: AppText.callout)
                else
                  for (final o in orders)
                    OrderTile(
                      title: o.title,
                      status: o.status,
                      priority: o.priority,
                      alerts: [if (o.isOverdue(now)) l.statusOverdue],
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _ctx!.open(context, o.row);
                        await _reloadItems();
                      },
                    ),
                if (place != null)
                  AppRow(
                    leading: const LeadingIcon(AppIcons.list),
                    title: l.planAllPlaceOrders,
                    titleStyle:
                        AppText.rowTitle.copyWith(color: AppColors.accentText),
                    onTap: () => Navigator.pop(ctx, _MarkerAction.allOrders),
                  ),
              ]),
              if (_ctx?.companyId != null)
                AppButton.primary(
                    icon: AppIcons.add,
                    label: l.planCreateHere,
                    onPressed: () => Navigator.pop(ctx, _MarkerAction.create)),
              if (_editing) ...[
                const SizedBox(height: AppSpace.group),
                AppGroup(children: [
                  AppRow(
                      leading: const LeadingIcon(AppIcons.edit),
                      title: l.planRename,
                      chevron: false,
                      onTap: () => Navigator.pop(ctx, _MarkerAction.rename)),
                  if (i.placed)
                    AppRow(
                        leading: const LeadingIcon(AppIcons.placeOff),
                        title: l.planRemoveFromPlan,
                        chevron: false,
                        onTap: () => Navigator.pop(ctx, _MarkerAction.unplace)),
                  AppRow(
                      leading: const LeadingIcon.danger(AppIcons.delete),
                      title: l.planDelete,
                      destructive: true,
                      chevron: false,
                      onTap: () => Navigator.pop(ctx, _MarkerAction.delete)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
    if (a == null || !mounted) return;
    switch (a) {
      case _MarkerAction.create:
        final ok = await showOrderForm(
          context: context,
          repo: _ctx!.repo,
          objects: _ctx!.objects,
          companyId: _ctx!.companyId!,
          initialObjectId: widget.objectId,
          initialLocationId: place?.id,
          initialAssetId: i.isPlace ? null : i.id,
          initialAssetName: i.isPlace ? null : i.name,
        );
        if (ok == true) {
          await _reloadItems();
          _msg(l.requestsCreated, type: AppMessageType.success);
        }
      case _MarkerAction.allOrders:
        await Navigator.push(
            context,
            appRoute(
                (_) => WorkOrderListScreen(
                    title: place!.name,
                    subtitle: _obj == null ? null : objectDisplayName(_obj!),
                    locationId: place.id),
                title: l.planTitle));
        await _reloadItems();
      case _MarkerAction.rename:
        final name =
            await askText(context, title: l.planRename, initial: i.name);
        if (name == null) return;
        try {
          await _repo.rename(i, name);
          _msg(l.planSaved, type: AppMessageType.success);
        } catch (e) {
          _fail(e);
        }
        await _reloadItems();
      case _MarkerAction.unplace:
        await _unplace(i);
      case _MarkerAction.delete:
        await _delete(i);
    }
  }

  Future<void> _unplace(PlanItem i) async {
    final l = context.l10n;
    try {
      await _repo.clearPoint(i);
      _msg(l.planSaved, type: AppMessageType.success);
    } catch (e) {
      _fail(e);
    }
    await _reloadItems();
  }

  Future<void> _delete(PlanItem i) async {
    final l = context.l10n;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.planDeleteConfirm(i.name),
      actions: [
        AppDialogAction(l.actionDelete, true, destructive: true),
        AppDialogAction(l.commonCancel, false),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(i);
      _msg(l.planSaved, type: AppMessageType.success);
    } on HasOrders {
      if (!mounted) return;
      // Заявки не теряем: вместо удаления — «Убрать с плана».
      final unplace = await showAppDialog<bool>(
        context: context,
        title: l.planDeleteHasOrders(i.name),
        actions: [
          if (i.placed) AppDialogAction(l.planRemoveFromPlan, true),
          AppDialogAction(l.commonCancel, false),
        ],
      );
      if (unplace == true) await _unplace(i);
      return;
    } catch (e) {
      _fail(e);
    }
    await _reloadItems();
  }

  Future<void> _emptyTap(double fx, double fy) async {
    final l = context.l10n;
    final unplaced = unplacedFor(_floorId, _items);
    final a = await showActionSheet<_EmptyAction>(context,
        title: l.planEditMode,
        actions: [
          SheetAction(_EmptyAction.newPlace, l.planNewPlaceHere, AppIcons.room),
          SheetAction(
              _EmptyAction.newAsset, l.planNewAssetHere, AppIcons.wrench),
          if (unplaced.isNotEmpty)
            SheetAction(_EmptyAction.putHere, l.planPutHere, AppIcons.place),
        ]);
    if (a == null || !mounted) return;
    switch (a) {
      case _EmptyAction.newPlace:
        final name = await askText(context, title: l.planNewPlace);
        if (name == null) return;
        try {
          final p = await _repo.createPlace(
              objectId: widget.objectId,
              name: name,
              floorId: _floorId,
              x: fx,
              y: fy);
          setState(() => _highlight = p.key);
          _msg(l.planSaved, type: AppMessageType.success);
        } catch (e) {
          _fail(e);
        }
        await _reloadItems();
      case _EmptyAction.newAsset:
        final places = [
          for (final i in _items)
            if (i.isPlace) i
        ];
        if (places.isEmpty) {
          _msg(l.planNoPlaces);
          return;
        }
        final near =
            nearestPlace(_items, _floorId, fx, fy, planSize(_floor!)) ??
                places.first;
        final r = await showAppSheet<_AssetDraft>(
            context: context,
            builder: (_) => _AssetForm(places: places, initialPlace: near));
        if (r == null) return;
        try {
          final asset = await _repo.createAsset(
              locationId: r.placeId,
              name: r.name,
              category: r.category,
              inventoryNo: r.inventoryNo,
              floorId: _floorId,
              x: fx,
              y: fy);
          setState(() => _highlight = asset.key);
          _msg(l.planSaved, type: AppMessageType.success);
        } catch (e) {
          _fail(e);
        }
        await _reloadItems();
      case _EmptyAction.putHere:
        final pick = await showActionSheet<PlanItem>(context,
            title: l.planPickUnplaced,
            actions: [
              for (final i in unplaced)
                SheetAction(i, i.name, equipmentIcon(i)),
            ]);
        if (pick != null) await _move(pick, fx, fy);
    }
  }

  // ------------------------------------------------------------ вёрстка

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppNavBar(
        title: _obj == null ? l.planTitle : objectDisplayName(_obj!),
        // Открыли по ссылке — назад некуда: на главный экран.
        leading: canPop
            ? null
            : AppIconButton(
                icon: AppIcons.home,
                label: l.navHome,
                onPressed: () => context.go('/')),
        actions: [
          AppInfoButton(
            title: l.infoPlanTitle,
            lines: [l.infoPlan1, l.infoPlan2, l.infoPlan3],
            closeLabel: l.commonGotIt,
            semanticLabel: l.infoShowHint(l.infoPlanTitle),
          ),
          if (_isManager && !_editing && !_loading && !_notFound)
            // На узком экране — значок: название объекта в шапке не обрезается.
            MediaQuery.sizeOf(context).width < 600
                ? AppIconButton(
                    icon: AppIcons.edit,
                    label: l.planEdit,
                    onPressed: () => setState(() => _editing = true))
                : AppBarTextButton(
                    label: l.planEdit,
                    onPressed: () => setState(() => _editing = true)),
        ],
      ),
      body: _loading
          ? const AppLoader()
          : _failed
              ? AppEmptyState(
                  text: l.cardLoadFailed,
                  error: true,
                  actionLabel: l.commonRetry,
                  onAction: _load)
              : _notFound
                  ? AppEmptyState(text: l.planNotFound, icon: AppIcons.floors)
                  : _body(l),
    );
  }

  Widget _body(AppLocalizations l) {
    final floor = _floor!;
    // Телефон: снизу панель списка (~14 % высоты экрана плана).
    final bottomInset = _wide ? 0.0 : MediaQuery.sizeOf(context).height * 0.12;
    final now = DateTime.now();
    final stats = planStats(_orders, now);
    final visible = [
      for (final i in _items)
        if (i.isOn(_floorId) && planFilterShows(_filter, i, stats)) i
    ];
    final canvas = Stack(children: [
      Positioned.fill(
        child: PlanCanvas(
          floor: floor,
          items: visible,
          stats: stats,
          controller: _canvas,
          highlight: _highlight,
          initialFocus: widget.floorId == _floorId ? widget.focus : null,
          bottomInset: bottomInset,
          editing: _editing,
          labelOf: (i) => _itemLabel(l, i),
          onMarkerTap: (i) {
            setState(() => _highlight = i.key);
            _showMarker(i);
          },
          onEmptyTap: _emptyTap,
          onMoved: _move,
        ),
      ),
      if (!floor.hasPlan && !_editing)
        PositionedDirectional(
          top: 12,
          start: 12,
          end: 68,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _Pill(
              icon: AppIcons.imageOff,
              text: l.planNotLoaded,
              // Загрузить может только менеджер; у остальных — без кнопки.
              action: _isManager && !_editing
                  ? AppButton.primary(
                      label: l.floorUploadPlan,
                      icon: AppIcons.imageAdd,
                      small: true,
                      loading: _uploading,
                      onPressed: _uploadPlan)
                  : null,
            ),
          ),
        ),
      PositionedDirectional(
        top: 12,
        end: 12,
        child: Column(children: [
          MapControlButton(
              icon: AppIcons.zoomIn,
              label: l.mapZoomIn,
              onPressed: () => _canvas.zoomBy(1.6)),
          MapControlButton(
              icon: AppIcons.zoomOut,
              label: l.mapZoomOut,
              onPressed: () => _canvas.zoomBy(1 / 1.6)),
          MapControlButton(
              icon: AppIcons.fit, label: l.planFit, onPressed: _canvas.fit),
        ]),
      ),
    ]);

    final Widget main;
    if (_wide) {
      main = Row(children: [
        SizedBox(
            width: 360,
            child:
                ColoredBox(color: AppColors.bg, child: _list(l, stats, null))),
        const VerticalDivider(
            width: 0.5, thickness: 0.5, color: AppColors.separator),
        Expanded(child: canvas),
      ]);
    } else {
      main = Stack(children: [
        Positioned.fill(child: canvas),
        DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: 0.14,
          minChildSize: 0.1,
          maxChildSize: 0.75,
          snap: true,
          snapSizes: const [0.14, 0.45],
          builder: (context, scroll) => DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.bg,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
              boxShadow: AppShadows.floating,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.sheet)),
              child: Material(
                  type: MaterialType.transparency,
                  child: _list(l, stats, scroll)),
            ),
          ),
        ),
      ]);
    }

    return Column(children: [
      _toolbar(l, floor),
      if (_editing) _editBanner(l, floor),
      Expanded(child: main),
    ]);
  }

  Widget _toolbar(AppLocalizations l, Floor floor) {
    Widget chip(PlanFilter f, String label) => Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpace.s),
          child: AppChip(
              label: label,
              selected: _filter == f,
              onTap: () => setState(() => _filter = f)),
        );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.xs),
      child: Row(children: [
        Builder(
          builder: (anchor) => AppFilterChip(
            icon: AppIcons.floors,
            label: floor.name,
            chevron: _floors.length > 1,
            onTap: _floors.length > 1 ? () => _pickFloor(anchor) : null,
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: AppFadingScroll(
            child: Row(children: [
              chip(PlanFilter.all, l.planFilterAll),
              chip(PlanFilter.places, l.planFilterPlaces),
              chip(PlanFilter.assets, l.planFilterAssets),
              chip(PlanFilter.withOrders, l.planFilterWithOrders),
            ]),
          ),
        ),
      ]),
    );
  }

  /// Плашка режима расстановки: что делать и главные действия.
  Widget _editBanner(AppLocalizations l, Floor floor) {
    final unplaced = unplacedFor(_floorId, _items).length;
    return Container(
      key: const ValueKey('plan-edit-banner'),
      decoration: const BoxDecoration(
        color: AppColors.accentTint,
        border: Border(bottom: BorderSide(color: AppColors.accent, width: 2)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpace.screen, AppSpace.s, AppSpace.xs, AppSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(top: 2),
              child: Icon(AppIcons.move,
                  size: AppSizes.iconS, color: AppColors.accentText),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: l.planEditMode,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' — ${l.planEditHint}'),
                ]),
                style: AppText.callout.copyWith(color: AppColors.accentText),
              ),
            ),
            AppInfoButton(
              title: l.infoEditTitle,
              lines: [l.infoEdit1, l.infoEdit2, l.infoEdit3],
              closeLabel: l.commonGotIt,
              color: AppColors.accentText,
              semanticLabel: l.infoShowHint(l.infoEditTitle),
            ),
          ]),
          const SizedBox(height: AppSpace.s),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpace.s),
            child: Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppButton.secondary(
                    label:
                        floor.hasPlan ? l.floorReplacePlan : l.floorUploadPlan,
                    icon: AppIcons.imageAdd,
                    small: true,
                    loading: _uploading,
                    onPressed: _uploadPlan),
                AppButton.secondary(
                    label: l.planUnplaced(unplaced),
                    icon: AppIcons.place,
                    small: true,
                    onPressed: _pickUnplaced),
                AppButton.primary(
                    label: l.planDone,
                    small: true,
                    onPressed: () => setState(() => _editing = false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(AppLocalizations l, Map<String, ObjectStats> stats,
      ScrollController? scroll) {
    final q = _query.trim().toLowerCase();
    bool match(PlanItem i) => q.isEmpty || i.name.toLowerCase().contains(q);
    final on = [
      for (final i in _items)
        if (i.isOn(_floorId) && match(i)) i
    ];
    final off = [
      for (final i in unplacedFor(_floorId, _items))
        if (match(i)) i
    ];
    Widget row(PlanItem i) {
      final n = stats[i.key]?.open ?? 0;
      final place = i.isPlace ? null : _placeOf(i);
      return AppRow(
        leading: i.isPlace
            ? LeadingIcon(equipmentIcon(i))
            : LeadingIcon.neutral(equipmentIcon(i)),
        title: i.name,
        subtitle: [
          if (place != null) place.name,
          l.floorOpenOrders(n),
        ].join(' · '),
        chevron: false,
        trailing: i.key == _highlight
            ? const Icon(AppIcons.place,
                size: AppSizes.iconS, color: AppColors.accentText)
            : null,
        onTap: () => _focus(i),
      );
    }

    return ListView(
      controller: scroll,
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpace.screen, 0, AppSpace.screen, AppSpace.xl),
      children: [
        if (scroll != null) ...[
          const SheetGrabber(),
          // Панель снизу: нажатие на заголовок раскрывает / сворачивает
          // (мышью панель не тянется).
          Pressable(
            onTap: _toggleSheet,
            semanticLabel:
                '${l.planOnPlan(on.length)}, ${l.planUnplaced(off.length)}',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTap),
              child: Row(children: [
                Expanded(
                  child: Text(
                      '${l.planOnPlan(on.length)} · ${l.planUnplaced(off.length)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headline),
                ),
                const Icon(AppIcons.list2,
                    size: AppSizes.iconS, color: AppColors.secondary),
              ]),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s),
        AppSearchField(
            hint: l.planSearch, onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: AppSpace.s),
        AppGroup(header: l.planOnPlan(on.length), children: [
          if (on.isEmpty)
            AppRow(title: l.planMarkerHint, titleStyle: AppText.callout)
          else
            for (final i in on) row(i),
        ]),
        AppGroup(header: l.planUnplaced(off.length), children: [
          if (off.isEmpty)
            AppRow(title: l.planNothingUnplaced, titleStyle: AppText.callout)
          else
            for (final i in off) row(i),
        ]),
      ],
    );
  }
}

/// Плашка поверх плана («План не загружен»).
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;

  /// Кнопка справа в плашке («Загрузить план» у менеджера).
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.floating),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: AppSizes.iconS, color: AppColors.secondary),
          const SizedBox(width: AppSpace.s),
          Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.footnote.copyWith(color: AppColors.ink))),
          if (action != null) ...[
            const SizedBox(width: AppSpace.m),
            action!,
          ],
        ]),
      );
}

/// Новое оборудование: название, категория, инвентарный номер, помещение.
class _AssetDraft {
  const _AssetDraft(this.name, this.category, this.inventoryNo, this.placeId);
  final String name;
  final String category;
  final String? inventoryNo;
  final String placeId;
}

class _AssetForm extends StatefulWidget {
  const _AssetForm({required this.places, required this.initialPlace});
  final List<PlanItem> places;
  final PlanItem initialPlace;

  @override
  State<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends State<_AssetForm> {
  final _name = TextEditingController();
  final _inv = TextEditingController();
  String _category = 'equipment';
  late String _placeId = widget.initialPlace.id;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _inv.dispose();
    super.dispose();
  }

  void _done() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = context.l10n.planNameRequired);
      return;
    }
    Navigator.pop(context,
        _AssetDraft(_name.text.trim(), _category, _inv.text, _placeId));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
              title: l.planNewAsset, doneLabel: l.commonSave, onDone: _done),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _name,
                    autofocus: true,
                    maxLength: 120,
                    decoration: InputDecoration(
                        labelText: l.planNameLabel, errorText: _error),
                  ),
                  TextField(
                    controller: _inv,
                    maxLength: 60,
                    decoration:
                        InputDecoration(labelText: l.planInventoryLabel),
                  ),
                  SectionHeader(l.planAssetCategory),
                  Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
                    for (final c in const [
                      'equipment',
                      'infra',
                      'furniture',
                      'other'
                    ])
                      AppChip(
                          label: l.assetCategory(c),
                          selected: _category == c,
                          onTap: () => setState(() => _category = c)),
                  ]),
                  SectionHeader(l.planAssetPlace),
                  AppGroup(children: [
                    for (final p in widget.places)
                      AppCheckRow(
                        title: p.name,
                        selected: p.id == _placeId,
                        onTap: () => setState(() => _placeId = p.id),
                      ),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
