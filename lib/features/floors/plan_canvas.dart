import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/scrolling.dart';
import '../map/map_logic.dart';
import '../map/map_parts.dart';
import 'floor_models.dart';
import 'plan_image.dart';
import 'plan_logic.dart';

/// Управление холстом плана снаружи (список слева, кнопки зума).
class PlanCanvasController {
  _PlanCanvasState? _s;

  /// Плавно показать маркер в центре и приблизить.
  void centerOn(PlanItem i) => _s?._centerOn(i);
  void zoomBy(double factor) => _s?._zoomBy(factor);
  void fit() => _s?._fit(animate: true);

  /// Точка в центре окна, доли 0..1 (поставить «не размещённое» сюда).
  (double, double)? viewCenter() => _s?._viewCenter();
}

/// Холст плана: картинка (или сетка) с масштабом и прокруткой — жесты,
/// колесо мыши, кнопки снаружи ([PlanCanvasController]); маркеры одного
/// размера при любом масштабе, подписи — при приближении.
///
/// В режиме расстановки ([editing]) маркер перетаскивается (мышью сразу,
/// пальцем — после долгого нажатия), нажатие на пустое место —
/// [onEmptyTap] с долями 0..1.
class PlanCanvas extends StatefulWidget {
  const PlanCanvas({
    super.key,
    required this.floor,
    required this.items,
    required this.stats,
    required this.controller,
    required this.onMarkerTap,
    this.highlight,
    this.editing = false,
    this.onEmptyTap,
    this.onMoved,
    this.labelOf,
    this.initialFocus,
    this.bottomInset = 0,
  });

  /// Сколько снизу закрыто панелью (телефон): «вписать» и центрирование —
  /// в видимой части.
  final double bottomInset;

  /// Маркер ([PlanItem.key]), на котором открыть план (из заявки, по ссылке).
  final String? initialFocus;

  final Floor floor;

  /// Маркеры этого этажа (уже отфильтрованные).
  final List<PlanItem> items;
  final Map<String, ObjectStats> stats;
  final PlanCanvasController controller;
  final ValueChanged<PlanItem> onMarkerTap;

  /// Подсвеченный маркер ([PlanItem.key]).
  final String? highlight;
  final bool editing;
  final void Function(double fx, double fy)? onEmptyTap;
  final void Function(PlanItem item, double fx, double fy)? onMoved;

  /// Подпись маркера для диктора (название и заявки).
  final String Function(PlanItem item)? labelOf;

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

class _PlanCanvasState extends State<PlanCanvas>
    with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final _anim =
      AnimationController(vsync: this, duration: AppMotion.normal * 2);
  Animation<Matrix4>? _tween;
  Size _viewport = Size.zero;
  bool _fitted = false;
  late String? _pendingCenter = widget.initialFocus;

  /// План двигали (жестом, кнопками, центрированием): при смене размера
  /// окна больше не «вписываем» заново.
  bool _touched = false;

  /// Перетаскиваемый маркер и его точка (пиксели плана).
  String? _dragKey;
  Offset? _dragPos;

  Size get _plan => planSize(widget.floor);
  /// Видимая часть холста (без панели снизу).
  Size get _visible => Size(
      _viewport.width, math.max(1.0, _viewport.height - widget.bottomInset));

