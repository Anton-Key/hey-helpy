import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Стрелка «дальше». При письме справа налево смотрит в другую сторону.
class ChevronEnd extends StatelessWidget {
  const ChevronEnd({super.key, this.color, this.size});
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) => Icon(
        Directionality.of(context) == TextDirection.rtl
            ? AppIcons.chevronLeft
            : AppIcons.chevronRight,
        color: color ?? AppColors.tertiary,
        size: size ?? 20,
      );
}

/// Подпись секции над группой: 13 w600 ПРОПИСНЫМИ, вторичным цветом.
/// [trailing] — действие справа (например «Добавить»).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing, this.padding});
  final String text;
  final Widget? trailing;

  /// По умолчанию: сверху 20, снизу 8, по бокам 16 (как строки группы).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ??
            const EdgeInsetsDirectional.fromSTEB(
                AppSpace.rowH, 20, AppSpace.rowH, AppSpace.s),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text.toUpperCase(), style: AppText.section),
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// «Сгруппированный список» как в Настройках iOS: белый блок с радиусом 16,
/// строки [children] одна под другой, между ними — разделители с отступом
/// слева [separatorInset] (под текстом, а не под значком). Без тени и рамки.
///
/// [header] — подпись секции над блоком, [footer] — пояснение под ним.
class AppGroup extends StatelessWidget {
  const AppGroup({
    super.key,
    required this.children,
    this.header,
    this.headerTrailing,
    this.footer,
    this.separatorInset,
    this.margin = const EdgeInsetsDirectional.only(bottom: AppSpace.group),
    this.padding = EdgeInsets.zero,
    this.compactHeader = false,
  });

  /// Подпись секции ближе к блоку (сверху 8, снизу 4) — длинные списки.
  final bool compactHeader;

  final List<Widget> children;
  final String? header;
  final Widget? headerTrailing;
  final String? footer;

  /// Отступ разделителя слева. По умолчанию: [AppSpace.rowH], а если первая
  /// строка — [AppRow] со значком, то до текста.
  final double? separatorInset;
  final EdgeInsetsGeometry margin;

  /// Внутренний отступ блока (для групп с произвольным содержимым).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final inset = separatorInset ??
        (children.isNotEmpty &&
                children.first is AppRow &&
                (children.first as AppRow).leading != null
            ? AppSpace.separatorInsetIcon
            : AppSpace.rowH);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(AppSeparator(inset: inset));
      rows.add(children[i]);
    }
    return Padding(
      padding: margin,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null)
              SectionHeader(header!,
                  trailing: headerTrailing,
                  padding: compactHeader
                      ? const EdgeInsetsDirectional.fromSTEB(
                          AppSpace.rowH, AppSpace.s, AppSpace.rowH, AppSpace.xs)
                      : null),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.group),
              child: ColoredBox(
                color: AppColors.surface,
                child: Padding(
                  padding: padding,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: rows),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.rowH, 6, AppSpace.rowH, 0),
                child: Text(footer!, style: AppText.footnote),
              ),
          ]),
    );
  }
}

/// Тонкий разделитель строк с отступом слева.
class AppSeparator extends StatelessWidget {
  const AppSeparator({super.key, this.inset = AppSpace.rowH});
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(start: inset),
        child: const SizedBox(
          height: 0.5,
          width: double.infinity,
          child: ColoredBox(color: AppColors.separator),
        ),
      );
}

/// Значок в тонированном квадрате 30×30 со скруглением 8 — ведущий элемент
/// строки.
class LeadingIcon extends StatelessWidget {
  const LeadingIcon(this.icon,
      {super.key,
      this.color = AppColors.accentText,
      this.background = AppColors.accentTint});
  final IconData icon;
  final Color color;
  final Color background;

  /// Серый вариант (для нейтральных строк).
  const LeadingIcon.neutral(this.icon, {super.key})
      : color = AppColors.secondary,
        background = AppColors.fill;

