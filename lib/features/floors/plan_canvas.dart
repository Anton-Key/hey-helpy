import 'dart:async';
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
    this.onClear,
    this.onMoved,
    this.labelOf,
    this.initialFocus,
    this.bottomInset = 0,
    this.areas = const [],
    this.draft,
    this.draftRect = false,
    this.onDraftTap,
    this.onDraftRect,
    this.onDraftMove,
  });

  /// Помещения с областью на этом этаже (шаг 16): закрашены цветом статуса,
  /// нажатие внутри области вне расстановки — как нажатие на маркер.
  final List<PlanItem> areas;

  /// Рисуемая область (режим «Обвести область»): вершины долями 0..1;
  /// null — не рисуем. Нажатие на план добавляет вершину ([onDraftTap]),
  /// вершины можно тянуть ([onDraftMove]).
  final List<(double, double)>? draft;

  /// Рисуем прямоугольником: протянуть пальцем / мышью ([onDraftRect]).
  final bool draftRect;
  final void Function(double fx, double fy)? onDraftTap;
  final void Function((double, double) a, (double, double) b)? onDraftRect;
  final void Function(int index, double fx, double fy)? onDraftMove;

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

  /// Нажатие на пустое место вне режима расстановки — снять выбор.
  final VoidCallback? onClear;
  final void Function(PlanItem item, double fx, double fy)? onMoved;

  /// Подпись маркера для диктора (название и заявки).
  final String Function(PlanItem item)? labelOf;

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

class _PlanCanvasState extends State<PlanCanvas> with TickerProviderStateMixin {
  final _tc = TransformationController();
  late final _anim =
      AnimationController(vsync: this, duration: AppMotion.normal * 2);
  Animation<Matrix4>? _tween;
  Size _viewport = Size.zero;
  bool _fitted = false;
  late String? _pendingCenter = widget.initialFocus;

  /// Один тикер на весь экран: волны выбранного и «дыхание» просроченного
  /// оборудования. Работает, только пока есть что анимировать.
  late final _clock =
      AnimationController(vsync: this, duration: kPlanClockPeriod);

  /// Волны у выбранного маркера — [kPlanPulseWindow] после выбора.
  bool _pulsing = false;
  Timer? _pulseTimer;

  /// Маркер под мышью (ПК): подпись видна.
  String? _hover;

  /// План двигали (жестом, кнопками, центрированием): при смене размера
  /// окна больше не «вписываем» заново.
  bool _touched = false;

  /// Перетаскиваемый маркер и его точка (пиксели плана).
  String? _dragKey;
  Offset? _dragPos;

  /// Прямоугольник области, который сейчас тянут (пиксели плана).
  Offset? _rectFrom;
  Offset? _rectTo;

