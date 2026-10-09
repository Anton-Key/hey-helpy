import 'dart:async';

import 'package:flutter/material.dart';

import 'design/icons.dart';
import 'design/pressable.dart';
import 'design/tokens.dart';

/// Вид сообщения: от него зависят значок и сколько оно висит.
enum AppMessageType { info, success, error }

/// Сколько сообщение на экране: обычное — 3 с, ошибка — 5 с.
Duration appMessageDuration(AppMessageType type) => type == AppMessageType.error
    ? const Duration(seconds: 5)
    : const Duration(seconds: 3);

/// Ширина окна, с которой сообщение — карточкой в правом верхнем углу.
const appMessageWideFrom = 700.0;

/// Больше сообщений сразу не показываем — старые уходят.
const appMessageMaxStack = 3;

/// Единый способ показать короткое сообщение (вместо SnackBar).
///
/// Сообщение появляется **сверху**, под шапкой экрана, и не закрывает кнопки
/// внизу: на широком окне — карточкой до 360 px в правом верхнем углу,
/// на телефоне — на всю ширину. Плавно появляется, через 3 с (ошибка — 5 с)
/// плавно исчезает, можно закрыть крестиком. Несколько подряд — стопкой,
/// не больше [appMessageMaxStack]. Одинаковый текст не дублируется.
void showAppMessage(BuildContext context, String text,
    {AppMessageType type = AppMessageType.info}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _AppMessages.instance.show(overlay, text, type);
}

class _Msg {
  _Msg(this.id, this.text, this.type);
  final int id;
  final String text;
  final AppMessageType type;
}

class _AppMessages {
  static final instance = _AppMessages();
  final items = ValueNotifier<List<_Msg>>(const []);
  OverlayEntry? _entry;
  OverlayState? _overlay;
  int _seq = 0;

  void show(OverlayState overlay, String text, AppMessageType type) {
    final entry = _entry;
    if (entry == null || _overlay != overlay || !entry.mounted) {
      if (entry != null && entry.mounted) entry.remove();
      _overlay = overlay;
      overlay.insert(_entry = OverlayEntry(builder: (_) => _MessageHost(this)));
    }
    final list = [
      for (final m in items.value)
        if (m.text != text) m,
      _Msg(++_seq, text, type),
    ];
    while (list.length > appMessageMaxStack) {
      list.removeAt(0);
    }
    items.value = list;
  }

  void remove(int id) => items.value = [
        for (final m in items.value)
          if (m.id != id) m
      ];
}

class _MessageHost extends StatelessWidget {
  const _MessageHost(this.messages);
  final _AppMessages messages;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= appMessageWideFrom;
    return ValueListenableBuilder<List<_Msg>>(
      valueListenable: messages.items,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();
        // Только сама стопка ловит нажатия — остальной экран работает.
        return Stack(children: [
          PositionedDirectional(
            top: mq.padding.top + AppSizes.navBar + 8,
            end: wide ? 24 : 16,
            start: wide ? null : 16,
            child: SizedBox(
              width: wide ? 360 : null,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final m in list)
                  _MessageCard(
                      key: ValueKey(m.id),
                      msg: m,
                      onGone: () => messages.remove(m.id)),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _MessageCard extends StatefulWidget {
  const _MessageCard({super.key, required this.msg, required this.onGone});
  final _Msg msg;
  final VoidCallback onGone;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220))
    ..forward();
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(appMessageDuration(widget.msg.type), _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _anim.reverse();
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (widget.msg.type) {
      AppMessageType.info => (AppIcons.info, AppColors.accentText),
      AppMessageType.success => (AppIcons.success, AppColors.accentText),
      AppMessageType.error => (AppIcons.error, AppColors.danger),
    };
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -0.25), end: Offset.zero)
            .animate(curve),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8),
          // Свой узел доступности с размерами карточки — экранный диктор
          // читает сообщение сразу (liveRegion).
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.group),
                boxShadow: AppShadows.floating,
              ),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 6, 4),
              child: Row(children: [
                Icon(icon, color: color, size: AppSizes.icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.symmetric(vertical: 10),
                    child: Text(widget.msg.text, style: AppText.callout),
                  ),
                ),
                Pressable(
                  onTap: _close,
                  semanticLabel:
                      MaterialLocalizations.of(context).closeButtonTooltip,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(AppIcons.close,
                        size: 18, color: AppColors.secondary),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
