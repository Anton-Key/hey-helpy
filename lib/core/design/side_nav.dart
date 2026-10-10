import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'buttons.dart';
import 'icons.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Раскладка главного меню по ширине окна.
enum AppNavLayout {
  /// Телефон (< [AppSpace.wideFrom]): нижнее меню и плавающие кнопки.
  bottom,

  /// Узкая колонка слева (80): значки с подписями под ними.
  rail,

  /// Широкая колонка слева (240): значки и подписи в строку.
  sidebar,
}

/// Ширина, с которой колонка слева по умолчанию широкая.
const kSidebarFrom = 1200.0;

/// Ширина колонки: широкой и узкой.
const kSidebarWidth = 240.0;
const kRailWidth = 80.0;

/// Раскладка по ширине окна: < 900 — нижнее меню, 900–1199 — узкая колонка,
/// ≥ 1200 — широкая. [collapsed] — выбор пользователя кнопкой «Свернуть»
/// (null — по ширине): true — узкая, false — широкая (на телефоне не влияет).
AppNavLayout appNavLayoutFor(double width, {bool? collapsed}) {
  if (width < AppSpace.wideFrom) return AppNavLayout.bottom;
  if (collapsed != null) {
    return collapsed ? AppNavLayout.rail : AppNavLayout.sidebar;
  }
  return width >= kSidebarFrom ? AppNavLayout.sidebar : AppNavLayout.rail;
}

/// Пункт бокового меню.
class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Число в красном кружке (просроченные заявки). 0 — без кружка.
  final int badge;
}

/// Боковое меню ПК: сверху название продукта, пункты меню, под ними кнопки
/// создания — акцентная «Эй, Helpy» и вторичная «+ Заявка»; внизу —
/// «Свернуть / Развернуть». [rail] — узкая колонка (значки, подписи под
/// ними, круглые кнопки с подсказкой при наведении).
class AppSideNav extends StatelessWidget {
  const AppSideNav({
    super.key,
    required this.brand,
    required this.items,
    required this.index,
    required this.onChanged,
    required this.voiceLabel,
    required this.voiceSemantic,
    required this.onVoice,
    required this.addLabel,
    required this.onAdd,
    required this.rail,
    required this.toggleLabel,
    required this.onToggle,
  });

  final String brand;
  final List<AppNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final String voiceLabel;
  final String voiceSemantic;
  final VoidCallback onVoice;
  final String addLabel;
  final VoidCallback? onAdd;
  final bool rail;

  /// «Свернуть меню» / «Развернуть меню».
  final String toggleLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final pad = rail ? AppSpace.s : AppSpace.l;
    return Container(
      width: rail ? kRailWidth : kSidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: BorderDirectional(
            end: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(pad, 0, pad, AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: rail
                      ? Alignment.center
                      : AlignmentDirectional.centerStart,
                  child: rail
                      ? const Icon(AppIcons.mic,
                          size: AppSizes.iconL, color: AppColors.accentText)
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(
                              start: AppSpace.s),
                          child: Text(brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title2
                                  .copyWith(color: AppColors.accentText)),
                        ),
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Semantics(
                role: SemanticsRole.tabBar,
                explicitChildNodes: true,
                child: Column(children: [
                  for (var i = 0; i < items.length; i++) _item(i),
                ]),
              ),
              const SizedBox(height: AppSpace.l),
              if (rail) ...[
                Center(
                  child: AppIconButton(
                      icon: AppIcons.mic,
                      label: voiceLabel,
                      accent: true,
                      size: 52,
                      tooltip: true,
                      onPressed: onVoice),
                ),
                if (onAdd != null) ...[
                  const SizedBox(height: AppSpace.m),
                  Center(
                    child: AppIconButton(
                        icon: AppIcons.add,
                        label: addLabel,
                        filled: true,
                        size: 44,
                        tooltip: true,
                        onPressed: onAdd),
                  ),
                ],
              ] else ...[
                Semantics(
                  button: true,
                  label: voiceSemantic,
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: onVoice,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpace.l),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: AppShadows.voice,
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(AppIcons.mic,
                                size: AppSizes.iconL,
                                color: AppColors.onAccent),
                            const SizedBox(width: AppSpace.s),
                            Flexible(
                              child: Text(voiceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.headline
                                      .copyWith(color: AppColors.onAccent)),
                            ),
                          ]),
                    ),
                  ),
                ),
                if (onAdd != null) ...[
                  const SizedBox(height: AppSpace.m),
                  AppButton.secondary(
                      label: addLabel,
                      icon: AppIcons.add,
                      expand: true,
                      onPressed: onAdd),
                ],
              ],
              const Spacer(),
              Align(
                alignment:
                    rail ? Alignment.center : AlignmentDirectional.centerStart,
                child: AppIconButton(
                    icon: rail ? AppIcons.panelOpen : AppIcons.panelClose,
                    label: toggleLabel,
                    filled: true,
                    tooltip: true,
                    onPressed: onToggle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final t = items[i];
    final on = i == index;
    final color = on ? AppColors.accentText : AppColors.secondary;
    final icon = Stack(clipBehavior: Clip.none, children: [
      Icon(on ? t.activeIcon : t.icon, size: AppSizes.iconL, color: color),
      if (t.badge > 0 && rail)
        PositionedDirectional(top: -6, end: -10, child: CountBadge(t.badge)),
    ]);
    final label = Text(t.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: rail ? TextAlign.center : TextAlign.start,
        style: (rail ? AppText.tabLabel : AppText.body).copyWith(
            color: on ? AppColors.accentText : AppColors.ink,
            fontWeight: on ? FontWeight.w600 : FontWeight.w500));
    return Semantics(
      role: SemanticsRole.tab,
      selected: on,
      container: true,
      label: t.badge > 0 ? '${t.label}, ${t.badge}' : t.label,
      onTap: () => onChanged(i),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppSpace.xs),
        child: Pressable(
          button: false,
          onTap: () => onChanged(i),
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Container(
            height: rail ? 60 : AppSizes.minTap,
            padding: EdgeInsetsDirectional.symmetric(
                horizontal: rail ? AppSpace.xs : AppSpace.m),
            decoration: BoxDecoration(
              color: on ? AppColors.accentTint : null,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: rail
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [icon, const SizedBox(height: 3), label])
                : Row(children: [
                    icon,
                    const SizedBox(width: AppSpace.m),
                    Expanded(child: label),
                    if (t.badge > 0) CountBadge(t.badge),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Таблетка «Компания · роль» в служебной строке ПК: сразу видно, под кем
/// вход.
class AppContextPill extends StatelessWidget {
  const AppContextPill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpace.m),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.separator),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.footnote
                .copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
      );
}

/// Маленький переключатель языка «RU | EN» в служебной строке ПК.
class AppLangSwitch extends StatelessWidget {
  const AppLangSwitch({
    super.key,
    required this.codes,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
  });

  /// Коды языков: ru, en.
  final List<String> codes;
  final String selected;
  final ValueChanged<String> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        container: true,
        child: Container(
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final c in codes)
              Semantics(
                button: true,
                selected: c == selected,
                child: Pressable(
                  onTap: c == selected ? null : () => onChanged(c),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    width: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c == selected ? AppColors.surface : null,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(c.toUpperCase(),
                        style: AppText.caption.copyWith(
                            color: c == selected
                                ? AppColors.ink
                                : AppColors.secondary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ]),
        ),
      );
}