  bool get _drawing => widget.draft != null;

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
    if (widget.highlight != null) _startPulse();
  }

  void _startPulse() {
    _pulseTimer?.cancel();
    _pulsing = true;
    _pulseTimer = Timer(kPlanPulseWindow, () {
      if (mounted) setState(() => _pulsing = false);
    });
  }

  /// Тикер — только когда нужен (после кадра: не из build).
  void _syncClock(bool need) {
    if (need == _clock.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (need && !_clock.isAnimating) _clock.repeat();
      if (!need && _clock.isAnimating) _clock.stop();
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
    if (old.highlight != widget.highlight) {
      if (widget.highlight != null) {
        _startPulse();
      } else {
        _pulseTimer?.cancel();
        _pulsing = false;
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller._s == this) widget.controller._s = null;
    _pulseTimer?.cancel();
    _clock.dispose();
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

  /// Приблизить к маркеру: на телефоне 1,8 × «весь план», на ПК 1,25 × —
  /// этаж почти целиком, маркер в центре (было 2,5 × — на ПК 1920 в кадре
  /// оставался угол одной комнаты; шаг 18).
  void _centerOn(PlanItem i) {
    if (!i.placed) return;
    if (_viewport.isEmpty || !_fitted) {
      _pendingCenter = i.key;
      return;
    }
    _touched = true;
    final p = fractionToPixels(i.x!, i.y!, _plan);
    final zoom = _viewport.width >= 900 ? 1.25 : 1.8;
    final s = math.max(_scale, _fitScale * zoom).clamp(_minScale, _maxScale);
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
                panEnabled: !(_drawing && widget.draftRect),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tapPlan(d.localPosition, plan),
                  onPanStart: _drawing && widget.draftRect
                      ? (d) => setState(() {
                            _rectFrom = d.localPosition;
                            _rectTo = d.localPosition;
                          })
                      : null,
                  onPanUpdate: _drawing && widget.draftRect
                      ? (d) => setState(() => _rectTo = d.localPosition)
                      : null,
                  onPanEnd: _drawing && widget.draftRect
                      ? (_) {
                          final a = _rectFrom, b = _rectTo;
                          setState(() {
                            _rectFrom = null;
                            _rectTo = null;
                          });
                          if (a == null || b == null) return;
                          if ((a - b).distance * _scale < 12) return;
                          widget.onDraftRect?.call(pixelsToFraction(a, plan),
                              pixelsToFraction(b, plan));
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
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _tc,
                  builder: (context, _) => _markers(plan),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }

  /// Нажатие на план (координаты плана, px).
  void _tapPlan(Offset local, Size plan) {
    final (fx, fy) = pixelsToFraction(local, plan);
    if (_drawing) {
      if (!widget.draftRect) widget.onDraftTap?.call(fx, fy);
      return;
    }
    if (widget.editing) {
      widget.onEmptyTap?.call(fx, fy);
      return;
    }
    // Нажатие в области помещения — как нажатие на его маркер.
    final hit = areaAt(widget.areas, widget.floor.id, fx, fy, plan);
    if (hit != null) {
      widget.onMarkerTap(hit);
      return;
    }
    widget.onClear?.call();
  }

  /// Области помещений и рисуемая область — под маркерами, без нажатий
  /// (нажатие проходит к плану: [_tapPlan]).
  List<Widget> _areaLayer(Size plan, double scale, double fit) {
    final out = <Widget>[];
    final shapes = <(List<Offset>, Color, bool)>[];
    for (final i in widget.areas) {
      if (!i.hasAreaOn(widget.floor.id)) continue;
      final tone = markerTone(widget.stats[i.key] ?? ObjectStats.empty);
      final pts = [
        for (final (x, y) in i.shape!) _toScreen(fractionToPixels(x, y, plan))
      ];
      shapes.add((pts, markerGlowColor(tone), i.key == widget.highlight));
      if (!_drawing && areaLabelVisible(i.shape!, plan, scale, fit)) {
        final (cx, cy) = polygonCentroid(i.shape!);
        var c = _toScreen(fractionToPixels(cx, cy, plan));
        // Маркер помещения обычно в центре области — подпись под ним.
        if (i.placed) {
          final m = _toScreen(fractionToPixels(i.x!, i.y!, plan));
          if ((m - c).distance < 34) c = m + const Offset(0, 34);
        }
        out.add(Positioned(
          left: c.dx - PlanMarker.boxWidth / 2,
          top: c.dy - 10,
          width: PlanMarker.boxWidth,
          child: IgnorePointer(
            child: Text(i.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w700)),
          ),
        ));
      }
    }
    final draft = widget.draft;
    List<Offset>? draftPts;
    if (draft != null) {
      draftPts = [
        for (final (x, y) in draft) _toScreen(fractionToPixels(x, y, plan))
      ];
    }
    final a = _rectFrom, b = _rectTo;
    List<Offset>? rectPts;
    if (a != null && b != null) {
      final ra = pixelsToFraction(a, plan), rb = pixelsToFraction(b, plan);
      rectPts = [
        for (final (x, y) in rectShape(ra, rb))
          _toScreen(fractionToPixels(x, y, plan))
      ];
    }
    out.insert(
        0,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
                painter:
                    AreaPainter(areas: shapes, draft: rectPts ?? draftPts)),
          ),
        ));
    // Вершины рисуемой области можно тянуть.
    if (draftPts != null && widget.onDraftMove != null && rectPts == null) {
      for (var k = 0; k < draftPts.length; k++) {
        out.add(_vertex(k, draftPts[k], plan));
      }
    }
    return out;
  }

  Widget _vertex(int k, Offset p, Size plan) {
    Offset? pos;
    void move(Offset screenDelta) {
      final d = widget.draft!;
      final start = pos ?? fractionToPixels(d[k].$1, d[k].$2, plan);
      pos = start + screenDelta / _scale;
      final (fx, fy) = pixelsToFraction(pos!, plan);
      widget.onDraftMove!(k, fx, fy);
    }

    return Positioned(
      left: p.dx - PlanMarker.hit / 2,
      top: p.dy - PlanMarker.hit / 2,
      width: PlanMarker.hit,
      height: PlanMarker.hit,
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => pos = null,
          onPanUpdate: (d) => move(d.delta),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 3),
                boxShadow: AppShadows.floating,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _markers(Size plan) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fit = _fitScale, scale = _scale;
    // Подсвеченный, наведённый и перетаскиваемый — последними (поверх).
    int rank(PlanItem i) => i.key == _dragKey
        ? 3
        : i.key == widget.highlight
            ? 2
            : (i.key == _hover ? 1 : 0);
    final ordered = [...widget.items]..sort((a, b) => rank(a) - rank(b));
    final shown = <(PlanItem, Offset, Offset, MarkerFx, bool)>[];
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
      final fx = markerFx(
          selected: i.key == widget.highlight && _dragKey == null,
          pulsing: _pulsing,
          isPlace: i.isPlace,
          overdue: widget.stats[i.key]?.overdue ?? 0,
          reduceMotion: reduceMotion);
      shown.add((i, px, p, fx, hi));
    }
    // Помещения с видимой подписью области — без подписи у маркера.
    final areaLabeled = {
      for (final a in widget.areas)
        if (!_drawing &&
            a.hasAreaOn(widget.floor.id) &&
            areaLabelVisible(a.shape!, plan, scale, fit))
          a.key
    };
    _syncClock(planNeedsTicker(shown.map((e) => e.$4)));
    // Подписи: выбранная / наведённая — всегда, остальные — без наездов на
    // соседние маркеры и подписи (по порядку: сначала оборудование).
    final labels = planLabelLayout([
      for (final (i, _, p, _, hi) in shown.reversed)
        PlanLabelBox(i.key, p, i.label,
            priority: hi || i.key == _hover,
            wanted: !areaLabeled.contains(i.key) &&
                planLabelWanted(
                    isPlace: i.isPlace,
                    selected: hi,
                    hovered: i.key == _hover,
                    scale: scale,
                    fitScale: fit)),
    ]);
    final canHover = !widget.editing;
    final children = <Widget>[..._areaLayer(plan, scale, fit)];
    for (final (i, px, p, fx, hi) in shown) {
      final stats = widget.stats[i.key] ?? ObjectStats.empty;
      Widget marker = PlanMarker(
        item: i,
        stats: stats,
        highlighted: hi,
        showLabel: labels.contains(i.key),
        movable: widget.editing && widget.onMoved != null && !_drawing,
        semanticLabel: widget.labelOf?.call(i) ?? i.name,
        fx: fx,
        clock: _clock,
        onHover: canHover
            ? (on) {
                if (on && _hover != i.key) {
                  setState(() => _hover = i.key);
                } else if (!on && _hover == i.key) {
                  setState(() => _hover = null);
                }
              }
            : null,
        onTap: () => widget.onMarkerTap(i),
      );
      if (widget.editing && widget.onMoved != null && !_drawing) {
        marker = _draggable(i, px, _Hop(child: marker));
      }
      // Пока рисуем область, маркеры не мешают нажатиям по плану.
      if (_drawing) marker = IgnorePointer(child: marker);
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

/// Маркер «подпрыгивает» один раз при входе в режим расстановки — видно,
/// что его можно двигать.
class _Hop extends StatelessWidget {
  const _Hop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.normal * 3,
        builder: (context, t, child) => Transform.translate(
          // Два затухающих подскока по 6 px.
          offset: Offset(0, -6 * (1 - t) * math.sin(t * math.pi * 2).abs()),
          child: child,
        ),
        child: child,
      );
}

