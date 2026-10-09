import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'icons.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Полупрозрачный фон с размытием (шапка, нижнее меню, панель действий).
class FrostedBar extends StatelessWidget {
  const FrostedBar({
    super.key,
    required this.child,
    this.borderTop = false,
    this.borderBottom = false,
    this.borderOpacity = 1,
  });

  final Widget child;
  final bool borderTop;
  final bool borderBottom;

  /// Прозрачность тонкой линии (0 — не видна; шапка показывает её при
  /// прокрутке).
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(
        color: AppColors.separator.withValues(alpha: borderOpacity),
        width: 0.5);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bar,
            border: Border(
              top: borderTop ? line : BorderSide.none,
              bottom: borderBottom ? line : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Кнопка «назад» в шапке: шеврон и подпись предыдущего экрана акцентом.
/// Подпись — [label], иначе название предыдущего экрана (из [appRoute]
/// с `title`), иначе «Назад».
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.label, this.onPressed});
  final String? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final previous = route is AppPageRoute ? route.backLabel : null;
    final text = label ??
        ((previous != null && previous.isNotEmpty)
            ? previous
            : MaterialLocalizations.of(context).backButtonTooltip);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Pressable(
      onTap: onPressed ?? () => Navigator.maybePop(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.navBar),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(rtl ? AppIcons.chevronRight : AppIcons.chevronLeft,
              size: 26, color: AppColors.accentText),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.headline.copyWith(
                    color: AppColors.accentText, fontWeight: FontWeight.w400)),
          ),
        ]),
      ),
    );
  }
}

/// Текстовая кнопка шапки («Готово», «Отмена»): акцентный цвет,
/// [strong] — жирнее (главное действие).
class AppBarTextButton extends StatelessWidget {
  const AppBarTextButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.strong = false,
      this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool strong;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
          width: 44,
          height: AppSizes.navBar,
          child: CupertinoActivityIndicator());
    }
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Pressable(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppSizes.navBar, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: Text(label,
                maxLines: 1,
                style: AppText.headline.copyWith(
                    color: AppColors.accentText,
                    fontWeight: strong ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
      ),
    );
  }
}

/// Шапка экрана с крупным заголовком, который при прокрутке сжимается
/// в маленький по центру (как в iOS). Фон — полупрозрачный с размытием,
/// тонкая линия снизу появляется, когда под шапкой прокручено содержимое.
///
/// Ставится первым sliver в [CustomScrollView]. [leading] — слева
/// (по умолчанию «назад», если есть куда), [actions] — справа,
/// [eyebrow] — маленькая акцентная подпись над крупным заголовком,
/// [bottom] — закреплённый ряд под заголовком (сегмент-контрол),
/// [large] == false — сразу компактная шапка (карточки).
class AppSliverHeader extends StatelessWidget {
  const AppSliverHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.eyebrow,
    this.bottom,
    this.bottomHeight = 0,
    this.large = true,
    this.showBack = true,
    this.backLabel,
    this.maxWidth = AppSpace.contentMax,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final String? eyebrow;
  final Widget? bottom;
  final double bottomHeight;
  final bool large;
  final bool showBack;
  final String? backLabel;

  /// Ширина колонки шапки на широком окне — как у содержимого (720),
  /// чтобы заголовок и кнопки стояли над списком. Экраны во всю ширину
  /// (отчёты) передают [double.infinity].
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    final lead = leading ?? (canPop ? AppBackButton(label: backLabel) : null);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(
        title: title,
        leading: lead,
        actions: actions,
        eyebrow: eyebrow,
        bottom: bottom,
        bottomHeight: bottom == null ? 0 : bottomHeight,
        large: large,
        topPadding: top,
        maxWidth: maxWidth,
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.title,
    required this.leading,
    required this.actions,
    required this.eyebrow,
    required this.bottom,
    required this.bottomHeight,
    required this.large,
    required this.topPadding,
    required this.maxWidth,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final String? eyebrow;
  final Widget? bottom;
  final double bottomHeight;
  final bool large;
  final double topPadding;
  final double maxWidth;

  double get _eyebrowHeight => eyebrow == null ? 0 : 18;
  double get _largeHeight => large ? AppSizes.largeTitle + _eyebrowHeight : 0;

  @override
  double get minExtent => topPadding + AppSizes.navBar + bottomHeight;

  @override
  double get maxExtent => minExtent + _largeHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final range = maxExtent - minExtent;
    final t = range == 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    // Маленький заголовок по центру появляется, когда крупный почти ушёл.
    final smallOpacity = large ? ((t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
    final lineOpacity = large ? smallOpacity : (overlaps ? 1.0 : 0.0);
    final largeVisible = _largeHeight * (1 - t);
    return FrostedBar(
      borderBottom: true,
      borderOpacity: math.max(lineOpacity, overlaps && t >= 1 ? 1 : 0),
      child: Padding(
        padding: EdgeInsetsDirectional.only(top: topPadding),
        child: ContentWidth(
          maxWidth: maxWidth,
          child: Column(children: [
            SizedBox(
              height: AppSizes.navBar,
              child: NavigationToolbar(
                leading: leading == null
                    ? null
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: leading),
                      ),
                middle: Opacity(
                  opacity: smallOpacity,
                  child: ExcludeSemantics(
                    excluding: large && smallOpacity == 0,
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headline),
                  ),
                ),
                trailing: actions.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(
                            end: AppSpace.screen),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpace.s),
                            actions[i],
                          ]
                        ]),
                      ),
                middleSpacing: AppSpace.s,
              ),
            ),
            if (large)
              SizedBox(
                height: largeVisible,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: AlignmentDirectional.bottomStart,
                    minHeight: _largeHeight,
                    maxHeight: _largeHeight,
                    child: Opacity(
                      opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpace.screen, 0, AppSpace.screen, 6),
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (eyebrow != null)
                                  Text(eyebrow!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.footnote.copyWith(
                                          color: AppColors.accentText,
                                          fontWeight: FontWeight.w600)),
                                Semantics(
                                  header: true,
                                  child: Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.largeTitle),
                                ),
                              ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (bottom != null) SizedBox(height: bottomHeight, child: bottom),
          ]),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.title != title ||
      old.leading != leading ||
      old.actions != actions ||
      old.eyebrow != eyebrow ||
      old.bottom != bottom ||
      old.bottomHeight != bottomHeight ||
      old.large != large ||
      old.topPadding != topPadding ||
      old.maxWidth != maxWidth;
}

