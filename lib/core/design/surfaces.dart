import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'buttons.dart';
import 'icons.dart';
import 'nav_bar.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Вкладка нижнего меню.
class AppTab {
  const AppTab(
      {required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Нижнее меню вкладок: полупрозрачное с размытием, тонкая линия сверху.
/// Активная — [AppColors.accentText] и значок с линией толще, неактивные —
/// [AppColors.tabInactive], подписи 11.
class AppTabBar extends StatelessWidget {
  const AppTabBar(
      {super.key,
      required this.tabs,
      required this.index,
      required this.onChanged});

  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return FrostedBar(
      borderTop: true,
      child: SafeArea(
        top: false,
        child: Semantics(
          role: SemanticsRole.tabBar,
          explicitChildNodes: true,
          child: SizedBox(
            height: AppSizes.tabBar,
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++) Expanded(child: _tab(i)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final t = tabs[i];
    final on = i == index;
    final color = on ? AppColors.accentText : AppColors.tabInactive;
    return Semantics(
      role: SemanticsRole.tab,
      selected: on,
      container: true,
      label: t.label,
      onTap: () => onChanged(i),
      excludeSemantics: true,
      child: Pressable(
        button: false,
        onTap: () => onChanged(i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(on ? t.activeIcon : t.icon, size: AppSizes.iconL, color: color),
          const SizedBox(height: 3),
          Text(t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.tabLabel.copyWith(
                  color: color,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// Голосовая кнопка: капсула с микрофоном и названием «Эй, Helpy»
/// (56, акцент, акцентная тень) и рядом маленькая белая круглая «+»
/// (ручное создание заявки). Под ней у списков нужен отступ
/// [AppSizes.fabClearance].
class VoiceButton extends StatelessWidget {
  const VoiceButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onVoice,
    required this.addLabel,
    required this.onAdd,
  });

  /// Текст на капсуле (`appName`).
  final String label;

  /// Имя для диктора («Нажми и говори»).
  final String semanticLabel;
  final VoidCallback onVoice;
  final String addLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (onAdd != null) ...[
        AppIconButton(
            icon: AppIcons.add,
            label: addLabel,
            onPressed: onAdd,
            size: 48,
            shadow: true),
        const SizedBox(width: AppSpace.m),
      ],
      Pressable(
        onTap: onVoice,
        semanticLabel: semanticLabel,
        child: Container(
          height: AppSizes.voiceHeight,
          padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 24, 0),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.voice,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(AppIcons.mic, size: 24, color: AppColors.onAccent),
            const SizedBox(width: 8),
            Text(label,
                style: AppText.headline.copyWith(color: AppColors.onAccent)),
          ]),
        ),
      ),
    ]);
  }
}

/// Нижняя панель с главной кнопкой экрана: полупрозрачная с размытием,
/// тонкая линия сверху. Ставится под прокручиваемой областью (в Column тела
/// Scaffold или в [AppScaffold.bottomBar]) — видна при любой высоте окна и
/// поднимается с клавиатурой. Ширина содержимого — до [maxWidth] по центру.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar(
      {super.key, required this.child, this.maxWidth = AppSpace.contentMax});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => FrostedBar(
        borderTop: true,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, 10, AppSpace.screen, 10),
            child: ContentWidth(maxWidth: maxWidth, child: child),
          ),
        ),
      );
}

/// Шапка шторки: «Отмена · Заголовок · [Готово]».
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.cancelLabel,
    this.onCancel,
    this.doneLabel,
    this.onDone,
    this.doneLoading = false,
  });

  final String title;
  final String? cancelLabel;
  final VoidCallback? onCancel;
  final String? doneLabel;
  final VoidCallback? onDone;
  final bool doneLoading;

  @override
  Widget build(BuildContext context) {
    final cancel =
        cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel;
    return SizedBox(
      height: AppSizes.navBar + 4,
      child: NavigationToolbar(
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpace.screen),
          child: AppBarTextButton(
              label: _cap(cancel),
              onPressed: onCancel ?? () => Navigator.maybePop(context)),
        ),
        middle: Semantics(
          header: true,
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline),
        ),
        trailing: doneLabel == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.screen),
                child: AppBarTextButton(
                    label: doneLabel!,
                    strong: true,
                    loading: doneLoading,
                    onPressed: onDone),
              ),
        middleSpacing: AppSpace.s,
      ),
    );
  }

  // Материальные подписи бывают прописными («ОТМЕНА»).
  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