  double get _fitScale =>
      planFitScale(_visible, _plan, margin: _viewport.width < 600 ? 8 : 24);
  double get _scale => _tc.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    widget.controller._s = this;
    _anim.addListener(() {
      final t = _tween;
      if (t != null) _tc.value = t.value;
    });
  }

  @override
  void didUpdateWidget(PlanCanvas old) {
    super.didUpdateWidget(old);
    widget.controller._s = this;
    if (old.floor.id != widget.floor.id ||
        old.floor.planW != widget.floor.planW ||
        old.floor.planH != widget.floor.planH) {
      _fitted = false;
      _touched = false;
    }
  }

  @override
  void dispose() {
    if (widget.controller._s == this) widget.controller._s = null;
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  Matrix4 _matrix(Offset t, double s) => Matrix4.identity()
    ..translateByDouble(t.dx, t.dy, 0, 1)
    ..scaleByDouble(s, s, s, 1);

  void _animateTo(Matrix4 m) {
    _tween = Matrix4Tween(begin: _tc.value, end: m)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  void _fit({bool animate = false}) {
    if (_viewport.isEmpty) return;
    final s = _fitScale;
    final t = Offset((_visible.width - _plan.width * s) / 2,
        (_visible.height - _plan.height * s) / 2);
    final m = _matrix(t, s);
    animate ? _animateTo(m) : _tc.value = m;
  }

  void _zoomBy(double f) {
    if (_viewport.isEmpty) return;
    _touched = true;
    final s0 = _scale;
    final s1 = (s0 * f).clamp(_minScale, _maxScale).toDouble();
    final t0 = _tc.value.getTranslation();
    final c = (_viewport.center(Offset.zero) - Offset(t0.x, t0.y)) / s0;
    _animateTo(_matrix(_viewport.center(Offset.zero) - c * s1, s1));
  }

  void _centerOn(PlanItem i) {
    if (!i.placed) return;
    if (_viewport.isEmpty || !_fitted) {
      _pendingCenter = i.key;
      return;
    }
    _touched = true;
    final p = fractionToPixels(i.x!, i.y!, _plan);
    final s = math.max(_scale, _fitScale * 2.5).clamp(_minScale, _maxScale);
    _animateTo(_matrix(planCenterOn(p, s.toDouble(), _visible), s.toDouble()));
  }

  (double, double)? _viewCenter() {
    if (_viewport.isEmpty) return null;
    final t = _tc.value.getTranslation();
    final p = (_viewport.center(Offset.zero) - Offset(t.x, t.y)) / _scale;
    return pixelsToFraction(p, _plan);
  }

  double get _minScale => _fitScale * 0.5;
  double get _maxScale => math.max(2.0, _fitScale * 8);

  Offset _toScreen(Offset planPx) =>
      MatrixUtils.transformPoint(_tc.value, planPx);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final vp = c.biggest;
      if (vp != _viewport) {
        _viewport = vp;
        if (_fitted && !_touched && !vp.isEmpty) {
          // Окно ещё «устраивается» (панели, шапка) — вписать заново.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_touched) _fit();
          });
        }
        if (!_fitted && !vp.isEmpty) {
          _fitted = true;
          _fit();
          final pending = _pendingCenter;
          if (pending != null) {
            _pendingCenter = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              for (final i in widget.items) {
                if (i.key == pending) _centerOn(i);
              }
            });
          }
        }
      } else if (!_fitted && !vp.isEmpty) {
        _fitted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
      }
      final plan = _plan;
      return KeyboardScrollBlocker(
        child: ClipRect(
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _tc,
                constrained: false,
                onInteractionStart: (_) => _touched = true,
                boundaryMargin: EdgeInsets.all(math.max(vp.width, vp.height)),
                minScale: _minScale,
                maxScale: _maxScale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.editing && widget.onEmptyTap != null
                      ? (d) {
                          final (fx, fy) =
                              pixelsToFraction(d.localPosition, plan);
                          widget.onEmptyTap!(fx, fy);
                        }
                      : null,
                  child: SizedBox(
                    width: plan.width,
                    height: plan.height,
                    child: DecoratedBox(
                      decoration:
                          const BoxDecoration(boxShadow: AppShadows.floating),
                      child: PlanPicture(floor: widget.floor),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _tc,
                builder: (context, _) => _markers(plan),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _markers(Size plan) {
    final labels = labelsVisible(_scale, _fitScale);
    final children = <Widget>[];
    // Подсвеченный и перетаскиваемый — последними (поверх соседей).
    final ordered = [...widget.items]..sort((a, b) {
        int r(PlanItem i) =>
            i.key == _dragKey ? 2 : (i.key == widget.highlight ? 1 : 0);
        return r(a) - r(b);
      });
    for (final i in ordered) {
      if (!i.placed) continue;
      final px = i.key == _dragKey && _dragPos != null
          ? _dragPos!
          : fractionToPixels(i.x!, i.y!, plan);
      final p = _toScreen(px);
      if (p.dx < -80 ||
          p.dy < -80 ||
          p.dx > _viewport.width + 80 ||
          p.dy > _viewport.height + 80) {
        continue;
      }
      final hi = i.key == widget.highlight || i.key == _dragKey;
      final stats = widget.stats[i.key] ?? ObjectStats.empty;
      Widget marker = PlanMarker(
        item: i,
        stats: stats,
        highlighted: hi,
        showLabel: labels || hi,
        semanticLabel: widget.labelOf?.call(i) ?? i.name,
        onTap: () => widget.onMarkerTap(i),
      );
      if (widget.editing && widget.onMoved != null) {
        marker = _draggable(i, px, marker);
      }
      children.add(Positioned(
        left: p.dx - PlanMarker.boxWidth / 2,
        top: p.dy - PlanMarker.hit / 2,
        width: PlanMarker.boxWidth,
        child: marker,
      ));
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _draggable(PlanItem i, Offset start, Widget child) {
    void begin() => setState(() {
          _dragKey = i.key;
          _dragPos = start;
        });
    void move(Offset screenDelta) =>
        setState(() => _dragPos = (_dragPos ?? start) + screenDelta / _scale);
    void end() {
      final pos = _dragPos;
      setState(() {
        _dragKey = null;
        _dragPos = null;
      });
      if (pos == null || pos == start) return;
      final (fx, fy) = pixelsToFraction(pos, _plan);
      widget.onMoved!(i, fx, fy);
    }

    Offset? last;
    // Мышь — сразу; палец — после долгого нажатия (иначе не прокрутить план).
    return GestureDetector(
      supportedDevices: const {PointerDeviceKind.mouse},
      onPanStart: (_) => begin(),
      onPanUpdate: (d) => move(d.delta),
      onPanEnd: (_) => end(),
      child: GestureDetector(
        onLongPressStart: (d) {
          last = d.globalPosition;
          begin();
        },
        onLongPressMoveUpdate: (d) {
          final prev = last ?? d.globalPosition;
          last = d.globalPosition;
          move(d.globalPosition - prev);
        },
        onLongPressEnd: (_) => end(),
        child: MouseRegion(cursor: SystemMouseCursors.move, child: child),
      ),
    );
  }
}

/// Маркер плана: помещение — кружок с числом открытых заявок, оборудование
/// — квадрат со значком. Цвет — по самой тревожной заявке (как на карте).
/// Цель нажатия 44 px; подпись — под маркером.
class PlanMarker extends StatelessWidget {
  const PlanMarker({
    super.key,
    required this.item,
    required this.stats,
    required this.onTap,
    this.highlighted = false,
    this.showLabel = false,
    this.semanticLabel,
  });

  final PlanItem item;
  final ObjectStats stats;
  final VoidCallback onTap;
  final bool highlighted;
  final bool showLabel;
  final String? semanticLabel;

  /// Цель нажатия и ширина области маркера с подписью.
  static const hit = 44.0;
  static const boxWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    final tone = markerTone(stats);
    final (bg, fg) = toneColors(tone);
    final place = item.isPlace;
    final d = place ? (highlighted ? 34.0 : 30.0) : (highlighted ? 30.0 : 26.0);
    final shape = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: place ? bg : AppColors.surface,
        shape: place ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: place ? null : BorderRadius.circular(7),
        border: Border.all(
            color:
                highlighted ? AppColors.ink : (place ? AppColors.surface : bg),
            width: highlighted ? 3 : 2),
        boxShadow: AppShadows.floating,
      ),
      child: place
          ? Text('${stats.open}',
              style: AppText.caption.copyWith(
                  color: fg, fontWeight: FontWeight.w700, fontSize: 13))
          : Icon(equipmentIcon(item), size: 15, color: AppColors.ink),
    );
    return Semantics(
      button: true,
      label: semanticLabel ?? item.name,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(width: hit, height: hit, child: Center(child: shape)),
        ),
        if (showLabel)
          IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(maxWidth: boxWidth),
              padding: const EdgeInsetsDirectional.fromSTEB(6, 1, 6, 1),
              decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

/// Значок оборудования: по виду (assets.meta.kind), иначе по категории.
IconData equipmentIcon(PlanItem i) {
  if (i.isPlace) return AppIcons.room;
  switch (i.equipmentKind) {
    case 'ac':
      return AppIcons.eqAirCon;
    case 'fancoil':
    case 'vent':
      return AppIcons.eqFan;
    case 'panel':
      return AppIcons.eqPanel;
    case 'light':
      return AppIcons.eqLight;
    case 'smoke':
      return AppIcons.eqSmoke;
    case 'ups':
      return AppIcons.eqUps;
    case 'sensor':
      return AppIcons.eqSensor;
    case 'camera':
      return AppIcons.eqCamera;
    case 'server':
      return AppIcons.eqServer;
    case 'water':
      return AppIcons.eqWater;
  }
  return switch (i.category) {
    'furniture' => AppIcons.eqFurniture,
    'infra' => AppIcons.eqInfra,
    'other' => AppIcons.eqOther,
    _ => AppIcons.wrench,
  };
}
