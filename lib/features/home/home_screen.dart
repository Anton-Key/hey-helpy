import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/directional.dart';
import '../../core/l10n_ext.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../auth/auth_repository.dart';
import '../directory/directory.dart';
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
    _auth.fetchMyProfile().then((p) { if (mounted) setState(() => _profile = p); });
  }
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        _Header(section: _section, tab: _tab, onTab: (i) => setState(() => _tab = i)),
        Expanded(child: _body()),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (i) => setState(() => _section = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l.navHome),
          NavigationDestination(icon: const Icon(Icons.history), label: l.navHistory),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: l.navReports),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.navProfile),
        ],
      ),
    );
  }
  Widget _body() {
    switch (_section) {
      case 1: return _history();
      case 2: return _reports();
      case 3: return _profileView();
      default:
        switch (_tab) {
          case 1: return const ContractorsTab();
          case 2: return const ObjectsTab();
          default: return const RequestsTab();
        }
    }
  }
  // Временно: выдуманные данные, пока «История» не переведена на реальные.
  Widget _history() {
    final l = context.l10n;
    return ListView(padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 120), children: [
      Text(l.mockHistoryDoneThisMonth(12), style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 10),
      _DoneCard(title: l.mockHistory1Title, place: l.mockHistory1Place, meta: l.mockHistory1Meta, who: 'IP'),
      _DoneCard(title: l.mockHistory2Title, place: l.mockHistory2Place, meta: l.mockHistory2Meta, who: 'SK'),
      _DoneCard(title: l.mockHistory3Title, place: l.mockHistory3Place, meta: l.mockHistory3Meta, who: 'KL'),
    ]);
  }
  // Временно: выдуманные цифры, пока «Отчёты» не переведены на реальные.
  // Числа уже форматируются по правилам выбранного языка.
  Widget _reports() {
    final brand = Theme.of(context).colorScheme.primary;
    final l = context.l10n;
    final num = NumberFormat.decimalPattern(l.localeName);
    final pct = NumberFormat.percentPattern(l.localeName);
    return ListView(padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 120), children: [
      Row(children: [
        Expanded(child: _Kpi(n: num.format(27), t: l.reportsKpiRequests)),
        const SizedBox(width: 10), Expanded(child: _Kpi(n: pct.format(0.92), t: l.reportsKpiOnTime)),
        const SizedBox(width: 10), Expanded(child: _Kpi(n: l.hoursShort(num.format(1.4)), t: l.reportsKpiAvgTime)),
      ]),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16), decoration: _cardDeco(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.reportsWeeklyChart, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(height: 120, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _bar(0.45, brand), _bar(0.7, brand), _bar(0.55, brand), _bar(0.9, brand)])),
        ])),
      const SizedBox(height: 14),
      FilledButton(onPressed: () {},
        style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand),
        child: Text(l.reportsExportPdf, style: const TextStyle(fontWeight: FontWeight.w800))),
      const SizedBox(height: 12),
      Center(child: Text(l.reportsWebHint, style: const TextStyle(color: _muted, fontSize: 12))),
    ]);
  }
  Widget _bar(double h, Color brand) => Expanded(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
          child: FractionallySizedBox(heightFactor: h, alignment: Alignment.bottomCenter,
              child: Container(decoration: BoxDecoration(color: brand,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))))));
  Widget _profileView() {
    final brand = Theme.of(context).colorScheme.primary;
    final l = context.l10n;
    final name = _profile?.displayName ?? l.profileDefaultName;
    final role = _profile == null ? '' : l.role(_profile!.role);
    final langName = LocaleController.nativeNames[context.localeCode] ?? context.localeCode;
    return ListView(padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 120), children: [
      Container(padding: const EdgeInsets.all(16), decoration: _cardDeco(),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: brand,
            child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                style: const TextStyle(color: _onBrand, fontWeight: FontWeight.w800, fontSize: 20))),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(role, style: const TextStyle(color: _muted, fontSize: 13)),
          ]),
        ])),
      const SizedBox(height: 16),
      _row(Icons.apartment_outlined, l.profileMyCompany),
      _row(Icons.notifications_none, l.profileNotifications),
      _row(Icons.language, '${l.profileLanguage} · $langName', onTap: _pickLanguage),
      _row(Icons.settings_outlined, l.profileSettings),
      _row(Icons.logout, l.profileSignOut, danger: true, onTap: () => _auth.signOut()),
    ]);
  }

  Future<void> _pickLanguage() async {
    final controller = LocaleScope.of(context);
    final chosen = await showModalBottomSheet<Locale>(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(4))),
          Padding(padding: const EdgeInsetsDirectional.only(bottom: 6),
              child: Text(ctx.l10n.profileLanguage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final loc in LocaleController.supported)
            ListTile(
              title: Text(LocaleController.nativeNames[loc.languageCode] ?? loc.languageCode),
              trailing: loc == controller.locale
                  ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.profileLanguageNotSynced)));
    }
  }
  Widget _row(IconData icon, String text, {bool danger = false, VoidCallback? onTap}) {
    final color = danger ? const Color(0xFFC24444) : _ink;
    return Padding(padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14), decoration: _cardDeco(),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            if (!danger) const Spacer(),
            if (!danger) const ChevronEnd(color: _muted),
          ]))));
  }
}

BoxDecoration _cardDeco() =>
    BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line));

class _Header extends StatelessWidget {
  const _Header({required this.section, required this.tab, required this.onTab});
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
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: HeyHelpyTheme.headerGradient),
        border: Border(bottom: BorderSide(color: Color(0xFFE4F3F0)))),
      child: SafeArea(bottom: false,
        child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text.rich(TextSpan(
                style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800),
                children: [
                  if (lead.isNotEmpty) TextSpan(text: lead, style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: main),
                ])),
              const Icon(Icons.notifications_none, color: _ink),
            ]),
            const SizedBox(height: 12),
            if (section == 0) _TopTabs(tab: tab, onTab: onTab)
            else Padding(padding: const EdgeInsetsDirectional.only(top: 2, bottom: 16),
              child: Text(titles[section], style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w800))),
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
        GestureDetector(onTap: () => onTab(i),
          child: Padding(padding: const EdgeInsetsDirectional.only(end: 22),
            child: Container(padding: const EdgeInsetsDirectional.only(bottom: 12),
              decoration: BoxDecoration(border: Border(
                  bottom: BorderSide(color: tab == i ? _ink : Colors.transparent, width: 3))),
              child: Text(labels[i], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: tab == i ? _ink : _ink.withValues(alpha: 0.5)))))),
    ]);
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.title, required this.place, required this.meta, required this.who});
  final String title, place, meta, who;
  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Container(margin: const EdgeInsetsDirectional.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: _cardDeco(),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(place, style: const TextStyle(color: _muted, fontSize: 13)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEAECEF), borderRadius: BorderRadius.circular(20)),
            child: Text(context.l10n.historyDone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7480)))),
        ]),
        const SizedBox(height: 11),
        const Divider(height: 1, color: _line),
        const SizedBox(height: 9),
        Row(children: [
          Text(meta, style: const TextStyle(color: _muted, fontSize: 12)),
          const Spacer(),
          CircleAvatar(radius: 11, backgroundColor: brand,
            child: Text(who, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _onBrand))),
        ]),
      ]));
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.n, required this.t});
  final String n, t;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(14), decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(t, style: const TextStyle(color: _muted, fontSize: 12)),
      ]));
  }
}