/// «Язычок» шторки 36×5.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Center(
          child: Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
                color: AppColors.grabber,
                borderRadius: BorderRadius.circular(AppRadius.pill)),
          ),
        ),
      );
}

/// Открывает нижнюю шторку: фон [AppColors.bg], верхние углы 14, язычок.
/// Шапку ([SheetHeader]) и содержимое строит [builder]. На широком окне
/// шторка не шире [AppSpace.contentMax].
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: AppColors.bg,
    barrierColor: AppColors.scrim,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: AppSpace.contentMax),
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    clipBehavior: Clip.antiAlias,
    // На всю ширину шторки: иначе она сжимается до ширины содержимого.
    builder: (ctx) => SizedBox(
      width: double.infinity,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            Flexible(child: builder(ctx)),
          ]),
    ),
  );
}

/// Плитка показателя (Отчёты): белая r16, число 30 w700, подпись footnote.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    this.valueColor,
  });

  final String value;
  final String label;

  /// Мелкая строка под подписью (например «из 24»).
  final String? hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.group)),
        child: MergeSemantics(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    maxLines: 1,
                    style: AppText.kpi.copyWith(color: valueColor)),
                const SizedBox(height: 2),
                Text(label, style: AppText.footnote),
                if (hint != null)
                  Text(hint!,
                      style:
                          AppText.caption.copyWith(color: AppColors.secondary)),
              ]),
        ),
      );
}

/// Крутилка загрузки по центру (стиль iOS).
class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CupertinoActivityIndicator(radius: 12));
}

/// Пустое состояние или ошибка: значок, текст и необязательная кнопка.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.text,
    this.icon = AppIcons.inbox,
    this.actionLabel,
    this.onAction,
    this.error = false,
  });

  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Ошибка: значок и текст — красным.
  final bool error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(error ? AppIcons.error : icon,
                size: 36, color: error ? AppColors.danger : AppColors.tertiary),
            const SizedBox(height: AppSpace.m),
            Text(text,
                textAlign: TextAlign.center,
                style: AppText.callout.copyWith(
                    color: error ? AppColors.danger : AppColors.secondary)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.l),
              AppButton.tinted(
                  label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ]),
        ),
      );
}

/// Действие диалога.
class AppDialogAction<T> {
  const AppDialogAction(this.label, this.value,
      {this.destructive = false, this.primary = false});
  final String label;
  final T value;
  final bool destructive;
  final bool primary;
}

/// Диалог подтверждения в стиле iOS: белая карточка r16, заголовок 17 w600,
/// текст, кнопки-капсулы. Возвращает value нажатой кнопки или null.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  required List<AppDialogAction<T>> actions,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: const Color(0x00000000),
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpace.xl),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.group)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    textAlign: TextAlign.center, style: AppText.headline),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: AppText.footnote.copyWith(fontSize: 14)),
                ],
                if (content != null) ...[
                  const SizedBox(height: AppSpace.m),
                  content,
                ],
                const SizedBox(height: 18),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s),
                  AppButton(
                    label: actions[i].label,
                    kind: actions[i].destructive
                        ? AppButtonKind.destructive
                        : (actions[i].primary
                            ? AppButtonKind.primary
                            : AppButtonKind.secondary),
                    small: false,
                    onPressed: () => Navigator.pop(ctx, actions[i].value),
                  ),
                ],
              ]),
        ),
      ),
    ),
  );
}