  /// Красный вариант (опасные строки).
  const LeadingIcon.danger(this.icon, {super.key})
      : color = AppColors.danger,
        background = AppColors.dangerTint;

  @override
  Widget build(BuildContext context) => Container(
        width: AppSizes.iconTile,
        height: AppSizes.iconTile,
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.iconTile)),
        child: Icon(icon, size: AppSizes.iconS, color: color),
      );
}

/// Квадрат с инициалами (подрядчик, сотрудник) — как [LeadingIcon].
class InitialsTile extends StatelessWidget {
  const InitialsTile(this.name, {super.key, this.size = AppSizes.iconTile});
  final String name;
  final double size;

  static String initials(String name) {
    final words = name
        .replaceAll(RegExp(r'[«»"“”()]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final a = words.first.characters.first;
    final b = words.length > 1 ? words[1].characters.first : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: BorderRadius.circular(size * 0.27)),
        child: Text(initials(name),
            style: AppText.caption.copyWith(
                color: AppColors.accentText,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4)),
      );
}

/// Точка приоритета 10×10: critical — красная, high — оранжевая,
/// остальные — серая.
class PriorityDot extends StatelessWidget {
  const PriorityDot(this.priority, {super.key, this.size = 10});
  final String priority;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.priority(priority), shape: BoxShape.circle),
      );
}

/// Строка сгруппированного списка.
///
/// [leading] — [LeadingIcon], [PriorityDot] или [InitialsTile];
/// [title] + необязательный [subtitle]; [trailing] — значение, статус или
/// кнопка; [value] — короткий текст значения справа (вторичным цветом).
/// Если задан [onTap] — нажимается вся строка (лёгкое затемнение) и,
/// при [chevron], в конце стрелка «дальше».
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.onLongPress,
    this.chevron = true,
    this.destructive = false,
    this.titleStyle,
    this.subtitleMaxLines = 2,
    this.extra,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool chevron;

  /// Красный текст («Удалить», «Выйти»).
  final bool destructive;
  final TextStyle? titleStyle;
  final int subtitleMaxLines;

  /// Дополнительное содержимое под подзаголовком (полоска, пометки).
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(title,
        style: (titleStyle ?? AppText.rowTitle)
            .copyWith(color: destructive ? AppColors.danger : null));
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.rowMinHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.rowH, vertical: AppSpace.rowV - 1),
        // Значение справа — не шире половины строки: иначе на узком экране
        // (360) заголовок слева сжимался до переносов по буквам («Адре/с»).
        child: LayoutBuilder(
            builder: (context, box) => Row(children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpace.m),
                  ],
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleText,
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(top: 2),
                              child: Text(subtitle!,
                                  maxLines: subtitleMaxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.footnote),
                            ),
                          if (extra != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(top: 6),
                              child: extra!,
                            ),
                        ]),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: AppSpace.s),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: math.min(200, box.maxWidth * 0.5)),
                      child: Text(value!,
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body
                              .copyWith(color: AppColors.secondary)),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpace.s),
                    trailing!,
                  ],
                  if (onTap != null && chevron) ...[
                    const SizedBox(width: AppSpace.xs),
                    const ChevronEnd(),
                  ],
                ])),
      ),
    );
    if (onTap == null && onLongPress == null) {
      return MergeSemantics(child: row);
    }
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      effect: PressEffect.highlight,
      child: row,
    );
  }
}

/// Карточка без строк: белый блок r16 с отступом 16 (для свободного
/// содержимого — описание, график, форма). Если задан [onTap] — нажимается
/// с затемнением.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.l),
    this.margin = const EdgeInsetsDirectional.only(bottom: AppSpace.group),
    this.color = AppColors.surface,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.group),
      child: ColoredBox(
        color: color,
        child: Padding(padding: padding, child: child),
      ),
    );
    return Padding(
      padding: margin,
      child: onTap == null
          ? box
          : Pressable(
              onTap: onTap,
              effect: PressEffect.highlight,
              borderRadius: BorderRadius.circular(AppRadius.group),
              child: box),
    );
  }
}
