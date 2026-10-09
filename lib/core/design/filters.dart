import 'package:flutter/material.dart';

import 'buttons.dart';
import 'controls.dart';
import 'group.dart';
import 'icons.dart';
import 'pressable.dart';
import 'surfaces.dart';
import 'tokens.dart';

/// «Таблетка» фильтра в строке над списком.
///
/// Обычная — белая капсула: [label] и стрелка вниз. Активная (задан
/// [activeLabel]) — тонированная акцентом, краткая подпись выбора и ✕
/// ([onClear]). Нажатие на таблетку — [onTap] (открыть выбор).
/// Названо не `FilterChip`, чтобы не путать с Material.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.onTap,
    this.activeLabel,
    this.onClear,
    this.clearLabel,
    this.icon,
    this.compact = false,
  });

  final String label;

  /// Только значок [icon] и стрелка (подпись — для диктора): узкая строка.
  final bool compact;
  final VoidCallback? onTap;

  /// Подпись выбора («Критический +1»). null — фильтр не выбран.
  final String? activeLabel;
  final VoidCallback? onClear;

  /// Подпись крестика для экранного диктора.
  final String? clearLabel;
  final IconData? icon;

  bool get active => activeLabel != null;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.accentText : AppColors.ink;
    final text = Text(activeLabel ?? label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.footnote.copyWith(
            fontSize: 14,
            color: fg,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500));
    final body = Pressable(
      onTap: onTap,
      selected: active,
      semanticLabel: active ? '$label: $activeLabel' : label,
      // Имя узла — только semanticLabel, без повтора текста таблетки.
      child: ExcludeSemantics(
          child: Padding(
        padding: EdgeInsetsDirectional.only(
            start: icon != null ? 10 : 14, end: active ? 2 : 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            if (!compact) const SizedBox(width: 5),
          ],
          if (!(compact && icon != null))
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200), child: text),
          if (!active) ...[
            const SizedBox(width: 3),
            const Icon(AppIcons.chevronDown,
                size: 15, color: AppColors.secondary),
          ],
        ]),
      )),
    );
    return Container(
      height: AppSizes.filterChip,
      decoration: BoxDecoration(
          color: active ? AppColors.accentTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        body,
        if (active && onClear != null)
          Pressable(
            onTap: onClear,
            semanticLabel: clearLabel,
            child: const SizedBox(
              width: 30,
              height: AppSizes.filterChip,
              child:
                  Icon(AppIcons.close, size: 15, color: AppColors.accentText),
            ),
          ),
      ]),
    );
  }
}

/// Строка выбора с галочкой справа (в группе [AppGroup]): для
/// множественного и одиночного выбора. Вместо [title] можно передать
/// [child] (например [StatusPill]).
class AppCheckRow extends StatelessWidget {
  const AppCheckRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.leading,
    this.child,
    this.subtitle,
    this.partial = false,
  });

  final String title;
  final bool selected;

  /// Выбрана часть (например не все объекты города) — «полугалочка» (минус).
  final bool partial;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        checked: selected,
        mixed: !selected && partial ? true : null,
        child: Pressable(
          onTap: onTap,
          effect: PressEffect.highlight,
          semanticLabel: subtitle == null ? title : '$title, $subtitle',
          child: ExcludeSemantics(
              child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.rowMinHeight),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpace.rowH, vertical: AppSpace.rowV - 2),
              child: Row(children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpace.m),
                ],
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: child ??
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title, style: AppText.body),
                              if (subtitle != null)
                                Text(subtitle!, style: AppText.footnote),
                            ]),
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                SizedBox(
                  width: 22,
                  child: selected
                      ? const Icon(AppIcons.check,
                          size: 20, color: AppColors.accentText)
                      : partial
                          ? const Icon(AppIcons.remove,
                              size: 20, color: AppColors.accentText)
                          : null,
                ),
              ]),
            ),
          )),
        ),
      );
}

/// Содержимое окна фильтра (шторки или выпадающего окна): заголовок,
/// необязательная шапка ([header], например сегмент-контрол), поиск по
/// списку ([onSearch]), прокручиваемые [children] и кнопки
/// «Сбросить» / «Применить (N)».
class AppFilterPanel extends StatelessWidget {
  const AppFilterPanel({
    super.key,
    required this.title,
    required this.children,
    required this.resetLabel,
    required this.applyLabel,
    required this.onApply,
    this.onReset,
    this.header,
    this.searchHint,
    this.onSearch,
  });

  final String title;
  final List<Widget> children;
  final String resetLabel;
  final String applyLabel;
  final VoidCallback onApply;

