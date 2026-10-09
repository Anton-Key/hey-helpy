import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/location.dart';
import '../../core/scrolling.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../directory/object_card.dart';
import '../requests/requests.dart';
import 'map_config.dart';
import 'map_logic.dart';
import 'map_parts.dart';

/// С какой ширины список стоит слева от карты, а не в выдвижной панели.
const mapWideBreakpoint = 900.0;

/// Фильтр списка по области карты.
sealed class _Area {
  const _Area();
}

/// «Искать в этой области» — видимая часть карты на момент нажатия.
class _VisibleArea extends _Area {
  const _VisibleArea(this.rect);
  final GeoRect rect;
}

/// Выделенный рамкой прямоугольник.
class _RectArea extends _Area {
  const _RectArea(this.rect);
  final GeoRect rect;
}

/// «Объекты рядом»: круг вокруг точки.
class _CircleArea extends _Area {
  const _CircleArea(this.center, this.km);
  final GeoPoint center;
  final double km;
}

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);
GeoPoint _gp(LatLng p) => GeoPoint(p.latitude, p.longitude);

/// Режим «Карта» вкладки «Локации»: объекты компании на карте с числом
/// открытых заявок, список рядом (широкий экран) или в выдвижной панели
/// (телефон), поиск по области, рамке и радиусу, карточка объекта,
/// «Указать на карте» для менеджера.
class ObjectsMapView extends StatefulWidget {
  const ObjectsMapView(
      {super.key,
      required this.objects,
      required this.isManager,
      required this.companyId,
      required this.onReload,
      required this.onShowOrders});

  final List<Obj> objects;
  final bool isManager;
  final String? companyId;

  /// Перечитать объекты (после правки места или карточки объекта).
  final Future<void> Function() onReload;

  /// «Заявки»: список заявок с фильтром по объекту.
  final ValueChanged<Obj> onShowOrders;

  @override
  State<ObjectsMapView> createState() => _ObjectsMapViewState();
}