/// Компактная шапка без прокрутки (над картой, на экранах без списка):
/// то же, что свёрнутая [AppSliverHeader].
class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.showBack = true,
    this.backLabel,
    this.border = true,
  });

  final String? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool showBack;
  final String? backLabel;
  final bool border;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.navBar);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    final lead = leading ?? (canPop ? AppBackButton(label: backLabel) : null);
    return FrostedBar(
      borderBottom: border,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSizes.navBar,
          child: NavigationToolbar(
            leading: lead == null
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: lead),
                  ),
            middle: title == null
                ? null
                : Text(title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headline),
            trailing: actions.isEmpty
                ? null
                : Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpace.screen),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpace.s),
                        actions[i],
                      ]
                    ]),
                  ),
            middleSpacing: AppSpace.s,
          ),
        ),
      ),
    );
  }
}

/// Колонка содержимого: на широком окне (≥ [AppSpace.wideFrom]) — по центру
/// шириной до [AppSpace.contentMax], поля по бокам [AppSpace.screen].
/// Для sliver-списков — [SliverContent].
class ContentWidth extends StatelessWidget {
  const ContentWidth(
      {super.key, required this.child, this.maxWidth = AppSpace.contentMax});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// Sliver с полями экрана и шириной до [AppSpace.contentMax] по центру.
class SliverContent extends StatelessWidget {
  const SliverContent({
    super.key,
    required this.sliver,
    this.top = AppSpace.s,
    this.bottom = 0,
    this.maxWidth = AppSpace.contentMax,
  });

  final Widget sliver;
  final double top;
  final double bottom;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
        builder: (context, c) {
          final w = c.crossAxisExtent;
          final side =
              math.max(AppSpace.screen, (w - maxWidth) / 2 + AppSpace.screen);
          return SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(side, top, side, bottom),
            sliver: sliver,
          );
        },
      );
}

/// Пустое место внизу списка: системный отступ (под нижним меню) и
/// [extra] (под голосовой кнопкой — [AppSizes.fabClearance]).
class SliverBottomInset extends StatelessWidget {
  const SliverBottomInset({super.key, this.extra = AppSpace.xl});
  final double extra;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: SizedBox(height: MediaQuery.paddingOf(context).bottom + extra),
      );
}

/// Каркас экрана: фон [AppColors.bg], шапка с крупным заголовком
/// ([AppSliverHeader]) и прокручиваемое содержимое [slivers] (уже с полями
/// и шириной — оберните в [SliverContent]), снизу — необязательная
/// [bottomBar] (обычно [BottomActionBar]).
///
/// [onRefresh] — «потянуть, чтобы обновить».
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.large = true,
    this.actions = const [],
    this.leading,
    this.backLabel,
    this.eyebrow,
    this.bottomBar,
    this.onRefresh,
    this.controller,
    this.floating,
  });

  final String title;
  final List<Widget> slivers;
  final bool large;
  final List<Widget> actions;
  final Widget? leading;
  final String? backLabel;
  final String? eyebrow;
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;

  /// Плавающая кнопка поверх содержимого (снизу справа).
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    final Widget scroll = CustomScrollView(
      controller: controller,
      // С «потянуть, чтобы обновить» — пружинящая прокрутка, как в iOS.
      physics: onRefresh != null
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      slivers: [
        AppSliverHeader(
          title: title,
          large: large,
          actions: actions,
          leading: leading,
          backLabel: backLabel,
          eyebrow: eyebrow,
        ),
        if (onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
        SliverBottomInset(
            extra: floating != null ? AppSizes.fabClearance : AppSpace.xl),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: bottomBar != null,
            child: floating == null
                ? scroll
                : Stack(children: [
                    Positioned.fill(child: scroll),
                    PositionedDirectional(
                      end: AppSpace.screen,
                      bottom: MediaQuery.paddingOf(context).bottom + AppSpace.l,
                      child: floating!,
                    ),
                  ]),
          ),
        ),
        if (bottomBar != null) bottomBar!,
      ]),
    );
  }
}

/// Маршрут экрана с переходом в стиле iOS. [title] — название экрана,
/// **с которого** переходим: это подпись кнопки «‹ назад» на новом экране.
Route<T> appRoute<T>(WidgetBuilder builder, {String? title}) =>
    AppPageRoute<T>(builder: builder, backLabel: title);

/// Маршрут iOS с подписью кнопки «назад» ([backLabel]).
class AppPageRoute<T> extends CupertinoPageRoute<T> {
  AppPageRoute(
      {required super.builder, this.backLabel, super.fullscreenDialog});

  /// Название предыдущего экрана — подпись «‹ назад».
  final String? backLabel;
}
