import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/language_picker.dart';
import '../../core/l10n_ext.dart';
import '../../models/profile.dart';
import '../auth/auth_repository.dart';
import '../directory/directory.dart';
import '../history/history_screen.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notifications_screen.dart';
import '../profile/company_screen.dart';
import '../profile/settings_screen.dart';
import '../reports/reports_screen.dart';
import '../requests/requests.dart';
import 'home_chrome.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthRepository();
  int _section = 0;
  int _tab = 0;
  Profile? _profile;

  /// Фильтр «Заявки» по объекту — из карточки объекта на карте.
  Obj? _ordersObject;
  final _notifications = NotificationRepository();

  /// Новых уведомлений с прошлого открытия — число у колокольчика.
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await _auth.fetchMyProfile();
    if (!mounted) return;
    setState(() => _profile = p);
    await _loadUnread();
  }

  Future<void> _loadUnread() async {
    final me = _profile;
    if (me == null) return;
    try {
      final list = await _notifications.load(me);
      final seen = await _notifications.seenAt(me.id);
      if (mounted) {
        setState(() => _unread = NotificationRepository.unread(list, seen));
      }
    } catch (e) {
      debugPrint('Unread: $e');
    }
  }

  Future<void> _openNotifications() async {
    final me = _profile;
    if (me == null) return;
    setState(() => _unread = 0);
    await Navigator.push(
        context,
        appRoute((_) => NotificationsScreen(me: me),
            title: context.l10n.navHome));
    await _loadUnread();
  }

  Future<void> _openCompany() async {
    final me = _profile;
    if (me == null) return;
    final tab = await Navigator.push<int>(
        context,
        appRoute((_) => MyCompanyScreen(me: me),
            title: context.l10n.navProfile));
    if (tab != null && mounted) {
      setState(() {
        _section = 0;
        _tab = tab;
      });
    }
  }

  Future<void> _openSettings() async {
    final me = _profile;
    if (me == null) return;
    final changed = await Navigator.push<bool>(
        context,
        appRoute((_) => SettingsScreen(me: me),
            title: context.l10n.navProfile));
    if (changed == true) await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Разделы: 0 — главная, 1 — история, 2 — отчёты, 3 — профиль.
    // «Отчёты» — только менеджеру и администратору (данные всё равно
    // ограничивает RLS в базе).
    final showReports = _profile?.role.canSeeReports == true;
    final sections = [0, 1, if (showReports) 2, 3];
    final section = sections.contains(_section) ? _section : 0;
    // Содержимое прокручивается под полупрозрачным нижним меню (extendBody):
    // списки сами оставляют снизу место (SliverBottomInset).
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: HomeChrome(
        unread: _unread,
        onBell: _profile == null ? null : _openNotifications,
        tab: _tab,
        onTab: (i) => setState(() => _tab = i),
        showTabs: section == 0,
        child: _body(section),
      ),
      bottomNavigationBar: AppTabBar(
        index: sections.indexOf(section),
        onChanged: (i) {
          setState(() => _section = sections[i]);
          _loadUnread();
        },
        tabs: [
          AppTab(
              icon: AppIcons.home,
              activeIcon: AppIcons.homeActive,
              label: l.navHome),
          AppTab(
              icon: AppIcons.history,
              activeIcon: AppIcons.historyActive,
              label: l.navHistory),
          if (showReports)
            AppTab(
                icon: AppIcons.reports,
                activeIcon: AppIcons.reportsActive,
                label: l.navReports),
          AppTab(
              icon: AppIcons.profile,
              activeIcon: AppIcons.profileActive,
              label: l.navProfile),
        ],
      ),
    );
  }

  Widget _body(int section) {
    switch (section) {
      case 1:
        return const HistoryScreen();
      case 2:
        return const ReportsScreen();
      case 3:
        return _profileView();
      default:
        switch (_tab) {
          case 1:
            return const ContractorsTab();
          case 2:
            return ObjectsTab(
                onShowOrders: (o) => setState(() {
                      _ordersObject = o;
                      _tab = 0;
                    }));
          default:
            return RequestsTab(
                objectFilter: _ordersObject,
                onClearObjectFilter: () =>
                    setState(() => _ordersObject = null));
        }
    }
  }

  Widget _profileView() {
    final l = context.l10n;
    final name = _profile?.displayName ?? l.profileDefaultName;
    final role = _profile == null ? '' : l.role(_profile!.role);
    return CustomScrollView(slivers: [
      HomeHeader(title: l.navProfile),
      SliverContent(
        sliver: SliverList.list(children: [
          AppGroup(children: [
            AppRow(
              leading: InitialsTile(name, size: 52),
              title: name,
              titleStyle: AppText.headline,
              subtitle: role,
            ),
          ]),
          AppGroup(children: [
            AppRow(
                leading: const LeadingIcon(AppIcons.building),
                title: l.profileMyCompany,
                onTap: _openCompany),
            AppRow(
                leading: const LeadingIcon(AppIcons.bell),
                title: l.profileNotifications,
                trailing: _unread > 0 ? CountBadge(_unread) : null,
                onTap: _openNotifications),
            AppRow(
                leading: const LeadingIcon(AppIcons.language),
                title: l.profileLanguage,
                value: currentLanguageName(context),
                onTap: () => pickLanguage(context)),
            AppRow(
                leading: const LeadingIcon(AppIcons.settings),
                title: l.profileSettings,
                onTap: _openSettings),
          ]),
          // «Выйти» — действие, без стрелки.
          AppGroup(children: [
            AppRow(
                leading: const LeadingIcon.danger(AppIcons.signOut),
                title: l.profileSignOut,
                destructive: true,
                chevron: false,
                onTap: () => _auth.signOut()),
          ]),
        ]),
      ),
      const SliverBottomInset(),
    ]);
  }
}
