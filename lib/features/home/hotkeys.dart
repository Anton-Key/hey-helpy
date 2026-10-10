import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Горячие клавиши ПК: N — новая заявка, V — голосовая, / — поиск,
/// ? — справка.
enum HomeHotkey { newOrder, voice, search, help }

/// Клавиша → действие. Не срабатывает, когда курсор в поле ввода
/// ([typing]) или зажат Ctrl / Alt / Cmd. Клавиши — физические: работают и
/// в русской раскладке (N = «Т», V = «М»).
HomeHotkey? hotkeyFor(
  PhysicalKeyboardKey key, {
  required bool typing,
  bool shift = false,
  bool modifier = false,
  String? character,
}) {
  if (typing || modifier) return null;
  if (character == '?') return HomeHotkey.help;
  if (key == PhysicalKeyboardKey.slash) {
    return shift ? HomeHotkey.help : HomeHotkey.search;
  }
  if (shift) return null;
  if (key == PhysicalKeyboardKey.keyN) return HomeHotkey.newOrder;
  if (key == PhysicalKeyboardKey.keyV) return HomeHotkey.voice;
  return null;
}

/// Курсор сейчас в поле ввода (тогда буквы — это текст, а не команды).
bool isTypingNow() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  if (ctx.widget is EditableText) return true;
  return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Слушает клавиатуру, пока [enabled] (главный экран сверху, без окон).
class HomeHotkeys extends StatefulWidget {
  const HomeHotkeys({
    super.key,
    required this.child,
    required this.onHotkey,
    required this.enabled,
  });

  final Widget child;
  final ValueChanged<HomeHotkey> onHotkey;
  final bool Function() enabled;

  @override
  State<HomeHotkeys> createState() => _HomeHotkeysState();
}

class _HomeHotkeysState extends State<HomeHotkeys> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted || !widget.enabled()) return false;
    final k = HardwareKeyboard.instance;
    final hk = hotkeyFor(
      e.physicalKey,
      typing: isTypingNow(),
      shift: k.isShiftPressed,
      modifier: k.isControlPressed || k.isAltPressed || k.isMetaPressed,
      character: e.character,
    );
    if (hk == null) return false;
    widget.onHotkey(hk);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
