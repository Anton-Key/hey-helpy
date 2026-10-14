import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/scrolling.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../directory/object_card.dart';
import '../equipment/asset_place.dart';
import '../equipment/equipment_kinds.dart';
import 'floor_models.dart';
import 'floor_repository.dart';
import 'plan_canvas.dart' show AreaPainter;
import 'plan_image.dart';
import 'plan_logic.dart';
import 'point_picker_logic.dart';

/// Итог экрана выбора точки: точка (или «убрать с плана» — [point] null)
/// и, если человек согласился, новое помещение по точке.
class PlanPointResult {
  const PlanPointResult({this.point, this.locationId});

  /// null — «Убрать с плана».
  final PlanPoint? point;

  /// Помещение сменить на это (точка попала в его контур); null — как было.
  final String? locationId;
}

/// Экран «Место на плане» (шаг 27): план этажа помещения, приближен к
/// контуру помещения, маркер оборудования можно тянуть (на телефоне — с
/// лупой над пальцем) или поставить нажатием. «Готово» / «Отмена» /
/// «Убрать с плана». null — отмена.
Future<PlanPointResult?> pickPlanPoint(
  BuildContext context, {
  required String objectId,
  required String assetName,
  String? assetId,
  String? locationId,
  PlanPoint? current,
  String? kind,
  String category = 'equipment',
  bool isManager = true,
}) =>
    Navigator.push<PlanPointResult>(
        context,
        appRoute(
            (_) => PlanPointPickerScreen(
                objectId: objectId,
                assetName: assetName,
                assetId: assetId,
                locationId: locationId,
                current: current,
                kind: kind,
                category: category,
                isManager: isManager),
            title: context.l10n.eqPlaceOnPlan));

class PlanPointPickerScreen extends StatefulWidget {
  const PlanPointPickerScreen({
    super.key,
    required this.objectId,
    required this.assetName,
    this.assetId,
    this.locationId,
    this.current,
    this.kind,
    this.category = 'equipment',
    this.isManager = true,
    this.repo,
  });

  final String objectId;
  final String assetName;

  /// null — новое оборудование (ещё не сохранено).
  final String? assetId;
  final String? locationId;
  final PlanPoint? current;
  final String? kind;
  final String category;
  final bool isManager;
  final FloorRepo? repo;

  @override
  State<PlanPointPickerScreen> createState() => _PlanPointPickerScreenState();
}

class _PlanPointPickerScreenState extends State<PlanPointPickerScreen> {
  late final FloorRepo _repo = widget.repo ?? FloorRepo();
  final _tc = TransformationController();

  bool _loading = true;
  bool _failed = false;
  List<Floor> _floors = const [];
  List<PlanItem> _items = const [];
  Floor? _floor;

  /// Точка маркера (доли 0..1) на этаже [_floor].
  (double, double) _point = (0.5, 0.5);

  /// Помещение оборудования (может смениться по предложению).
  late String? _locationId = widget.locationId;

  /// Предложение «точка в помещении …» и помещение, от которого отказались.
  PlanItem? _suggest;
  String? _declined;

  Size _viewport = Size.zero;
  bool _fitted = false;