  /// null — кнопки «Сбросить» нет.
  final VoidCallback? onReset;
  final Widget? header;
  final String? searchHint;

  /// Задан — над списком поле поиска.
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    const pad = AppSpace.screen;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(pad, 10, pad, 10),
          child: Semantics(
            header: true,
            child: Text(title,
                textAlign: TextAlign.center, style: AppText.headline),
          ),
        ),
        if (header != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(pad, 0, pad, 10),
            child: header,
          ),
        if (onSearch != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(pad, 0, pad, 10),
            child: AppSearchField(hint: searchHint ?? '', onChanged: onSearch!),
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(pad, 4, pad, pad),
            // «Сбросить» — по ширине текста, «Применить (N)» — всё остальное:
            // число на главной кнопке не обрезается и в узком окне.
            child: Row(children: [
              if (onReset != null) ...[
                AppButton.secondary(
                    label: resetLabel, onPressed: onReset, expand: false),
                const SizedBox(width: AppSpace.m),
              ],
              Expanded(
                child: AppButton.primary(label: applyLabel, onPressed: onApply),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Выпадающее окно под элементом [context] (на широком экране вместо
/// шторки): фон [AppColors.bg], скругление 16, тень плавающих элементов.
/// Закрывается нажатием мимо и клавишей Esc.
Future<T?> showAppPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 360,
  double maxHeight = 560,
}) {
  final box = context.findRenderObject() as RenderBox?;
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) {
    return showAppSheet<T>(context: context, builder: builder);
  }
  final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final rtl = Directionality.of(context) == TextDirection.rtl;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.popoverScrim,
    transitionDuration: AppMotion.fast,
    pageBuilder: (ctx, _, __) {
      final screen = MediaQuery.sizeOf(ctx);
      final w = width.clamp(0.0, screen.width - 2 * AppSpace.s);
      final left = (rtl ? anchor.right - w : anchor.left)
          .clamp(AppSpace.s, screen.width - w - AppSpace.s);
      final top = anchor.bottom + 6;
      final h = (screen.height - top - AppSpace.l).clamp(160.0, maxHeight);
      return Stack(children: [
        Positioned(
          left: left,
          top: top,
          width: w,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(AppRadius.group),
                  boxShadow: AppShadows.floating),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.group),
                child: Material(
                    type: MaterialType.transparency, child: builder(ctx)),
              ),
            ),
          ),
        ),
      ]);
    },
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: child,
    ),
  );
}

/// Открывает выбор фильтра: на широком экране (≥ [AppSpace.wideFrom]) —
/// выпадающее окно под [context], на узком — нижняя шторка.
Future<T?> showFilterPicker<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final wide = MediaQuery.sizeOf(context).width >= AppSpace.wideFrom;
  return wide
      ? showAppPopover<T>(context: context, builder: builder)
      : showAppSheet<T>(context: context, builder: builder);
}

/// Группа-обёртка без отступа снизу — для списков внутри [AppFilterPanel].
class AppPanelGroup extends StatelessWidget {
  const AppPanelGroup({super.key, required this.children, this.header});
  final List<Widget> children;
  final String? header;

  @override
  Widget build(BuildContext context) => AppGroup(
        header: header,
        separatorInset: AppSpace.rowH,
        children: children,
      );
}

/// Горизонтальная прокрутка с плавным затуханием у края, за которым есть
/// ещё содержимое (строка таблеток фильтров): видно, что её можно
/// прокрутить. Затухание — с той стороны, куда можно листать (с учётом RTL).
class AppFadingScroll extends StatefulWidget {
  const AppFadingScroll({super.key, required this.child, this.fade = 28});
  final Widget child;

  /// Ширина затухания, px.
  final double fade;

  @override
  State<AppFadingScroll> createState() => _AppFadingScrollState();
}

class _AppFadingScrollState extends State<AppFadingScroll> {
  final _c = ScrollController();
  bool _start = false;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_c.hasClients) return;
    final p = _c.position;
    final start = p.pixels > 1;
    final end = p.pixels < p.maxScrollExtent - 1;
    if (start != _start || end != _end) {
      setState(() {
        _start = start;
        _end = end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scroll = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _update();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _update();
          return false;
        },
        child: SingleChildScrollView(
          controller: _c,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        ),
      ),
    );
    if (!_start && !_end) return scroll;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final f = (widget.fade / w).clamp(0.0, 0.5);
      const solid = Color(0xFF000000);
      const clear = Color(0x00000000);
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [_start ? clear : solid, solid, solid, _end ? clear : solid],
          stops: [0, f, 1 - f, 1],
        ).createShader(rect, textDirection: Directionality.of(context)),
        child: scroll,
      );
    });
  }
}
