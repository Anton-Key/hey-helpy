import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';

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
  });

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
      old.showTabs != showTabs;
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

/// Шапка вкладки главного экрана — первый sliver её списка: крупный
/// заголовок [title] (сжимается при прокрутке), над ним маленькая
/// акцентная подпись [eyebrow], справа [actions] и колокольчик, снизу —
/// переключатель вкладок (в разделе «Главная»).
class HomeHeader extends StatelessWidget {
  const HomeHeader(
      {super.key, required this.title, this.eyebrow, this.actions = const []});
  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final chrome = HomeChrome.maybeOf(context);
    final tabs = chrome != null && chrome.showTabs;
    return AppSliverHeader(
      title: title,
      eyebrow: eyebrow,
      showBack: false,
      actions: [...actions, _Bell(chrome)],
      bottom: tabs ? _MainTabs(chrome) : null,
      bottomHeight: tabs ? _tabsHeight : 0,
    );
  }
}

/// То же, что свёрнутая [HomeHeader], — для вкладок без прокрутки (карта):
/// заголовок по центру, колокольчик, переключатель вкладок.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final chrome = HomeChrome.maybeOf(context);
    final tabs = chrome != null && chrome.showTabs;
    return FrostedBar(
      borderBottom: true,
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: AppSizes.navBar,
            child: NavigationToolbar(
              middle: Text(title, style: AppText.headline),
              trailing: Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.screen),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final a in actions) ...[
                    a,
                    const SizedBox(width: AppSpace.s),
                  ],
                  _Bell(chrome),
                ]),
              ),
            ),
          ),
          if (tabs) SizedBox(height: _tabsHeight, child: _MainTabs(chrome)),
        ]),
      ),
    );
  }
}
