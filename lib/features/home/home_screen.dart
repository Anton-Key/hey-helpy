import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../models/profile.dart';
import '../auth/auth_repository.dart';
import '../directory/directory.dart';
import '../history/history_screen.dart';
import '../reports/reports_screen.dart';
import '../requests/requests.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _onBrand = Color(0xFF06342A);

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
  @override
  void initState() {
    super.initState();
    _auth.fetchMyProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    });
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        _Header(
            section: section,
            tab: _tab,
            onTab: (i) => setState(() => _tab = i)),
        Expanded(child: _body(section)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: sections.indexOf(section),
        onDestinationSelected: (i) => setState(() => _section = sections[i]),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l.navHome),
          NavigationDestination(
              icon: const Icon(Icons.history), label: l.navHistory),
          if (showReports)
            NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart),
                label: l.navReports),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
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
            return const ObjectsTab();
          default:
            return const RequestsTab();
        }
    }
  }

  Widget _profileView() {
    final l = context.l10n;
    final name = _profile?.displayName ?? l.profileDefaultName;
    final role = _profile == null ? '' : l.role(_profile!.role);
    final langName =
        LocaleController.nativeNames[context.localeCode] ?? context.localeCode;
    return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 120),
        children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDeco(),
              child: Row(children: [
                CircleAvatar(
                    radius: 28,
                    backgroundColor: HeyHelpyTheme.brand,
                    child: Text(
                        name.isNotEmpty
                            ? name.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: _onBrand,
                            fontWeight: FontWeight.w800,
                            fontSize: 20))),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(role,
                      style: const TextStyle(color: _muted, fontSize: 13)),
                ]),
              ])),
          const SizedBox(height: 16),
          _row(Icons.apartment_outlined, l.profileMyCompany),
          _row(Icons.notifications_none, l.profileNotifications),
          _row(Icons.language, '${l.profileLanguage} · $langName',
              onTap: _pickLanguage),
          _row(Icons.settings_outlined, l.profileSettings),
          _row(Icons.logout, l.profileSignOut,
              danger: true, onTap: () => _auth.signOut()),
        ]);
  }

  Future<void> _pickLanguage() async {
    final controller = LocaleScope.of(context);
    final chosen = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: _line, borderRadius: BorderRadius.circular(4))),
          Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 6),
              child: Text(ctx.l10n.profileLanguage,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800))),
          for (final loc in LocaleController.supported)
            ListTile(
              title: Text(LocaleController.nativeNames[loc.languageCode] ??
                  loc.languageCode),
              trailing: loc == controller.locale
                  ? Icon(Icons.check_rounded,
                      color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, loc),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (chosen == null || chosen == controller.locale) return;
    final synced = await controller.select(chosen);
    if (!synced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.profileLanguageNotSynced)));
    }
  }

  /// Строка профиля. Стрелка «дальше» — только у строк, которые что-то
  /// открывают; «Выйти» — действие, без стрелки; без [onTap] — просто текст
  /// (раздел ещё не готов) и без эффекта нажатия.
  Widget _row(IconData icon, String text,
      {bool danger = false, VoidCallback? onTap}) {
    final color =
        danger ? const Color(0xFFC24444) : (onTap == null ? _muted : _ink);
    return TapCard(
        onTap: onTap,
        chevron: !danger,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ),
        ]));
  }
}

BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _line));

class _Header extends StatelessWidget {
  const _Header(
      {required this.section, required this.tab, required this.onTab});
  final int section;
  final int tab;
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final titles = ['', l.navHistory, l.navReports, l.navProfile];
    // Название — из переводов. Часть после первого пробела выделяем жирнее:
    // «Эй, |Helpy», «Hey |Helpy».
    final name = l.appName;
    final cut = name.indexOf(' ');
    final lead = cut < 0 ? '' : name.substring(0, cut + 1);
    final main = cut < 0 ? name : name.substring(cut + 1);
    return Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: AlignmentDirectional.topEnd,
                end: AlignmentDirectional.bottomStart,
                colors: HeyHelpyTheme.headerGradient),
            border: Border(bottom: BorderSide(color: Color(0xFFE4F3F0)))),
        child: SafeArea(
            bottom: false,
            child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text.rich(TextSpan(
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800),
                                children: [
                                  if (lead.isNotEmpty)
                                    TextSpan(
                                        text: lead,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  TextSpan(text: main),
                                ])),
                            const Icon(Icons.notifications_none, color: _ink),
                          ]),
                      const SizedBox(height: 12),
                      if (section == 0)
                        _TopTabs(tab: tab, onTab: onTab)
                      else
                        Padding(
                            padding: const EdgeInsetsDirectional.only(
                                top: 2, bottom: 16),
                            child: Text(titles[section],
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800))),
                    ]))));
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [l.tabRequests, l.tabContractors, l.tabLocations];
    return Row(children: [
      for (int i = 0; i < labels.length; i++)
        // Material + InkWell: на градиенте шапки виден эффект нажатия.
        Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    onTap: () => onTab(i),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                            start: 6, end: 6, top: 4),
                        child: Container(
                            padding:
                                const EdgeInsetsDirectional.only(bottom: 12),
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: tab == i
                                            ? _ink
                                            : Colors.transparent,
                                        width: 3))),
                            child: Text(labels[i],
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: tab == i
                                        ? _ink
                                        : _ink.withValues(alpha: 0.5)))))))),
    ]);
  }
}
