import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Прокрутка во всём приложении (`MaterialApp.scrollBehavior`).
///
/// - На компьютере (в том числе в браузере на ПК) у вертикальных списков
///   всегда видна полоса прокрутки, и её ползунок можно тянуть мышью.
///   Полоса строится здесь с тем же контроллером, что и у списка, поэтому
///   отдельные `Scrollbar` вокруг списков не нужны.
/// - Перетаскивание содержимого — пальцем, стилусом и жестом тачпада.
///   Мышью содержимое не тянем: у мыши порог перетаскивания 1 px, и любое
///   дрожание руки при щелчке превращало бы нажатие кнопки в прокрутку.
///   Мышью — колесо и ползунок полосы.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    final desktop = switch (getPlatform(context)) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
    if (desktop && axisDirectionToAxis(details.direction) == Axis.vertical) {
      return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          interactive: true,
          child: child);
    }
    return super.buildScrollbar(context, child, details);
  }
}

/// Клавиша прокрутки.
enum ScrollKey { lineUp, lineDown, pageUp, pageDown, home, end }

/// Шаг стрелок ↑/↓.
const scrollLineStep = 60.0;

/// Куда прокрутить по клавише: стрелки — на [scrollLineStep], PageUp/PageDown
/// и пробел — на высоту видимой области (минус 10 %, чтобы последняя строка
/// осталась на экране), Home/End — в начало и в конец.
double scrollKeyTarget(ScrollKey key,
    {required double pixels,
    required double min,
    required double max,
    required double viewport}) {
  final page = viewport * 0.9;
  final to = switch (key) {
    ScrollKey.lineUp => pixels - scrollLineStep,
    ScrollKey.lineDown => pixels + scrollLineStep,
    ScrollKey.pageUp => pixels - page,
    ScrollKey.pageDown => pixels + page,
    ScrollKey.home => min,
    ScrollKey.end => max,
  };
  return to.clamp(min, max);
}

class ScrollKeyIntent extends Intent {
  const ScrollKeyIntent(this.key, {this.space = false});
  final ScrollKey key;

  /// Пробел: прокручивает, только если ничего не выбрано (иначе он нажимает
  /// выбранную кнопку или пишет в поле).
  final bool space;
}

/// Прокрутка клавиатурой на всех экранах: ↑/↓, PageUp/PageDown, пробел
/// (Shift+пробел — вверх), Home/End. Ставится один раз в `MaterialApp.builder`.
///
/// Какой список прокручивать: тот, внутри которого стоит фокус, иначе —
/// видимый список под курсором мыши (или в центре окна). Фокус ставить не
/// нужно — экран прокручивается сразу после открытия и после щелчка в
/// пустое место. Если фокус в текстовом поле, клавиши работают для текста.
class KeyboardScrolling extends StatefulWidget {
  const KeyboardScrolling({super.key, required this.child});
  final Widget child;

  static const shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp):
        ScrollKeyIntent(ScrollKey.lineUp),
    SingleActivator(LogicalKeyboardKey.arrowDown):
        ScrollKeyIntent(ScrollKey.lineDown),
    SingleActivator(LogicalKeyboardKey.pageUp):
        ScrollKeyIntent(ScrollKey.pageUp),
    SingleActivator(LogicalKeyboardKey.pageDown):
        ScrollKeyIntent(ScrollKey.pageDown),
    SingleActivator(LogicalKeyboardKey.home): ScrollKeyIntent(ScrollKey.home),
    SingleActivator(LogicalKeyboardKey.end): ScrollKeyIntent(ScrollKey.end),
    SingleActivator(LogicalKeyboardKey.space):
        ScrollKeyIntent(ScrollKey.pageDown, space: true),
    SingleActivator(LogicalKeyboardKey.space, shift: true):
        ScrollKeyIntent(ScrollKey.pageUp, space: true),
  };

  @override
  State<KeyboardScrolling> createState() => _KeyboardScrollingState();
}

class _KeyboardScrollingState extends State<KeyboardScrolling> {
  /// Где последний раз была мышь (логические пиксели окна).
  Offset? _mouse;

  late final _action = _ScrollKeyAction(() => _mouse);

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (e) => _mouse = e.position,
        onPointerDown: (e) => _mouse = e.position,
        child: Shortcuts(
          shortcuts: KeyboardScrolling.shortcuts,
          child: Actions(
            actions: {ScrollKeyIntent: _action},
            child: widget.child,
          ),
        ),
      );
}

class _ScrollKeyAction extends Action<ScrollKeyIntent> {
  _ScrollKeyAction(this.mouse);
  final Offset? Function() mouse;

  @override
  bool isEnabled(ScrollKeyIntent intent) => _target(intent) != null;

  @override
  void invoke(ScrollKeyIntent intent) {
    final pos = _target(intent);
    if (pos == null) return;
    final to = scrollKeyTarget(intent.key,
        pixels: pos.pixels,
        min: pos.minScrollExtent,
        max: pos.maxScrollExtent,
        viewport: pos.viewportDimension);
    if (to == pos.pixels) return;
    pos.animateTo(to,
        duration: const Duration(milliseconds: 140), curve: Curves.easeOut);
  }

  ScrollPosition? _target(ScrollKeyIntent intent) {
    final focus = FocusManager.instance.primaryFocus;
    final focusCtx = focus?.context;
    // Выбрано что-то конкретное (не просто экран).
    if (focus != null && focusCtx != null && focus is! FocusScopeNode) {
      // Текстовое поле — клавиши для текста.
      if (focusCtx.widget is EditableText ||
          focusCtx.findAncestorWidgetOfExactType<EditableText>() != null) {
        return null;
      }
      // Пробел нажимает выбранную кнопку.
      if (intent.space) return null;
      final around = _verticalAround(focusCtx);
      if (around != null) return around;
    }
    return _underPoint();
  }

  /// Ближайший вертикальный список вокруг [context], который можно прокрутить.
  static ScrollPosition? _verticalAround(BuildContext context) {
    var s = Scrollable.maybeOf(context);
    while (s != null) {
      if (_usable(s)) return s.position;
      s = Scrollable.maybeOf(s.context);
    }
    return null;
  }

  static bool _usable(ScrollableState s) {
    if (axisDirectionToAxis(s.axisDirection) != Axis.vertical) return false;
    final p = s.position;
    return p.hasContentDimensions &&
        p.hasViewportDimension &&
        p.maxScrollExtent > p.minScrollExtent;
  }

  /// Видимый список под мышью (или в центре окна): самый вложенный из тех,
  /// что можно прокрутить. Проверка попаданием, поэтому списки скрытых
  /// вкладок и экранов под текущим не выбираются.
  ScrollPosition? _underPoint() {
    final binding = WidgetsBinding.instance;
    final view = binding.platformDispatcher.implicitView;
    final root = binding.rootElement;
    if (view == null || root == null) return null;
    final byBox = <RenderObject, ScrollableState>{};
    void visit(Element e) {
      if (e is StatefulElement && e.state is ScrollableState) {
        final s = e.state as ScrollableState;
        final box = e.findRenderObject();
        if (box != null && box.attached && _usable(s)) byBox[box] = s;
      }
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
    if (byBox.isEmpty) return null;
    final size = view.physicalSize / view.devicePixelRatio;
    // Сначала под мышью, потом — в центре окна (мышь над шапкой или полем).
    for (final point in [mouse(), size.center(Offset.zero)]) {
      if (point == null) continue;
      final result = HitTestResult();
      binding.hitTestInView(result, point, view.viewId);
      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderObject) {
          final s = byBox[target];
          if (s != null) return s.position;
        }
      }
    }
    return null;
  }
}
