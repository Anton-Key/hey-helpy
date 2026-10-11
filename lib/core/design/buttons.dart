import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;

import 'pressable.dart';
import 'tokens.dart';

/// Вид кнопки-капсулы.
enum AppButtonKind {
  /// Главная: акцент, текст [AppColors.onAccent].
  primary,

  /// Тонированная: [AppColors.accentTint], текст [AppColors.accentText].
  tinted,

  /// Вторичная: [AppColors.fill], текст [AppColors.ink].
  secondary,

  /// Опасная: серая, текст [AppColors.danger] (5.3:1).
  destructive,

  /// Только текст акцентного цвета (ссылка-кнопка).
  plain,
}

/// Кнопка-капсула. Нажатие — масштаб 0.97, без «волны».
/// [onPressed] == null — неактивна (бледнее). [loading] — крутилка вместо
/// текста, кнопка не нажимается.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.expand = true,
    this.small = false,
    this.loading = false,
  });

  const AppButton.primary(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.expand = true,
      this.small = false,
      this.loading = false})
      : kind = AppButtonKind.primary;

  const AppButton.tinted(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.expand = true,
      this.small = false,
      this.loading = false})
      : kind = AppButtonKind.tinted;

  const AppButton.secondary(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.expand = true,
      this.small = false,
      this.loading = false})
      : kind = AppButtonKind.secondary;

  const AppButton.destructive(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.expand = true,
      this.small = false,
      this.loading = false})
      : kind = AppButtonKind.destructive;

  const AppButton.plain(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.expand = false,
      this.small = false,
      this.loading = false})
      : kind = AppButtonKind.plain;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;

  /// true — на всю ширину.
  final bool expand;

  /// Маленькая капсула 32 (например «Сменить» в строке).
  final bool small;
  final bool loading;

  static (Color, Color) colors(AppButtonKind kind) => switch (kind) {
        AppButtonKind.primary => (AppColors.accent, AppColors.onAccent),
        AppButtonKind.tinted => (AppColors.accentTint, AppColors.accentText),
        AppButtonKind.secondary => (AppColors.fill, AppColors.ink),
        AppButtonKind.destructive => (AppColors.fill, AppColors.danger),
        AppButtonKind.plain => (const Color(0x00000000), AppColors.accentText),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(kind);
    final enabled = onPressed != null && !loading;
    final height = small ? AppSizes.buttonSmallHeight : AppSizes.buttonHeight;
    final text = (small ? AppText.callout : AppText.headline)
        .copyWith(color: fg, fontWeight: FontWeight.w600);
    final content = loading
        ? CupertinoActivityIndicator(color: fg)
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon,
                  size: small ? AppSizes.iconS : AppSizes.icon, color: fg),
              SizedBox(width: small ? 6 : 8),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text),
            ),
          ]);
    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: EdgeInsetsDirectional.symmetric(
              horizontal: small ? 14 : (kind == AppButtonKind.plain ? 8 : 22)),
          // Container с alignment занимает всю ширину родителя — у кнопки
          // «по размеру» (expand: false) центрируем через Center шириной по
          // содержимому (шаг 18: в Wrap кнопки растягивались на всю строку).
          alignment: expand ? Alignment.center : null,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: expand ? content : Center(widthFactor: 1, child: content),
        ),
      ),
    );
  }
}

/// Круглая кнопка-значок: белая (в шапке, на карте) или серая [filled].
/// [label] — подпись для диктора и подсказка (обязательна: у значка нет
/// текста).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 36,
    this.filled = false,
    this.accent = false,
    this.shadow = false,
    this.badge = 0,
    this.color,
    this.tooltip = false,
  });

  /// Подсказка [label] при наведении мышью (служебные кнопки на ПК).
  final bool tooltip;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Диаметр: 36 в шапке, 44–48 на карте, 52 в нижней панели.
  final double size;

  /// true — фон [AppColors.fill], иначе белый.
  final bool filled;

  /// true — фон акцент (главное действие).
  final bool accent;

  /// Тень — только у плавающих кнопок (поверх карты).
  final bool shadow;

  /// Число в красном кружке (колокольчик). 0 — без кружка.
  final int badge;

  /// Цвет значка (по умолчанию — [AppColors.ink]).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = accent
        ? AppColors.accent
        : (filled ? AppColors.fill : AppColors.surface);
    final fg = color ?? (accent ? AppColors.onAccent : AppColors.ink);
    final iconSize = size >= 48 ? AppSizes.iconL : (size <= 32 ? 18.0 : 20.0);
    final button = Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: label,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: shadow ? AppShadows.floating : null,
              ),
              child: Icon(icon, size: iconSize, color: fg),
            ),
            if (badge > 0)
              PositionedDirectional(
                top: -3,
                end: -3,
                child: CountBadge(badge),
              ),
          ]),
        ),
      ),
    );
    return tooltip
        ? Tooltip(message: label, excludeFromSemantics: true, child: button)
        : button;
  }
}

/// Красный кружок с числом (новые уведомления).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
        child: Text(count > 99 ? '99+' : '$count',
            style: AppText.caption.copyWith(
                color: AppColors.surface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1)),
      );
}
