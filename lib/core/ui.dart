import 'package:flutter/material.dart';

import 'directional.dart';
import 'theme.dart';

const _line = Color(0xFFE8EAED);
const _muted = Color(0xFF8A9098);

/// Белая карточка с рамкой. Если задан [onTap] — с эффектом нажатия
/// (Material + InkWell: у Container с заливкой волна не видна) и,
/// при [chevron], со стрелкой «дальше» в конце строки.
class TapCard extends StatelessWidget {
  const TapCard({
    super.key,
    required this.child,
    this.onTap,
    this.chevron = true,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsetsDirectional.only(bottom: 10),
    this.radius = 16,
    this.color = Colors.white,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool chevron;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: _line));
    final content = onTap != null && chevron
        ? Row(children: [
            Expanded(child: child),
            const SizedBox(width: 6),
            const ChevronEnd(color: _muted, size: 20),
          ])
        : child;
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: content),
        ),
      ),
    );
  }
}

/// Плашка-выбор (вид работ, срочность, тип объекта) с эффектом нажатия.
class ChoiceTag extends StatelessWidget {
  const ChoiceTag(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.filled = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// true — выбранная плашка залита бирюзовым (текст тёмно-зелёный),
  /// false — светло-мятная с тёмно-зелёной рамкой и текстом.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = !selected
        ? Colors.white
        : (filled ? HeyHelpyTheme.brand : const Color(0xFFE8F6F2));
    final fg = !selected
        ? HeyHelpyTheme.ink
        : (filled ? HeyHelpyTheme.onBrand : HeyHelpyTheme.link);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: selected
                  ? (filled ? HeyHelpyTheme.brand : HeyHelpyTheme.link)
                  : _line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}

/// Заголовок раздела в карточке.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 20, bottom: 10),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: HeyHelpyTheme.ink)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Стиль бирюзовой кнопки: текст тёмно-зелёный (белый на бирюзовом
/// не проходит по контрасту).
ButtonStyle brandButtonStyle() => FilledButton.styleFrom(
    backgroundColor: HeyHelpyTheme.brand,
    foregroundColor: HeyHelpyTheme.onBrand);

/// Нижняя панель с главной кнопкой экрана: всегда видна, при любой высоте
/// окна. Ставится под прокручиваемую область в Column тела Scaffold (а не в
/// bottomNavigationBar — ту закрывает клавиатура), поэтому с открытой
/// клавиатурой поднимается вместе с ней. Ширина — как у колонки
/// содержимого: до [maxWidth] по центру.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
            color: Colors.white, border: Border(top: BorderSide(color: _line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child),
            ),
          ),
        ),
      );
}