/// Цвет подсветки, ореола и волн маркера — цвет его статуса (не чёрный):
/// просрочено — красный, срочно — оранжевый, остальное — акцент.
Color markerGlowColor(MarkerTone t) => switch (t) {
      MarkerTone.alert => StatusColors.overdue.foreground,
      MarkerTone.warning => AppColors.priorityHigh,
      MarkerTone.open || MarkerTone.idle => AppColors.accent,
    };

/// Квадрат оборудования: (фон, рамка, значок) — светлый оттенок статуса,
/// рамка и значок цвета статуса; без заявок — серый.
(Color, Color, Color) assetColors(MarkerTone t) => switch (t) {
      MarkerTone.alert => (
          StatusColors.overdue.background,
          StatusColors.overdue.foreground,
          StatusColors.overdue.foreground
        ),
      MarkerTone.warning => (
          StatusColors.returned.background,
          AppColors.priorityHigh,
          StatusColors.returned.foreground
        ),
      MarkerTone.open => (
          AppColors.accentTint,
          AppColors.accent,
          AppColors.accentText
        ),
      MarkerTone.idle => (
          StatusColors.cancelled.background,
          AppColors.tertiary,
          AppColors.secondary
        ),
    };

/// Маркер плана: помещение — кружок с числом открытых заявок, оборудование
/// — квадрат со значком цвета статуса и бейджем числа заявок. Цвет — по
/// самой тревожной заявке (как на карте). Выбранный — крупнее в 1,25 раза,
/// с волнами / ореолом цвета статуса ([fx], общий тикер [clock]).
/// Цель нажатия 44 px; подпись — под маркером.
class PlanMarker extends StatelessWidget {
  const PlanMarker({
    super.key,
    required this.item,
    required this.stats,
    required this.onTap,
    this.highlighted = false,
    this.showLabel = false,
    this.movable = false,
    this.semanticLabel,
    this.fx = MarkerFx.none,
    this.clock,
    this.onHover,
  });