  /// Перетаскивание пальцем: показать лупу.
  bool _dragging = false;
  bool _magnify = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await Future.wait<Object>([
        _repo.floorsOf(widget.objectId),
        _repo.itemsOf(widget.objectId),
      ]);
      if (!mounted) return;
      final floors = r[0] as List<Floor>;
      final items = r[1] as List<PlanItem>;
      setState(() {
        _floors = floors;
        _items = items;
        _loading = false;
      });
      _selectFloor(initialPickerFloor(floors,
          ownFloorId: widget.current?.floorId, roomFloorId: _room?.floorId));
    } catch (e) {
      debugPrint('PlanPointPicker: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  PlanItem? _placeById(String? id) {
    if (id == null) return null;
    for (final i in _items) {
      if (i.isPlace && i.id == id) return i;
    }
    return null;
  }

  PlanItem? get _room => _placeById(_locationId);

  List<Floor> get _planFloors => [
        for (final f in sortFloors(_floors))
          if (f.hasPlan) f
      ];

  void _selectFloor(Floor? f) {
    final cur = widget.current;
    setState(() {
      _floor = f;
      _fitted = false;
      _suggest = null;
      if (f != null) {
        _point = initialPickerPoint(f.id,
            own: cur == null ? null : (cur.floorId, cur.x, cur.y), room: _room);
      }
    });
  }

  Size get _plan => planSize(_floor!);
  double get _scale => _tc.value.getMaxScaleOnAxis();
  Offset get _translation {
    final t = _tc.value.getTranslation();
    return Offset(t.x, t.y);
  }

  double get _fitScale => planFitScale(_viewport, _plan, margin: 8);

  void _fit() {
    final floor = _floor;
    if (floor == null || _viewport.isEmpty) return;
    final room = _room;
    final focus = pickerFocusRect(_plan,
        shape: room != null && room.hasAreaOn(floor.id) ? room.shape : null,
        point: _point);
    final s = pickerScale(focus, _viewport,
        margin: 24, minScale: _fitScale, maxScale: _fitScale * 8);
    final t = pickerTranslation(focus, s, _viewport);
    _tc.value = Matrix4.identity()
      ..translateByDouble(t.dx, t.dy, 0, 1)
      ..scaleByDouble(s, s, s, 1);
  }

  void _setPoint((double, double) p, {bool settle = true}) {
    setState(() {
      _point = p;
      if (settle) _checkRoom();
    });
  }

  /// Точка в контуре другого помещения — предложить сменить (не молча).
  void _checkRoom() {
    final floor = _floor;
    if (floor == null) return;
    final hit =
        otherRoomAt(_items, floor.id, _point.$1, _point.$2, _plan, _locationId);
    _suggest = hit != null && hit.id != _declined ? hit : null;
  }

  void _done() {
    final floor = _floor;
    if (floor == null) return;
    Navigator.pop(
        context,
        PlanPointResult(
          point: PlanPoint(floor.id, _point.$1, _point.$2).rounded(),
          locationId: _locationId != widget.locationId ? _locationId : null,
        ));
  }

  void _clear() => Navigator.pop(context, const PlanPointResult());

  Future<void> _openObject() async {
    final obj = await DirectoryRepo().object(widget.objectId);
    if (obj == null || !mounted) return;
    await Navigator.push(
        context,
        appRoute((_) => ObjectCardScreen(object: obj),
            title: context.l10n.eqPlaceOnPlan));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ready = !_loading && !_failed && _floor != null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppNavBar(
        title: l.eqPlaceOnPlan,
        leading: AppBarTextButton(
            label: l.commonCancel, onPressed: () => Navigator.pop(context)),
        actions: [
          if (ready)
            AppBarTextButton(
                label: l.eqPlaceDone, strong: true, onPressed: _done),
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
              : _floor == null
                  ? AppEmptyState(
                      icon: AppIcons.floors,
                      text: l.eqPlaceNoPlan,
                      actionLabel:
                          widget.isManager ? l.eqPlaceOpenObject : null,
                      onAction: widget.isManager ? _openObject : null)
                  : Column(children: [
                      Expanded(child: _canvas(l)),
                      _panel(l),
                    ]),
    );
  }

  // ------------------------------------------------------------------ холст

  Widget _canvas(AppLocalizations l) {
    final floor = _floor!;
    final plan = _plan;
    return LayoutBuilder(builder: (context, c) {
      final vp = c.biggest;
      if (vp != _viewport) {
        _viewport = vp;
        if (!_fitted && !vp.isEmpty) {
          _fitted = true;
          _fit();
        }
      } else if (!_fitted && !vp.isEmpty) {
        _fitted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(_fit);
        });
      }
      return KeyboardScrollBlocker(
        child: ClipRect(
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
            Positioned.fill(
              child: InteractiveViewer(
                key: ValueKey(floor.id),
                transformationController: _tc,
                constrained: false,
                boundaryMargin: EdgeInsets.all(math.max(vp.width, vp.height)),
                minScale: _fitScale * 0.5,
                maxScale: math.max(2.0, _fitScale * 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Нажатие по плану — маркер сюда.
                  onTapUp: (d) =>
                      _setPoint(pixelsToFraction(d.localPosition, plan)),
                  child: SizedBox(
                    width: plan.width,
                    height: plan.height,
                    child: DecoratedBox(
                      decoration:
                          const BoxDecoration(boxShadow: AppShadows.floating),
                      child: PlanPicture(floor: floor, repo: _repo),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _tc,
                builder: (context, _) => _overlay(l, floor, plan),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _overlay(AppLocalizations l, Floor floor, Size plan) {
    final t = _translation, s = _scale;
    Offset screen((double, double) f) => fractionToScreen(f, plan, t, s);
    final room = _room;
    final areas = <(List<Offset>, Color, bool)>[
      for (final i in _items)
        if (i.hasAreaOn(floor.id))
          (
            [for (final p in i.shape!) screen(p)],
            i.id == room?.id
                ? AppColors.accent
                : i.id == _suggest?.id
                    ? AppColors.priorityHigh
                    : AppColors.tertiary,
            i.id == room?.id || i.id == _suggest?.id,
          ),
    ];
    final marker = screen(_point);
    final children = <Widget>[
      Positioned.fill(
          child: IgnorePointer(
              child: CustomPaint(painter: AreaPainter(areas: areas)))),
      // Другое оборудование этажа — бледные точки (для ориентира).
      for (final i in _items)
        if (!i.isPlace && i.isOn(floor.id) && !_isSelf(i))
          _ghost(screen((i.x!, i.y!))),
      Positioned(
        left: marker.dx - _Marker.hit / 2,
        top: marker.dy - _Marker.hit / 2,
        width: _Marker.hit,
        height: _Marker.hit,
        child: Semantics(
          label: l.eqPlaceMarker(widget.assetName),
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => setState(() {
                _dragging = true;
                _magnify = d.kind == PointerDeviceKind.touch ||
                    d.kind == PointerDeviceKind.stylus;
                _suggest = null;
              }),
              onPanUpdate: (d) => _setPoint(
                  moveFraction(_point, d.delta, plan, _scale),
                  settle: false),
              onPanEnd: (_) => setState(() {
                _dragging = false;
                _magnify = false;
                _checkRoom();
              }),
              onPanCancel: () => setState(() {
                _dragging = false;
                _magnify = false;
              }),
              child: _Marker(
                  icon: assetIcon(widget.kind, widget.category),
                  active: _dragging),
            ),
          ),
        ),
      ),
    ];
    if (_magnify) children.add(_magnifier(marker));
    return Stack(clipBehavior: Clip.none, children: children);
  }

  bool _isSelf(PlanItem i) => i.id == widget.assetId;

  Widget _ghost(Offset p) => Positioned(
        left: p.dx - 5,
        top: p.dy - 5,
        width: 10,
        height: 10,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.tertiary, width: 2),
            ),
          ),
        ),
      );

  /// Лупа над пальцем: палец закрывает маркер — видно, куда он встанет.
  Widget _magnifier(Offset at) {
    const size = 120.0, lift = 110.0;
    // У верхнего края — лупа под пальцем.
    final up = at.dy - lift - size / 2 > 0;
    final center = at + Offset(0, up ? -lift : lift);
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: IgnorePointer(
        child: RawMagnifier(
          size: const Size(size, size),
          magnificationScale: 2.2,
          focalPointOffset: Offset(0, up ? lift : -lift),
          decoration: const MagnifierDecoration(
            shape: CircleBorder(
                side: BorderSide(color: AppColors.accent, width: 3)),
            shadows: AppShadows.floating,
          ),
          child: const Center(
            child: SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: AppColors.onAccent, shape: BoxShape.circle)),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ панель

  Widget _panel(AppLocalizations l) {
    final floors = _planFloors;
    final room = _room;
    final suggest = _suggest;
    final changed = _locationId != widget.locationId && room != null;
    return BottomActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (floors.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in floors)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpace.s),
                    child: AppChip(
                        label: f.name,
                        selected: f.id == _floor?.id,
                        onTap: () => _selectFloor(f)),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpace.s),
          ],
          if (suggest != null) ...[
            Text(l.eqPlaceOtherRoom(suggest.label),
                style: AppText.footnote.copyWith(color: AppColors.ink)),
            const SizedBox(height: AppSpace.s),
            Row(children: [
              Expanded(
                child: AppButton.tinted(
                    label: l.eqPlaceSwitchRoom,
                    small: true,
                    onPressed: () => setState(() {
                          _locationId = suggest.id;
                          _suggest = null;
                        })),
              ),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: AppButton.secondary(
                    label: l.eqPlaceKeepRoom,
                    small: true,
                    onPressed: () => setState(() {
                          _declined = suggest.id;
                          _suggest = null;
                        })),
              ),
            ]),
            const SizedBox(height: AppSpace.s),
          ] else
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
              child: Text(
                  [
                    _floor!.name,
                    if (room != null) room.label,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.footnote.copyWith(color: AppColors.ink)),
            ),
          if (changed && suggest == null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
              child: Text(l.eqPlaceRoomChanged(room.label),
                  style: AppText.caption.copyWith(color: AppColors.accentText)),
            ),
          if (suggest == null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
              child: Text(l.eqPlaceDragHint,
                  style: AppText.caption.copyWith(color: AppColors.secondary)),
            ),
          Row(children: [
            if (widget.current != null) ...[
              Expanded(
                child: AppButton.secondary(
                    label: l.eqPlaceRemove,
                    icon: AppIcons.placeOff,
                    onPressed: _clear),
              ),
              const SizedBox(width: AppSpace.s),
            ],
            Expanded(
              child: AppButton.primary(
                  label: l.eqPlaceDone, icon: AppIcons.check, onPressed: _done),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Маркер выбираемой точки: кольцо с точкой в центре (точно видно место)
/// и значок вида оборудования сбоку. Цель нажатия 56 px.
class _Marker extends StatelessWidget {
  const _Marker({required this.icon, required this.active});
  final IconData icon;
  final bool active;

  static const hit = 56.0;

  @override
  Widget build(BuildContext context) {
    final ring = active ? 40.0 : 34.0;
    return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentText, width: 2.5),
              boxShadow: AppShadows.floating,
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.onAccent, shape: BoxShape.circle),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Icon(icon, size: 13, color: AppColors.onAccent),
            ),
          ),
        ]);
  }
}
