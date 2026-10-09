import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Как нажатие видно пользователю.
enum PressEffect {
  /// Кнопки: масштаб 0.97.
  scale,

  /// Строки списков: лёгкое затемнение фона.
  highlight,
}

/// Нажимаемая область без «волны» Material: масштаб или затемнение,
/// фокус с клавиатуры (Tab, Enter, пробел), курсор-рука, роль «кнопка»
/// для экранного диктора и автотестов.
///
/// [onTap] == null — область неактивна (не нажимается, не в фокусе).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.effect = PressEffect.scale,
    this.borderRadius,
    this.semanticLabel,
    this.button = true,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final PressEffect effect;

  /// Форма затемнения (для [PressEffect.highlight]).
  final BorderRadius? borderRadius;

  /// Имя для диктора, если в [child] нет понятного текста (значок).
  final String? semanticLabel;

  /// false — у области нет роли «кнопка» (например, она внутри другой).
  final bool button;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.effect == PressEffect.scale) {
      child = AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: child,
      );
    } else {
      child = Stack(children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              decoration: BoxDecoration(
                  color: _pressed || _focused
                      ? AppColors.pressOverlay
                      : const Color(0x00000000),
                  borderRadius: widget.borderRadius),
            ),
          ),
        ),
      ]);
    }
    if (widget.effect == PressEffect.scale && _focused) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius:
              widget.borderRadius ?? BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.accentText, width: 2),
        ),
        child: child,
      );
    }
    // Один узел доступности на всю область: текст внутри становится её
    // именем (роль «кнопка» с подписью — для диктора и для /screens).
    return Semantics(
      container: true,
      button: widget.button && _enabled,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _enabled ? (_) => _set(true) : null,
          onTapUp: _enabled ? (_) => _set(false) : null,
          onTapCancel: _enabled ? () => _set(false) : null,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: child,
        ),
      ),
    );
  }
}