  /// Режим расстановки: акцентный контур «можно двигать».
  final bool movable;

  final PlanItem item;
  final ObjectStats stats;
  final VoidCallback onTap;
  final bool highlighted;
  final bool showLabel;
  final String? semanticLabel;
  final MarkerFx fx;

  /// Общий тикер экрана (0..1 за [kPlanClockPeriod]); один на все маркеры.
  final Animation<double>? clock;

  /// Наведение мыши (ПК): показать подпись.
  final ValueChanged<bool>? onHover;

  /// Цель нажатия и ширина области маркера с подписью.
  static const hit = 44.0;
  static const boxWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    final tone = markerTone(stats);
    final (bg, fg) = toneColors(tone);
    final glow = markerGlowColor(tone);
    final place = item.isPlace;
    final d = place ? 30.0 : 26.0;
    final Widget shape;
    if (place) {
      shape = Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
              color: highlighted ? glow : AppColors.surface,
              width: highlighted ? 3 : 2),
          boxShadow: AppShadows.floating,
        ),
        child: Text('${stats.open}',
            style: AppText.caption.copyWith(
                color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
      );
    } else {
      final (fill, border, icon) = assetColors(tone);
      shape = Stack(clipBehavior: Clip.none, children: [
        Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border, width: highlighted ? 3 : 2),
            boxShadow: AppShadows.floating,
          ),
          child: Icon(equipmentIcon(item), size: 15, color: icon),
        ),
        if (stats.open > 0)
          PositionedDirectional(
            top: -7,
            end: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text('${stats.open}',
                  style: AppText.caption.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      height: 1)),
            ),
          ),
      ]);
    }
    Widget body = movable
        ? Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: place ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: place ? null : BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: shape,
          )
        : shape;
    if (fx != MarkerFx.none) {
      body = CustomPaint(
        painter: _GlowPainter(
            clock: clock, fx: fx, color: glow, circle: place, side: d),
        child: body,
      );
    }
    if (highlighted) body = Transform.scale(scale: 1.25, child: body);
    Widget target = Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(width: hit, height: hit, child: Center(child: body)),
    );
    if (onHover != null) {
      target = MouseRegion(
          onEnter: (_) => onHover!(true),
          onExit: (_) => onHover!(false),
          child: target);
    }
    return Semantics(
      button: true,
      selected: highlighted,
      label: semanticLabel ?? item.name,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        target,
        if (showLabel)
          IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(maxWidth: boxWidth),
              padding: const EdgeInsetsDirectional.fromSTEB(6, 1, 6, 1),
              decoration: BoxDecoration(
                  color: AppColors.surface
                      .withValues(alpha: highlighted ? 0.97 : 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: highlighted ? AppShadows.floating : null),
              child: Text(item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                      color: AppColors.ink,
                      fontWeight:
                          highlighted ? FontWeight.w700 : FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

/// Период общего тикера: кратен периоду волн (1,2 с) и «дыхания» (2 с).
const kPlanClockPeriod = Duration(seconds: 12);
const _ripplePeriod = 1.2;
const _breathePeriod = 2.0;

/// Ореол, волны и «дыхание» вокруг маркера. Перерисовывается от общего
/// тикера (repaint), без перестройки виджетов — план не тормозит и при
/// десятках маркеров.
class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.clock,
    required this.fx,
    required this.color,
    required this.circle,
    required this.side,
  }) : super(
            repaint:
                fx == MarkerFx.ripple || fx == MarkerFx.breathe ? clock : null);

  final Animation<double>? clock;
  final MarkerFx fx;
  final Color color;
  final bool circle;
  final double side;

  double get _seconds =>
      (clock?.value ?? 0) * kPlanClockPeriod.inMilliseconds / 1000;

  void _ring(Canvas c, Offset center, double grow, double alpha, double width) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: alpha.clamp(0, 1).toDouble());
    if (circle) {
      c.drawCircle(center, side / 2 + grow, p);
    } else {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: center,
                  width: side + grow * 2,
                  height: side + grow * 2),
              Radius.circular(7 + grow)),
          p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    switch (fx) {
      case MarkerFx.none:
        return;
      case MarkerFx.halo:
        // Спокойный ореол: кольцо 30 % непрозрачности.
        _ring(canvas, center, 5, 0.3, 6);
      case MarkerFx.ripple:
        _ring(canvas, center, 5, 0.3, 6);
        final phase = (_seconds / _ripplePeriod) % 1;
        for (var i = 0; i < 3; i++) {
          final p = (phase + i / 3) % 1;
          _ring(canvas, center, 4 + p * 22, 0.65 * (1 - p), 2.5);
        }
      case MarkerFx.breathe:
        final s = (1 - math.cos(2 * math.pi * (_seconds / _breathePeriod))) / 2;
        _ring(canvas, center, 3 + 3 * s, 0.18 + 0.27 * s, 5);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.fx != fx ||
      old.color != color ||
      old.circle != circle ||
      old.side != side ||
      old.clock != clock;
}

