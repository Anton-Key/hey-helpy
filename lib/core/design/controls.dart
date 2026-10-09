import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import 'icons.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Капсула статуса заявки высотой 24: цветная точка (у «Принята» —
/// галочка) и подпись. Цвета — [StatusColors]. [label] — свой текст
/// (например «Просрочена» или приоритет), иначе перевод статуса.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label, this.large = false});
  final String status;
  final String? label;

  /// Чуть крупнее — в шапке карточки заявки (28).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = StatusColors.of(status);
    final height = large ? 28.0 : AppSizes.pillHeight;
    return Container(
      height: height,
      padding: EdgeInsetsDirectional.symmetric(horizontal: large ? 11 : 9),
      decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == 'done')
          Icon(AppIcons.check, size: large ? 14 : 13, color: c.foreground)
        else
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: c.foreground, shape: BoxShape.circle),
          ),
        SizedBox(width: status == 'done' ? 4 : 6),
        Text(label ?? context.l10n.status(status),
            maxLines: 1,
            softWrap: false,
            style: AppText.caption.copyWith(
                fontSize: large ? 13 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: c.foreground)),
      ]),
    );
  }
}

/// Капсула приоритета с точкой (в шапке карточки заявки).
class PriorityPill extends StatelessWidget {
  const PriorityPill(this.priority, {super.key, this.large = false});
  final String priority;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final height = large ? 28.0 : AppSizes.pillHeight;
    return Container(
      height: height,
      padding: EdgeInsetsDirectional.symmetric(horizontal: large ? 11 : 9),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: AppColors.priority(priority), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(context.l10n.priority(priority),
            maxLines: 1,
            softWrap: false,
            style: AppText.caption.copyWith(
                fontSize: large ? 13 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: AppColors.ink)),
      ]),
    );
  }
}

/// Сегмент сегмент-контрола.
class Segment<T> {
  const Segment(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Сегмент-контрол как в iOS: серая дорожка, выбранный сегмент — белый
/// с мягкой тенью, плавно переезжает.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = true,
  });

  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// true — на всю ширину, сегменты равной ширины.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final index = segments.indexWhere((s) => s.value == selected);
    Widget cell(int i) {
      final s = segments[i];
      final on = i == index;
      final style = AppText.footnote.copyWith(
          color: AppColors.ink,
          fontSize: 13,
          fontWeight: on ? FontWeight.w600 : FontWeight.w500);
      return Pressable(
        onTap: on ? () {} : () => onChanged(s.value),
        selected: on,
        child: Container(
          height: AppSizes.segmentHeight - 4,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (s.icon != null) ...[
              Icon(s.icon, size: 16, color: AppColors.ink),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(s.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
            ),
          ]),
        ),
      );
    }

    return Container(
      height: AppSizes.segmentHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.segmentTrack)),
      child: LayoutBuilder(builder: (context, c) {
        if (!expand) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < segments.length; i++)
              Container(
                decoration: i == index ? _thumb : null,
                child: cell(i),
              ),
          ]);
        }
        final w = c.maxWidth / segments.length;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        return Stack(children: [
          if (index >= 0)
            AnimatedPositioned(
              duration: AppMotion.normal,
              curve: Curves.easeOutCubic,
              left: rtl ? null : w * index,
              right: rtl ? w * index : null,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(decoration: _thumb),
            ),
          Row(children: [
            for (var i = 0; i < segments.length; i++) Expanded(child: cell(i)),
          ]),
        ]);
      }),
    );
  }

  static final _thumb = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.segmentThumb),
      boxShadow: AppShadows.segment);
}

/// Поле поиска: залитое, высота 38, значок лупы, крестик очистки.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _c =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.searchHeight,
      child: TextField(
        controller: _c,
        autofocus: widget.autofocus,
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v);
        },
        textInputAction: TextInputAction.search,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppText.body.copyWith(color: AppColors.secondary),
          filled: true,
          fillColor: AppColors.fill,
          isDense: true,
          contentPadding: EdgeInsetsDirectional.zero,
          prefixIcon: const Icon(AppIcons.search,
              size: AppSizes.iconS, color: AppColors.secondary),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: _c.text.isEmpty
              ? null
              : Pressable(
                  semanticLabel:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  onTap: () {
                    _c.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                  child: const Icon(AppIcons.close,
                      size: 16, color: AppColors.secondary),
                ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

/// Чип-выбор (вид работ, тип объекта, фильтр): капсула. Выбранный —
/// акцентный с галочкой, невыбранный — белый.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onSurface = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// true — чип лежит на белой группе: невыбранный тогда серый (fill).
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.accent
        : (onSurface ? AppColors.fill : AppColors.surface);
    final fg = selected ? AppColors.onAccent : AppColors.ink;
    return Pressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        height: 34,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 5),
              child: Icon(AppIcons.check, size: 16, color: AppColors.onAccent),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: Icon(icon, size: 16, color: fg),
            ),
          Text(label,
              style: AppText.callout.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// Плашка-фильтр с крестиком (например «Объект: БЦ «Демо» ✕»).
class FilterTag extends StatelessWidget {
  const FilterTag(
      {super.key,
      required this.label,
      required this.onClear,
      required this.clearLabel,
      this.icon});
  final String label;
  final VoidCallback onClear;
  final String clearLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.accentText),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.footnote.copyWith(
                    color: AppColors.accentText, fontWeight: FontWeight.w600)),
          ),
          Pressable(
            onTap: onClear,
            semanticLabel: clearLabel,
            child: const SizedBox(
              width: 28,
              height: 28,
              child:
                  Icon(AppIcons.close, size: 16, color: AppColors.accentText),
            ),
          ),
        ]),
      );
}
