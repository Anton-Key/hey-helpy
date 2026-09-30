import 'package:flutter/material.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        _Header(section: _section, tab: _tab, onTab: (i) => setState(() => _tab = i)),
        Expanded(child: _body()),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (i) => setState(() => _section = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.history), label: 'История'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Отчёты'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
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
  Widget _history() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 120), children: const [
      Text('Выполнено за месяц: 12', style: TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 13)),
      SizedBox(height: 10),
      _DoneCard(title: 'Ремонт стула', place: 'Астана · Кабинет 512', meta: '12 авг · 40 мин', who: 'ИП'),
      _DoneCard(title: 'Замена фильтров', place: 'Москва · Серверная', meta: '11 авг · 1 ч 20 мин', who: 'СК'),
      _DoneCard(title: 'Уборка холла', place: 'Москва · 1 этаж', meta: '11 авг · 55 мин', who: 'КЛ'),
    ]);
  }
  Widget _reports() {
    final brand = Theme.of(context).colorScheme.primary;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
      Row(children: const [
        Expanded(child: _Kpi(n: '27', t: 'заявок за месяц')),
        SizedBox(width: 10), Expanded(child: _Kpi(n: '92%', t: 'в срок')),
        SizedBox(width: 10), Expanded(child: _Kpi(n: '1.4ч', t: 'ср. время')),
      ]),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16), decoration: _cardDeco(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Заявки по неделям', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(height: 120, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _bar(0.45, brand), _bar(0.7, brand), _bar(0.55, brand), _bar(0.9, brand)])),
        ])),
      const SizedBox(height: 14),
      FilledButton(onPressed: () {},
        style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: _onBrand),
        child: const Text('Экспорт в PDF', style: TextStyle(fontWeight: FontWeight.w800))),
      const SizedBox(height: 12),
      const Center(child: Text('Полные отчёты и фильтры — в web-версии', style: TextStyle(color: _muted, fontSize: 12))),
    ]);
  }
  Widget _bar(double h, Color brand) => Expanded(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
          child: FractionallySizedBox(heightFactor: h, alignment: Alignment.bottomCenter,
              child: Container(decoration: BoxDecoration(color: brand,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))))));
  Widget _profileView() {
    final brand = Theme.of(context).colorScheme.primary;
    final name = _profile?.displayName ?? 'Антон';
    final role = _profile?.role.title ?? 'Администратор';
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
      Container(padding: const EdgeInsets.all(16), decoration: _cardDeco(),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: brand,
            child: Text(name.isNotEmpty ? name[0] : 'A',
                style: const TextStyle(color: _onBrand, fontWeight: FontWeight.w800, fontSize: 20))),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(role, style: const TextStyle(color: _muted, fontSize: 13)),
          ]),
        ])),
      const SizedBox(height: 16),
      _row(Icons.apartment_outlined, 'Моя компания'),
      _row(Icons.notifications_none, 'Уведомления'),
      _row(Icons.language, 'Язык · Русский'),
      _row(Icons.settings_outlined, 'Настройки'),
      _row(Icons.logout, 'Выйти', danger: true, onTap: () => _auth.signOut()),
    ]);
  }
  Widget _row(IconData icon, String text, {bool danger = false, VoidCallback? onTap}) {
    final color = danger ? const Color(0xFFC24444) : _ink;
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14), decoration: _cardDeco(),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            if (!danger) const Spacer(),
            if (!danger) const Icon(Icons.chevron_right, color: _muted),
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
  static const _titles = ['', 'История', 'Отчёты', 'Профиль'];
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: HeyHelpyTheme.headerGradient),
        border: Border(bottom: BorderSide(color: Color(0xFFE4F3F0)))),
      child: SafeArea(bottom: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              RichText(text: const TextSpan(
                style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(text: 'Эй, ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: 'Helpy'),
                ])),
              const Icon(Icons.notifications_none, color: _ink),
            ]),
            const SizedBox(height: 12),
            if (section == 0) _TopTabs(tab: tab, onTab: onTab)
            else Padding(padding: const EdgeInsets.only(top: 2, bottom: 16),
              child: Text(_titles[section], style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w800))),
          ]))));
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    const labels = ['Заявки', 'Исполнитель', 'Локации'];
    return Row(children: [
      for (int i = 0; i < labels.length; i++)
        GestureDetector(onTap: () => onTab(i),
          child: Padding(padding: const EdgeInsets.only(right: 22),
            child: Container(padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(border: Border(
                  bottom: BorderSide(color: tab == i ? _ink : Colors.transparent, width: 3))),
              child: Text(labels[i], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: tab == i ? _ink : _ink.withOpacity(0.5)))))),
    ]);
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.title, required this.place, required this.meta, required this.who});
  final String title, place, meta, who;
  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: _cardDeco(),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(place, style: const TextStyle(color: _muted, fontSize: 13)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEAECEF), borderRadius: BorderRadius.circular(20)),
            child: const Text('Готово', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7480)))),
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