/// Области помещений (заливка 16 % и контур цвета статуса; выбранная —
/// плотнее) и рисуемая область (контур и вершины акцента). Точки — экранные.
class AreaPainter extends CustomPainter {
  AreaPainter({required this.areas, this.draft});

  final List<(List<Offset>, Color, bool)> areas;
  final List<Offset>? draft;

  Path _path(List<Offset> pts, {bool close = true}) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    if (close) p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (pts, color, selected) in areas) {
      if (pts.length < 3) continue;
      final path = _path(pts);
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: selected ? 0.28 : 0.16));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 1.5
            ..strokeJoin = StrokeJoin.round
            ..color = color.withValues(alpha: selected ? 0.9 : 0.55));
    }
    final d = draft;
    if (d != null && d.isNotEmpty) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accentText;
      if (d.length >= 3) {
        canvas.drawPath(
            _path(d),
            Paint()
              ..style = PaintingStyle.fill
              ..color = AppColors.accent.withValues(alpha: 0.18));
      }
      if (d.length >= 2) {
        canvas.drawPath(_path(d, close: d.length >= 3), stroke);
      }
      for (final o in d) {
        canvas.drawCircle(o, 4, Paint()..color = AppColors.accentText);
      }
    }
  }

  @override
  bool shouldRepaint(AreaPainter old) => true;
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