class _ObjectsMapViewState extends State<ObjectsMapView>
    with TickerProviderStateMixin {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  final _mapFocus = FocusNode(debugLabel: 'objects-map');
  final _requests = RequestsRepo();

  AnimationController? _fly;
  bool _mapReady = false;
  bool _wide = true;

  Map<String, ObjectStats> _stats = const {};
  bool _ordersFailed = false;

  String? _selectedId;
  _Area? _area;

  /// Карту подвинули рукой — показать «Искать в этой области».
  bool _moved = false;

  /// Кнопка «Выделить область» нажата.
  bool _rectMode = false;

  /// Зажат Shift: перетаскивание мышью рисует рамку.
  bool _shift = false;
  Offset? _dragFrom;
  Offset? _dragTo;

  /// Объект, которому выбираем место на карте (перекрестие по центру).
  Obj? _placing;
  bool _saving = false;

  GeoPoint? _me;
  bool _locating = false;

  /// Чип города над картой: null — «Все».
  String? _city;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant ObjectsMapView old) {
    super.didUpdateWidget(old);
    if (_selectedId != null && _object(_selectedId!) == null) {
      _selectedId = null;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _fly?.dispose();
    _sheet.dispose();
    _search.dispose();
    _mapFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (shift != _shift && mounted) setState(() => _shift = shift);
    return false;
  }

  Future<void> _loadStats() async {
    try {
      final rows = await _requests.mapOrders();
      if (!mounted) return;
      setState(() {
        _stats = ObjectStats.byObject(
            rows.map(MapOrder.fromMap), DateTime.now().toUtc());
        _ordersFailed = false;
      });
    } catch (e) {
      debugPrint('mapOrders: $e');
      if (mounted) setState(() => _ordersFailed = true);
    }
  }

  // ---------------------------------------------------------------- данные

  Obj? _object(String id) {
    for (final o in widget.objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  ObjectStats _statsOf(String id) => _stats[id] ?? ObjectStats.empty;

  List<MapItem<Obj>> get _items => [
        for (final o in widget.objects)
          if (o.hasCoordinates)
            MapItem(id: o.id, point: GeoPoint(o.lat!, o.lng!), value: o),
      ];

  /// Объекты для списка с учётом поиска и области; для круга — с расстоянием.
  List<(Obj, double?)> _listed() {
    final items = [
      for (final i in _items)
        if (matchesQuery(_search.text, i.value.name, i.value.address)) i,
    ];
    return switch (_area) {
      null => [for (final i in items) (i.value, null)],
      _VisibleArea(:final rect) || _RectArea(:final rect) => [
          for (final i in itemsInRect(items, rect)) (i.value, null)
        ],
      _CircleArea(:final center, :final km) => [
          for (final (i, d) in itemsInCircle(items, center, km * 1000))
            (i.value, d)
        ],
    };
  }

  List<Obj> _unplaced() => [
        for (final o in widget.objects)
          if (!o.hasCoordinates &&
              matchesQuery(_search.text, o.name, o.address))
            o,
      ];

  String _km(double km) {
    final f = NumberFormat(km < 10 ? '0.#' : '0', context.l10n.localeName);
    return context.l10n.mapKm(f.format(km));
  }

  String _distance(double m) {
    if (m < 1000) return context.l10n.cardMeters('${m.round()}');
    return _km(m / 1000);
  }

  // ---------------------------------------------------------------- камера

  void _flyTo(LatLng to, double zoom) {
    if (!_mapReady) return;
    final cam = _map.camera;
    _fly?.dispose();
    final c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fly = c;
    final curve = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    final lat = Tween(begin: cam.center.latitude, end: to.latitude);
    final lng = Tween(begin: cam.center.longitude, end: to.longitude);
    final z = Tween(
        begin: cam.zoom, end: zoom.clamp(mapMinZoom, mapMaxZoom).toDouble());
    c.addListener(() => _map.move(
        LatLng(lat.evaluate(curve), lng.evaluate(curve)), z.evaluate(curve)));
    c.forward();
  }

  /// Отступы при «показать всё»: снизу на телефоне — выдвижная панель.
  EdgeInsets get _fitPadding {
    final h = MediaQuery.sizeOf(context).height;
    return EdgeInsets.fromLTRB(60, 80, 80, _wide ? 60 : h * 0.35);
  }

  void _fitPoints(List<GeoPoint> points, {double maxZoom = 16}) {
    final b = boundsOf(points);
    if (b == null || !_mapReady) return;
    if (b.isTiny) {
      _flyTo(LatLng(b.south, b.west), math.max(_map.camera.zoom, 15));
      return;
    }
    final cam = CameraFit.bounds(
            bounds:
                LatLngBounds(LatLng(b.south, b.west), LatLng(b.north, b.east)),
            padding: _fitPadding,
            maxZoom: maxZoom)
        .fit(_map.camera);
    _flyTo(cam.center, cam.zoom);
  }

  void _fitAll() => _fitPoints([for (final i in _items) i.point]);

  /// Чип города: плавно приблизить к объектам города; «Все» — весь мир.
  void _showCity(String? city) {
    setState(() => _city = city);
    if (city == null) {
      _fitAll();
      return;
    }
    _fitPoints([
      for (final i in _items)
        if (cityOf(i.value.address) == city) i.point
    ], maxZoom: 15);
  }

  /// Чипы «Все · Абиджан · Белград · …» с числом открытых заявок.
  Widget _cityChips(AppLocalizations l) {
    final groups = groupObjectsByCity([for (final i in _items) i.value])
        .where((g) => g.city.isNotEmpty)
        .toList();
    if (groups.length < 2) return const SizedBox.shrink();
    int open(Iterable<Obj> list) =>
        list.fold(0, (sum, o) => sum + _statsOf(o.id).open);
    Widget chip(String? city, String label) => Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpace.s),
          child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadows.floating),
            child: AppChip(
                label: label,
                selected: _city == city,
                onTap: () => _showCity(city)),
          ),
        );
    final all = open([for (final g in groups) ...g.items]);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Тень чипов не обрезается.
      padding: const EdgeInsetsDirectional.only(bottom: 6, end: 6),
      clipBehavior: Clip.none,
      child: Row(children: [
        chip(null, all > 0 ? l.cityCount(l.cityAll, all) : l.cityAll),
        for (final g in groups)
          chip(g.city,
              open(g.items) > 0 ? l.cityCount(g.city, open(g.items)) : g.city),
      ]),
    );
  }

  void _zoomBy(double d) {
    if (!_mapReady) return;
    final cam = _map.camera;
    _flyTo(cam.center, (cam.zoom + d).roundToDouble());
  }

  // ---------------------------------------------------------------- действия

  /// Доля высоты карты под выдвижной панелью, когда открыта карточка объекта.
  static const _sheetWithCard = 0.55;

  void _select(Obj o) {
    setState(() => _selectedId = o.id);
    if (o.hasCoordinates && _mapReady) {
      final zoom = math.max(_map.camera.zoom, 15).toDouble();
      final point = LatLng(o.lat!, o.lng!);
      if (_wide) {
        _flyTo(point, zoom);
      } else {
        // На телефоне низ карты закрыт панелью с карточкой: объект ставим
        // в середину видимой части — центр карты ниже него.
        final cam = _map.camera.withPosition(center: point, zoom: zoom);
        final size = cam.nonRotatedSize;
        _flyTo(
            cam.screenOffsetToLatLng(Offset(size.width / 2,
                size.height / 2 + size.height * _sheetWithCard / 2)),
            zoom);
      }
    }
    if (!_wide && _sheet.isAttached) {
      _sheet.animateTo(_sheetWithCard,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _clearSelection() => setState(() => _selectedId = null);

  void _searchHere() {
    if (!_mapReady) return;
    final b = _map.camera.visibleBounds;
    setState(() {
      _area = _VisibleArea(
          GeoRect(south: b.south, west: b.west, north: b.north, east: b.east));
      _moved = false;
    });
  }

  void _resetArea() => setState(() {
        _area = null;
        _moved = false;
      });

  void _nearby(LatLng p) {
    if (_placing != null) return;
    final prev = _area;
    setState(() {
      _area =
          _CircleArea(_gp(p), prev is _CircleArea ? prev.km : nearbyDefaultKm);
      _selectedId = null;
      _rectMode = false;
    });
  }

  void _finishRect() {
    final from = _dragFrom, to = _dragTo;
    setState(() {
      _dragFrom = null;
      _dragTo = null;
    });
    if (from == null || to == null || !_mapReady) return;
    if ((from - to).distance < 8) return;
    final cam = _map.camera;
    final rect = GeoRect.fromCorners(
        _gp(cam.screenOffsetToLatLng(from)), _gp(cam.screenOffsetToLatLng(to)));
    if (rect.isTiny) return;
    setState(() {
      _area = _RectArea(rect);
      _rectMode = false;
      _selectedId = null;
    });
  }

  Future<void> _locate() async {
    final l = context.l10n;
    setState(() => _locating = true);
    final ok = await ensureLocationPermission();
    final pos = ok ? await currentPosition() : null;
    if (!mounted) return;
    setState(() => _locating = false);
    if (pos == null) {
      showAppMessage(context, l.mapMyLocationFailed,
          type: AppMessageType.error);
      return;
    }
    setState(() => _me = GeoPoint(pos.latitude, pos.longitude));
    _flyTo(LatLng(pos.latitude, pos.longitude), math.max(_map.camera.zoom, 14));
  }

  Future<void> _openObject(Obj o) async {
    await Navigator.push(
        context,
        appRoute((_) => ObjectCardScreen(object: o),
            title: context.l10n.tabLocations));
    if (!mounted) return;
    await Future.wait([widget.onReload(), _loadStats()]);
  }

  Future<void> _createHere(Obj o) async {
    final l = context.l10n;
    final companyId = widget.companyId;
    if (companyId == null) {
      showAppMessage(context, l.requestsNoCompany, type: AppMessageType.error);
      return;
    }
    final ok = await showOrderForm(
        context: context,
        repo: _requests,
        objects: widget.objects,
        companyId: companyId,
        initialObjectId: o.id);
    if (ok == true && mounted) {
      showAppMessage(context, l.requestsCreated, type: AppMessageType.success);
      await _loadStats();
    }
  }

  void _startPlacing(Obj o) {
    setState(() {
      _placing = o;
      _selectedId = o.hasCoordinates ? o.id : null;
      _rectMode = false;
      _moved = false;
    });
    if (o.hasCoordinates) _flyTo(LatLng(o.lat!, o.lng!), 17);
  }

  Future<void> _savePlace() async {
    final o = _placing;
    if (o == null || !_mapReady) return;
    final l = context.l10n;
    final c = _map.camera.center;
    setState(() => _saving = true);
    try {
      await DirectoryRepo().updateObjectGeo(o.id,
          address: o.address,
          lat: double.parse(c.latitude.toStringAsFixed(6)),
          lng: double.parse(c.longitude.toStringAsFixed(6)),
          radiusM: o.geofenceRadiusM);
      if (!mounted) return;
      setState(() {
        _placing = null;
        _saving = false;
        _selectedId = o.id;
      });
      showAppMessage(context, l.mapPlaceSaved, type: AppMessageType.success);
      await widget.onReload();
    } catch (e) {
      debugPrint('savePlace: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showAppMessage(context, l.saveFailed, type: AppMessageType.error);
    }
  }

  // ---------------------------------------------------------------- вёрстка

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _wide = c.maxWidth >= mapWideBreakpoint;
      final map = _mapStack(context);
      if (_wide) {
        return Row(children: [
          SizedBox(
              width: 360,
              child: ColoredBox(color: AppColors.bg, child: _panel(null))),
          const VerticalDivider(
              width: 0.5, thickness: 0.5, color: AppColors.separator),
          Expanded(child: map),
        ]);
      }
      return Stack(children: [
        Positioned.fill(child: map),
        if (_placing == null)
          DraggableScrollableSheet(
            controller: _sheet,
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.32, _sheetWithCard],
            builder: (context, scroll) => DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet)),
                boxShadow: AppShadows.floating,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet)),
                child: Material(
                    type: MaterialType.transparency, child: _panel(scroll)),
              ),
            ),
          ),
      ]);
    });
  }

  /// Список объектов: слева (широкий экран) или в выдвижной панели.
  Widget _panel(ScrollController? scroll) {
    final l = context.l10n;
    final listed = _listed();
    final unplaced = _unplaced();
    final selected = _selectedId == null ? null : _object(_selectedId!);
    final area = _area;
    final areaText = switch (area) {
      null => null,
      _VisibleArea() => l.mapInArea(listed.length),
      _RectArea() => l.mapInRect(listed.length),
      _CircleArea(:final km) => l.mapNearby(listed.length, _km(km)),
    };
    return ListView(
      controller: scroll,
      padding: EdgeInsetsDirectional.fromSTEB(
          AppSpace.screen,
          scroll != null ? 0 : AppSpace.m,
          AppSpace.screen,
          AppSpace.xl + MediaQuery.paddingOf(context).bottom),
      children: [
        if (scroll != null)
          const Padding(
            padding: EdgeInsetsDirectional.only(bottom: AppSpace.s),
            child: SheetGrabber(),
          ),
        // На телефоне карточка выбранного объекта — сверху панели.
        if (!_wide && selected != null)
          AppCard(
            padding: const EdgeInsets.all(AppSpace.l),
            child: _infoCard(selected),
          ),
        AppSearchField(
          controller: _search,
          hint: l.mapSearchHint,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.m),
        if (areaText != null)
          Container(
            margin: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
            decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.field)),
            child: Row(children: [
              Icon(area is _CircleArea ? AppIcons.nearby : AppIcons.area,
                  size: AppSizes.iconS, color: AppColors.accentText),
              const SizedBox(width: AppSpace.s),
              Expanded(
                  child: Text(areaText,
                      style: AppText.footnote.copyWith(
                          color: AppColors.accentText,
                          fontWeight: FontWeight.w600))),
              AppButton.plain(
                  label: l.mapReset,
                  icon: AppIcons.close,
                  small: true,
                  onPressed: _resetArea),
            ]),
          )
        else
          SectionHeader(l.mapListTitle(listed.length),
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.rowH, AppSpace.xs, AppSpace.rowH, AppSpace.s)),
        if (_ordersFailed)
          Padding(
            padding: const EdgeInsetsDirectional.only(
                bottom: AppSpace.s, start: AppSpace.rowH),
            child: Text(l.mapOrdersFailed,
                style: AppText.caption.copyWith(color: AppColors.danger)),
          ),
        if (listed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
            child: Text(l.mapNothingFound,
                textAlign: TextAlign.center,
                style: AppText.callout.copyWith(color: AppColors.secondary)),
          ),
        if (listed.isNotEmpty && area is _CircleArea)
          // «Объекты рядом» — по удалённости, город в названии.
          AppGroup(
            separatorInset: AppSpace.separatorInsetIcon,
            children: [
              for (final (o, d) in listed)
                ObjectMapRow(
                  object: o,
                  stats: _statsOf(o.id),
                  selected: o.id == _selectedId,
                  distanceText: d == null ? null : _distance(d),
                  withCity: true,
                  onTap: () => _select(o),
                ),
            ],
          ),
        if (listed.isNotEmpty && area is! _CircleArea)
          // Секции по городам: «МОСКВА · 5».
          for (final g in groupByCity(listed,
              address: (e) => e.$1.address, name: (e) => e.$1.name))
            AppGroup(
              header: l.cityCount(
                  g.city.isEmpty ? l.cityNone : g.city, g.items.length),
              separatorInset: AppSpace.separatorInsetIcon,
              children: [
                for (final (o, _) in g.items)
                  ObjectMapRow(
                    object: o,
                    stats: _statsOf(o.id),
                    selected: o.id == _selectedId,
                    onTap: () => _select(o),
                  ),
              ],
            ),
        if (unplaced.isNotEmpty)
          AppGroup(
            header: l.mapNoCoordinates(unplaced.length),
            separatorInset: AppSpace.separatorInsetIcon,
            children: [
              for (final o in unplaced)
                UnplacedRow(
                    object: o,
                    isManager: widget.isManager,
                    onPlace: () => _startPlacing(o)),
            ],
          ),
        Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.rowH),
          child: Text(l.mapNearbyHelp, style: AppText.caption),
        ),
      ],
    );
  }

  Widget _infoCard(Obj o) => ObjectInfoCard(
        object: o,
        stats: _statsOf(o.id),
        isManager: widget.isManager,
        onOpen: () => _openObject(o),
        onOrders: () => widget.onShowOrders(o),
        onCreate: () => _createHere(o),
        onMove: () => _startPlacing(o),
        onClose: _clearSelection,
      );

  Widget _mapStack(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    final selected = _selectedId == null ? null : _object(_selectedId!);
    final area = _area;
    final drawing = _rectMode || _shift || _dragFrom != null;
    final bounds = boundsOf(items.map((i) => i.point));
    final placing = _placing;

    const noRotate = InteractiveFlag.all & ~InteractiveFlag.rotate;
    final options = MapOptions(
      // Нет объектов — Белград (демо); один — сразу к нему; несколько — рамка.
      initialCenter: bounds == null
          ? const LatLng(44.8125, 20.4612)
          : LatLng(bounds.south, bounds.west),
      initialZoom: bounds == null ? 11 : 15,
      initialCameraFit: bounds == null || bounds.isTiny
          ? null
          : CameraFit.bounds(
              bounds: LatLngBounds(LatLng(bounds.south, bounds.west),
                  LatLng(bounds.north, bounds.east)),
              padding: const EdgeInsets.fromLTRB(60, 80, 80, 80),
              maxZoom: 15),
      minZoom: mapMinZoom,
      maxZoom: mapMaxZoom,
      backgroundColor: AppColors.bg,
      interactionOptions: InteractionOptions(
        flags: drawing ? noRotate & ~InteractiveFlag.drag : noRotate,
        keyboardOptions: KeyboardOptions(focusNode: _mapFocus),
      ),
      onMapReady: () => _mapReady = true,
      onPointerDown: (_, __) {
        _fly?.stop();
        _mapFocus.requestFocus();
      },
      onTap: (_, __) {
        if (_selectedId != null && _placing == null) _clearSelection();
      },
      onSecondaryTap: (_, p) => _nearby(p),
      onLongPress: (_, p) => _nearby(p),
      onPositionChanged: (_, gesture) {
        if (gesture && !_moved && _placing == null) {
          setState(() => _moved = true);
        }
      },
    );

    return KeyboardScrollBlocker(
      child: Stack(children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: options,
            children: [
              TileLayer(
                urlTemplate: mapTileUrl,
                subdomains: mapTileSubdomains,
                userAgentPackageName: mapUserAgentPackage,
                retinaMode: RetinaMode.isHighDensity(context),
                maxNativeZoom: mapTileMaxNativeZoom,
              ),
              if (area is _RectArea)
                PolygonLayer(polygons: [
                  Polygon(
                    points: [
                      LatLng(area.rect.south, area.rect.west),
                      LatLng(area.rect.north, area.rect.west),
                      LatLng(area.rect.north, area.rect.east),
                      LatLng(area.rect.south, area.rect.east),
                    ],
                    color: AppColors.accent.withValues(alpha: 0.10),
                    borderColor: AppColors.accentText,
                    borderStrokeWidth: 2,
                  ),
                ]),
              CircleLayer(circles: [
                if (area is _CircleArea)
                  CircleMarker(
                    point: _ll(area.center),
                    radius: area.km * 1000,
                    useRadiusInMeter: true,
                    color: AppColors.accent.withValues(alpha: 0.10),
                    borderColor: AppColors.accentText,
                    borderStrokeWidth: 2,
                  ),
                if (selected != null &&
                    selected.hasCoordinates &&
                    placing == null)
                  CircleMarker(
                    point: LatLng(selected.lat!, selected.lng!),
                    radius: selected.geofenceRadiusM.toDouble(),
                    useRadiusInMeter: true,
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderColor: AppColors.accent,
                    borderStrokeWidth: 1.5,
                  ),
              ]),
              if (area is _CircleArea)
                MarkerLayer(markers: [
                  Marker(
                      point: _ll(area.center),
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.accentText,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.surface, width: 2)),
                      )),
                ]),
              if (_me != null)
                MarkerLayer(markers: [
                  Marker(
                      point: _ll(_me!),
                      width: 22,
                      height: 22,
                      child: const MeDot()),
                ]),
              if (placing == null)
                _ClusteredMarkers(
                  items: items,
                  stats: _stats,
                  selectedId: _selectedId,
                  onObject: _select,
                  onCluster: (c) => _fitPoints(
                      [for (final i in c.items) i.point],
                      maxZoom: clusterMaxZoom + 1),
                ),
              SimpleAttributionWidget(
                source: Text(mapAttribution),
                backgroundColor: AppColors.surface.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
        if (drawing && placing == null) Positioned.fill(child: _rectOverlay()),
        if (placing != null) const _Crosshair(),

        // Сверху слева: «Искать в этой области», радиус «Объекты рядом»,
        // подсказка режима рамки.
        PositionedDirectional(
          top: 12,
          start: 12,
          end: 68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (placing == null) ...[
                _cityChips(l),
                const SizedBox(height: AppSpace.xs),
              ],
              if (placing != null)
                _Banner(text: l.mapPlaceHint(placing.name))
              else if (_rectMode)
                _Banner(text: l.mapSelectAreaHint)
              else if (_moved)
                DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: AppShadows.floating),
                  child: AppButton.primary(
                      label: l.mapSearchHere,
                      icon: AppIcons.searchArea,
                      small: true,
                      expand: false,
                      onPressed: _searchHere),
                ),
              if (area is _CircleArea && placing == null) ...[
                const SizedBox(height: AppSpace.s),
                _RadiusCard(
                  km: area.km,
                  label: _km(area.km),
                  onChanged: (v) =>
                      setState(() => _area = _CircleArea(area.center, v)),
                  onClose: _resetArea,
                ),
              ],
            ],
          ),
        ),

        // Справа сверху: зум, «показать всё», «где я», рамка.
        PositionedDirectional(
          top: 12,
          end: 12,
          child: Column(children: [
            MapControlButton(
                icon: AppIcons.zoomIn,
                label: l.mapZoomIn,
                onPressed: () => _zoomBy(1)),
            MapControlButton(
                icon: AppIcons.zoomOut,
                label: l.mapZoomOut,
                onPressed: () => _zoomBy(-1)),
            if (placing == null) ...[
              MapControlButton(
                  icon: AppIcons.fit,
                  label: l.mapFitAll,
                  onPressed: items.isEmpty ? null : _fitAll),
              MapControlButton(
                  icon: AppIcons.locate,
                  label: l.mapMyLocation,
                  busy: _locating,
                  onPressed: _locating ? null : _locate),
              MapControlButton(
                  icon: AppIcons.area,
                  label: l.mapSelectArea,
                  active: _rectMode,
                  onPressed: () => setState(() => _rectMode = !_rectMode)),
            ],
          ]),
        ),

        if (_wide && selected != null && placing == null)
          PositionedDirectional(
            start: 12,
            bottom: 28,
            width: 360,
            child: Container(
              padding: const EdgeInsets.all(AppSpace.l),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.group),
                  boxShadow: AppShadows.floating),
              child: _infoCard(selected),
            ),
          ),

        if (placing != null)
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 28,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.m),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.group),
                      boxShadow: AppShadows.floating),
                  child: Row(children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: l.commonCancel,
                        onPressed: _saving
                            ? null
                            : () => setState(() => _placing = null),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    Expanded(
                      child: AppButton.primary(
                        label: l.mapSaveHere,
                        icon: AppIcons.check,
                        loading: _saving,
                        onPressed: _savePlace,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  /// Слой поверх карты для рамки: мышь (кнопка или Shift) или палец.
  Widget _rectOverlay() {
    final from = _dragFrom, to = _dragTo;
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.mouse &&
              e.buttons & kPrimaryMouseButton == 0) {
            return;
          }
          setState(() {
            _dragFrom = e.localPosition;
            _dragTo = e.localPosition;
          });
        },
        onPointerMove: (e) {
          if (_dragFrom != null) setState(() => _dragTo = e.localPosition);
        },
        onPointerUp: (_) => _finishRect(),
        onPointerCancel: (_) => setState(() {
          _dragFrom = null;
          _dragTo = null;
        }),
        child: Stack(children: [
          if (from != null && to != null)
            Positioned.fromRect(
              rect: Rect.fromPoints(from, to),
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.accentText, width: 2),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Маркеры объектов с группировкой по сетке (map_logic.clusterByGrid):
/// пересчитываются при каждом изменении зума.
class _ClusteredMarkers extends StatelessWidget {
  const _ClusteredMarkers(
      {required this.items,
      required this.stats,
      required this.selectedId,
      required this.onObject,
      required this.onCluster});
  final List<MapItem<Obj>> items;
  final Map<String, ObjectStats> stats;
  final String? selectedId;
  final ValueChanged<Obj> onObject;
  final ValueChanged<MapCluster<Obj>> onCluster;

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    // Мелкий масштаб — один кружок на город с подписью; крупнее — по сетке.
    final clusters =
        clusterMap(items, zoom, cityOf: (Obj o) => cityOf(o.address));
    // Выбранный — последним, чтобы был поверх соседей.
    clusters.sort((a, b) {
      int rank(MapCluster<Obj> c) =>
          c.isSingle && c.label == null && c.items.first.id == selectedId
              ? 1
              : 0;
      return rank(a) - rank(b);
    });
    return MarkerLayer(markers: [
      for (final c in clusters)
        if (c.isSingle && c.label == null)
          Marker(
            key: ValueKey(c.key),
            point: _ll(c.center),
            width: ObjectMarker.selectedSize + 4,
            height: ObjectMarker.selectedSize + 4,
            child: ObjectMarker(
              name: objectDisplayName(c.items.first.value),
              stats: stats[c.items.first.id] ?? ObjectStats.empty,
              selected: c.items.first.id == selectedId,
              onTap: () => onObject(c.items.first.value),
            ),
          )
        else
          Marker(
            key: ValueKey(c.key),
            point: _ll(c.center),
            width: c.label == null
                ? ClusterMarker.size + 4
                : ClusterMarker.labelWidth,
            height: ClusterMarker.size +
                4 +
                (c.label == null ? 0 : 2 * ClusterMarker.labelHeight),
            child: ClusterMarker(
              city: c.label,
              objects: c.items.length,
              open: c.items.fold(
                  0, (sum, i) => sum + (stats[i.id] ?? ObjectStats.empty).open),
              tone: worstTone(c.items
                  .map((i) => markerTone(stats[i.id] ?? ObjectStats.empty))),
              onTap: () => onCluster(c),
            ),
          ),
    ]);
  }
}

/// Перекрестие в центре карты (режим «Указать на карте»).
class _Crosshair extends StatelessWidget {
  const _Crosshair();
  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: Center(
          child: Stack(alignment: Alignment.center, children: [
            Icon(AppIcons.add, size: 56, color: AppColors.surface),
            Icon(AppIcons.add, size: 48, color: AppColors.ink),
            SizedBox(
              width: 14,
              height: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
              ),
            ),
          ]),
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.m, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.field),
            boxShadow: AppShadows.floating),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(AppIcons.info,
              size: AppSizes.iconS, color: AppColors.accentText),
          const SizedBox(width: AppSpace.s),
          Flexible(
            child: Text(text,
                style: AppText.footnote.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// Ползунок радиуса «Объекты рядом» (0,5–20 км, шаг 0,5).
class _RadiusCard extends StatelessWidget {
  const _RadiusCard(
      {required this.km,
      required this.label,
      required this.onChanged,
      required this.onClose});
  final double km;
  final String label;
  final ValueChanged<double> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 4),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.group),
            boxShadow: AppShadows.floating),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(AppIcons.nearby,
                size: AppSizes.iconS, color: AppColors.accentText),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Text('${l.mapNearbyTitle} · $label',
                  style: AppText.callout.copyWith(fontWeight: FontWeight.w600)),
            ),
            AppIconButton(
                icon: AppIcons.close,
                label: l.mapReset,
                filled: true,
                size: 30,
                onPressed: onClose),
          ]),
          Slider(
            value: km.clamp(nearbyMinKm, nearbyMaxKm),
            min: nearbyMinKm,
            max: nearbyMaxKm,
            divisions: ((nearbyMaxKm - nearbyMinKm) / 0.5).round(),
            label: label,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.fill,
            onChanged: onChanged,
          ),
        ]),
      ),
    );
  }
}
