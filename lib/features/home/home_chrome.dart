import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import 'home_actions.dart';

/// Общая шапка вкладок главного экрана: колокольчик с числом новых
/// уведомлений и (в разделе «Главная») переключатель
/// «Заявки | Подрядчики | Локации». Её даёт [HomeScreen], а вкладки
/// ставят [HomeHeader] первым sliver своего списка.
class HomeChrome extends InheritedWidget {
  const HomeChrome({
    super.key,
    required super.child,
    required this.unread,
    required this.onBell,
    required this.tab,
    required this.onTab,
    required this.showTabs,
    required this.layout,
    required this.actions,
    this.utilityLead,
    this.utilityTail = const [],
  });

  /// Раскладка меню: на ПК ([AppNavLayout.rail], [AppNavLayout.sidebar])
  /// шапка — крупный заголовок в одной строке со служебными кнопками.
  final AppNavLayout layout;

  /// Связь с вкладкой «Заявки» (кнопки бокового меню, горячие клавиши).
  final HomeActions actions;

  /// ПК: таблетка «Компания · роль» (перед «Обновить»).
  final Widget? utilityLead;

  /// ПК: язык, уведомления, справка, аватар (после «Обновить»).
  final List<Widget> utilityTail;

  bool get desktop => layout != AppNavLayout.bottom;

  final int unread;
  final VoidCallback? onBell;

  /// Вкладка раздела «Главная»: 0 — заявки, 1 — подрядчики, 2 — локации.
  final int tab;
  final ValueChanged<int> onTab;

  /// true — в разделе «Главная» (показывать переключатель вкладок).
  final bool showTabs;

  static HomeChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeChrome>();

  @override
  bool updateShouldNotify(HomeChrome old) =>
      old.unread != unread ||
      old.onBell != onBell ||
      old.tab != tab ||
      old.showTabs != showTabs ||
      old.layout != layout ||
      old.utilityLead != utilityLead ||
      old.utilityTail != utilityTail;
}

/// Высота ряда с переключателем вкладок под заголовком.
const _tabsHeight = AppSizes.segmentHeight + 10;

/// Колокольчик в белом круге с числом новых уведомлений.
class _Bell extends StatelessWidget {
  const _Bell(this.chrome);
  final HomeChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final unread = chrome?.unread ?? 0;
    return AppIconButton(
      icon: AppIcons.bell,
      label: context.l10n.notifBellTooltip(unread),
      badge: unread,
      onPressed: chrome?.onBell,
    );
  }
}

class _MainTabs extends StatelessWidget {
  const _MainTabs(this.chrome);
  final HomeChrome chrome;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpace.screen, 0, AppSpace.screen, 10),
      child: ContentWidth(
        child: SegmentedControl<int>(
          segments: [
            Segment(0, l.tabRequests),
            Segment(1, l.tabContractors),
            Segment(2, l.tabLocations),
          ],
          selected: chrome.tab,
          onChanged: chrome.onTab,
        ),
      ),
    );
  }
}

/// Кнопки справа в шапке вкладки. Телефон: действия вкладки, «Обновить»,
/// колокольчик. ПК: действия вкладки, «Компания · роль», «Обновить», язык,
/// уведомления, справка, аватар.
List<Widget> _headerActions(BuildContext context, HomeChrome? chrome,
    List<Widget> actions, VoidCallback? onRefresh) {
  final l = context.l10n;
  final desktop = chrome?.desktop ?? false;
  final refresh = onRefresh == null
      ? null
      : AppIconButton(
          icon: AppIcons.refresh,
          label: l.commonRefresh,
          tooltip: desktop,
          size: desktop ? 40 : 36,
          onPressed: onRefresh);
  if (!desktop) {
    return [...actions, if (refresh != null) refresh, _Bell(chrome)];
  }
  return [
    ...actions,
    if (chrome?.utilityLead != null) chrome!.utilityLead!,
    if (refresh != null) refresh,
    ...?chrome?.utilityTail,
  ];
}

/// Шапка вкладки главного экрана — первый sliver её списка. Одинаковая на
/// всех вкладках. Телефон: строка «Эй, Helpy» + «Обновить» + колокольчик,
/// под ней крупный заголовок [title] (сжимается при прокрутке), снизу —
/// переключатель вкладок (в разделе «Главная»). ПК: крупный заголовок в
/// одной строке со служебными кнопками.
class HomeHeader extends StatelessWidget {
  const HomeHeader(
      {super.key,
      required this.title,
      this.actions = const [],
      this.onRefresh,
      this.maxWidth = AppSpace.contentMax});
  final String title;
  final List<Widget> actions;

  /// «Обновить» (null — без кнопки).
  final VoidCallback? onRefresh;

  /// Как у содержимого вкладки: 720 у списков, во всю ширину — у отчётов.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final chrome = HomeChrome.maybeOf(context);
    final tabs = chrome != null && chrome.showTabs;
    final desktop = chrome?.desktop ?? false;
    return AppSliverHeader(
      title: title,
      eyebrow: desktop ? null : context.l10n.appName,
      showBack: false,
      inline: desktop,
      actions: _headerActions(context, chrome, actions, onRefresh),
      bottom: tabs ? _MainTabs(chrome) : null,
      bottomHeight: tabs ? _tabsHeight : 0,
      // ПК: служебные кнопки — у правого края окна, не над колонкой списка.
      maxWidth: desktop ? double.infinity : maxWidth,
    );
  }
}

/// То же, что свёрнутая [HomeHeader], — для вкладок без прокрутки (карта):
/// заголовок, кнопки, переключатель вкладок.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar(
      {super.key,
      required this.title,
      this.actions = const [],
      this.onRefresh});
  final String title;
  final List<Widget> actions;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final chrome = HomeChrome.maybeOf(context);
    final tabs = chrome != null && chrome.showTabs;
    final desktop = chrome?.desktop ?? false;
    final buttons = _headerActions(context, chrome, actions, onRefresh);
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < buttons.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpace.s),
        buttons[i],
      ],
    ]);
    return FrostedBar(
      borderBottom: true,
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: desktop ? 64 : AppSizes.navBar,
            child: desktop
                ? Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpace.screen),
                    child: Row(children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.largeTitle),
                        ),
                      ),
                      row,
                    ]),
                  )
                : NavigationToolbar(
                    middle: Text(title, style: AppText.headline),
                    trailing: Padding(
                      padding: const EdgeInsetsDirectional.only(
                          end: AppSpace.screen),
                      child: row,
                    ),
                  ),
          ),
          if (tabs) SizedBox(height: _tabsHeight, child: _MainTabs(chrome)),
        ]),
      ),
    );
  }
}
