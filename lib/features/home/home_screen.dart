import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_message.dart';
import '../../core/content_navigator.dart';
import '../../core/design/design.dart';
import '../../core/language_picker.dart';
import '../../core/l10n_ext.dart';
import '../../core/locale_controller.dart';
import '../../models/profile.dart';
import '../auth/auth_repository.dart';
import '../directory/directory.dart';
import '../history/history_screen.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notifications_screen.dart';
import '../ppr/ppr_repository.dart';
import '../ppr/ppr_tab.dart';
import '../profile/company_screen.dart';
import '../profile/profile_repository.dart';
import '../profile/settings_screen.dart';
import '../reports/reports_screen.dart';
import '../requests/requests.dart';
import 'home_actions.dart';
import 'home_chrome.dart';
import 'hotkeys.dart';

/// Где запоминается выбор «Свернуть / Развернуть меню» (ПК).
const _kRailPref = 'nav_rail_collapsed';

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

  /// Название компании — таблетка «Компания · роль» на ПК.
  String? _companyName;

  /// ПК: выбор «Свернуть меню» (null — по ширине окна).
  bool? _railPref;

  final _actions = HomeActions();

  /// ПК: навигатор области справа от бокового меню.
  final _contentNav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _actions.addListener(_onActions);
    _loadProfile();
    _loadRailPref();
  }

  @override
  void dispose() {
    _actions.removeListener(_onActions);
    _actions.dispose();
    super.dispose();
  }

  void _onActions() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRailPref() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool(_kRailPref);
      if (mounted && v != null) setState(() => _railPref = v);
    } catch (e) {
      debugPrint('Rail pref: $e');
    }
  }

  Future<void> _toggleRail(AppNavLayout now) async {
    final collapsed = now != AppNavLayout.rail;
    setState(() => _railPref = collapsed);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kRailPref, collapsed);
    } catch (e) {
      debugPrint('Rail pref: $e');
    }
  }

  Future<void> _loadProfile() async {
    final p = await _auth.fetchMyProfile();
    if (!mounted) return;
    setState(() => _profile = p);
    // ППР: задачи текущего периода создаются при входе менеджера (не чаще
    // раза в 10 минут; без миграции 0015 — молча ничего).
    if (p?.role.canSeeReports == true) {
      PprRepository().generate().ignore();
    }
    final cid = p?.companyId;
    if (cid != null) {
      try {
        final name = await ProfileRepository().companyName(cid);
        if (mounted) setState(() => _companyName = name);
      } catch (e) {
        debugPrint('Company name: $e');
      }
    }
    await _loadUnread();
  }

  /// Открыть экран поверх: на ПК — справа от бокового меню.
  Future<T?> _push<T>(Route<T> route) {
    final nav = _contentNav.currentState;
    if (nav != null) return nav.push(route);
    return Navigator.push(context, route);
  }

  /// Раздел меню: на ПК закрываем экраны, открытые поверх.
  void _goSection(int s) {
    _contentNav.currentState?.popUntil((r) => r.isFirst);
    setState(() => _section = s);
    _loadUnread();
  }

  /// Кнопки «Эй, Helpy» / «+ Заявка» и горячие клавиши: открыть вкладку
  /// «Заявки», дальше её дело ([HomeActions]).
  void _requestAction(HomeAction a) {
    _contentNav.currentState?.popUntil((r) => r.isFirst);
    setState(() {
      _section = 0;
      _tab = 0;
    });
    _actions.request(a);
  }

  void _onHotkey(HomeHotkey k) {
    switch (k) {
      case HomeHotkey.newOrder:
        _requestAction(HomeAction.create);
      case HomeHotkey.voice:
        _requestAction(HomeAction.voice);
      case HomeHotkey.search:
        _requestAction(HomeAction.search);
      case HomeHotkey.help:
        _showHelp();
    }
  }

  Future<void> _showHelp() {
    final l = context.l10n;
    Widget key(String k, String label) => AppRow(
          title: label,
          chevron: false,
          trailing: Container(
            constraints: const BoxConstraints(minWidth: 28),
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpace.s, vertical: AppSpace.xxs),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(k,
                style: AppText.callout.copyWith(fontWeight: FontWeight.w700)),
          ),
        );
    return showAppSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
              title: l.helpTitle,
              doneLabel: l.commonGotIt,
              onDone: () => Navigator.pop(ctx)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppGroup(children: [
                      for (final t in [l.helpTip1, l.helpTip2, l.helpTip3])
                        AppRow(
                            title: t,
                            titleStyle: AppText.callout,
                            chevron: false),
                    ]),
                    AppGroup(
                        header: l.helpHotkeys,
                        footer: l.hotkeyNote,
                        children: [
                          key('N', l.hotkeyNew),
                          key('V', l.hotkeyVoice),
                          key('/', l.hotkeySearch),
                          key('?', l.hotkeyHelp),
                        ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _setLanguage(String code) async {
    final synced = await LocaleScope.of(context).select(Locale(code));
    if (!synced && mounted) {
      showAppMessage(context, context.l10n.profileLanguageNotSynced,
          type: AppMessageType.error);
    }
  }

  Future<void> _accountMenu(BuildContext anchor) async {
    final l = context.l10n;
    final a = await showFilterPicker<int>(
      context: anchor,
      builder: (ctx) => AppGroup(margin: EdgeInsets.zero, children: [
        AppRow(
            leading: const LeadingIcon(AppIcons.profile),
            title: l.navProfile,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 0)),
        AppRow(
            leading: const LeadingIcon(AppIcons.building),
            title: l.profileMyCompany,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 1)),
        AppRow(
            leading: const LeadingIcon(AppIcons.settings),
            title: l.profileSettings,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 2)),
        AppRow(
            leading: const LeadingIcon.danger(AppIcons.signOut),
            title: l.profileSignOut,
            destructive: true,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 3)),
      ]),
    );
    switch (a) {
      case 0:
        _goSection(3);
      case 1:
        await _openCompany();
      case 2:
        await _openSettings();
      case 3:
        await _auth.signOut();
    }
  }

  /// Служебные кнопки ПК после «Обновить»: язык, уведомления, справка,
  /// аватар.
  List<Widget> _utilityTail() {
    final l = context.l10n;
    final name = _profile?.displayName ?? l.profileDefaultName;
    return [
      AppLangSwitch(
          codes: [for (final x in LocaleController.supported) x.languageCode],
          selected: context.localeCode,
          semanticLabel: l.navLanguage(currentLanguageName(context)),
          onChanged: _setLanguage),
      AppIconButton(
          icon: AppIcons.bell,
          label: l.notifBellTooltip(_unread),
          badge: _unread,
          size: 40,
          tooltip: true,
          onPressed: _profile == null ? null : _openNotifications),
      AppIconButton(
          icon: AppIcons.help,
          label: l.navHelp,
          size: 40,
          tooltip: true,
          onPressed: _showHelp),
      Builder(
        builder: (anchor) => Tooltip(
          message: l.navAccount,
          excludeFromSemantics: true,
          child: Pressable(
            semanticLabel: l.navAccount,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => _accountMenu(anchor),
            child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: InitialsTile(name, size: 36))),
          ),
        ),
      ),
    ];
  }

  Widget? _utilityLead() {
    final p = _profile;
    if (p == null) return null;
    final l = context.l10n;
    final role = l.role(p.role);
    final company = _companyName;
    return AppContextPill(
        company == null ? role : l.navCompanyRole(company, role));
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
    await _push(appRoute((_) => NotificationsScreen(me: me),
        title: context.l10n.navHome));
    await _loadUnread();
  }

  Future<void> _openCompany() async {
    final me = _profile;
    if (me == null) return;
    final tab = await _push<int>(appRoute((_) => MyCompanyScreen(me: me),
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
    final changed = await _push<bool>(appRoute((_) => SettingsScreen(me: me),
        title: context.l10n.navProfile));
    if (changed == true) await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Разделы: 0 — главная, 1 — история, 2 — отчёты, 3 — профиль,
    // 4 — ППР (только на ПК; на телефоне ППР — вкладка «Главной»).
    // «Отчёты» — только менеджеру и администратору (данные всё равно
    // ограничивает RLS в базе).
    final showReports = _profile?.role.canSeeReports == true;
    final layout =
        appNavLayoutFor(MediaQuery.sizeOf(context).width, collapsed: _railPref);
    final desktop = layout != AppNavLayout.bottom;
    final sections = desktop
        ? [0, 4, 1, if (showReports) 2, 3]
        : [0, 1, if (showReports) 2, 3];
    var section = _section;
    // Окно сузили на вкладке «ППР» ПК → вкладка «ППР» телефона, и наоборот.
    if (!desktop && section == 4) {
      section = 0;
      _tab = 3;
    } else if (desktop && section == 0 && _tab == 3) {
      section = 4;
      _tab = 0;
    }
    if (!sections.contains(section)) section = 0;
    final body = _body(section);
    Widget chrome(Widget child) => HomeChrome(
          unread: _unread,
          onBell: _profile == null ? null : _openNotifications,
          tab: _tab,
          onTab: (i) => setState(() => _tab = i),
          showTabs: section == 0,
          layout: layout,
          actions: _actions,
          utilityLead: desktop ? _utilityLead() : null,
          utilityTail: desktop ? _utilityTail() : const [],
          child: child,
        );
    final Widget scaffold;
    if (!desktop) {
      // Телефон: содержимое прокручивается под полупрозрачным нижним меню
      // (extendBody): списки сами оставляют снизу место (SliverBottomInset).
      scaffold = Scaffold(
        backgroundColor: AppColors.bg,
        extendBody: true,
        body: chrome(body),
        bottomNavigationBar: AppTabBar(
          index: sections.indexOf(section),
          onChanged: (i) => _goSection(sections[i]),
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
    } else {
      // ПК: меню слева, справа — раздел; экраны поверх открываются в этой
      // же области (ContentNavigator), меню остаётся видно.
      final rail = layout == AppNavLayout.rail;
      scaffold = Scaffold(
        backgroundColor: AppColors.bg,
        body: chrome(Row(children: [
          AppSideNav(
            brand: l.appName,
            rail: rail,
            index: sections.indexOf(section),
            onChanged: (i) => _goSection(sections[i]),
            items: [
              AppNavItem(
                  icon: AppIcons.home,
                  activeIcon: AppIcons.homeActive,
                  label: l.navHome,
                  badge: _actions.overdue),
              AppNavItem(
                  icon: AppIcons.calendar,
                  activeIcon: AppIcons.calendar,
                  label: l.tabPpr),
              AppNavItem(
                  icon: AppIcons.history,
                  activeIcon: AppIcons.historyActive,
                  label: l.navHistory),
              if (showReports)
                AppNavItem(
                    icon: AppIcons.reports,
                    activeIcon: AppIcons.reportsActive,
                    label: l.navReports),
              AppNavItem(
                  icon: AppIcons.profile,
                  activeIcon: AppIcons.profileActive,
                  label: l.navProfile,
                  badge: _unread),
            ],
            voiceLabel: l.appName,
            voiceSemantic: l.requestsVoice,
            onVoice: () => _requestAction(HomeAction.voice),
            addLabel: l.navAddOrder,
            onAdd: () => _requestAction(HomeAction.create),
            toggleLabel: rail ? l.navExpand : l.navCollapse,
            onToggle: () => _toggleRail(layout),
          ),
          Expanded(
            child: ContentNavigatorView(navKey: _contentNav, home: body),
          ),
        ])),
      );
    }
    return HomeHotkeys(
      enabled: () => ModalRoute.of(context)?.isCurrent ?? true,
      onHotkey: _onHotkey,
      child: scaffold,
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
      case 4:
        return const PprTab();
      default:
        switch (_tab) {
          case 1:
            return const ContractorsTab();
          case 3:
            return const PprTab();
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
      HomeHeader(title: l.navProfile, onRefresh: _loadProfile),
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
