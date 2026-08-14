import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../auth/auth_repository.dart';

const _panel = Color(0xFFF2F3F5);
const _line = Color(0xFFE8EAED);
const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _onBrand = Color(0xFF06342A);

/// Главный экран Hey Helpy — перенос дизайна кликабельного прототипа.
/// Светлый градиент в шапке, вордмарк «Эй, Helpy», верхние вкладки
/// (Заявки/Исполнитель/Локации) и нижнее меню (Главная/История/Отчёты/Профиль).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthRepository();
  int _section = 0; // 0 Главная, 1 История, 2 Отчёты, 3 Профиль
  int _tab = 0; // 0 Заявки, 1 Исполнитель, 2 Локации
  int _filter = 0;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _auth.fetchMyProfile();
    if (mounted) setState(() => _profile = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _Header(
            section: _section,
            tab: _tab,
            onTab: (i) => setState(() => _tab = i),
          ),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: _section == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/create'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: _onBrand,
              icon: const Icon(Icons.add),
              label: const Text('Создать заявку',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (i) => setState(() => _section = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.history), label: 'История'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Отчёты'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Профиль'),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_section) {
      case 1:
        return _history();
      case 2:
        return _reports();
      case 3:
        return _profileView();
      default:
        switch (_tab) {
          case 1:
            return _executors();
          case 2:
            return _locations();
          default:
            return _requests();
        }
    }
  }

  // ---------------- Заявки ----------------
  Widget _requests() {
    const filters = ['Все', 'Новые', 'В работе', 'Просрочено', 'Готово'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        const _Search(hint: 'Поиск по заявкам…', showFilter: true),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < filters.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: filters[i],
                    active: _filter == i,
                    onTap: () => setState(() => _filter = i),
                  ),
                ),
              _FilterChip(label: 'Тип ▾', active: false, outlined: true, onTap: () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('Заявок: 5',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 10),
        _TaskCard(
          title: 'Протекает кран',
          place: 'Москва · Переговорная №3',
          status: _St.prog,
          meta: 'Сантехника · фото',
          who: 'ИП',
          high: true,
        ),
        _TaskCard(
          title: 'Не работает кондиционер',
          place: 'Москва · Опенспейс, 5 этаж',
          status: _St.late,
          meta: 'Климат · +2 ч',
          who: 'СК',
          high: true,
        ),
        _TaskCard(
          title: 'Заменить лампу',
          place: 'Москва · Холл, 1 этаж',
          status: _St.newO,
          meta: 'Электрика',
          who: null,
        ),
        _TaskCard(
          title: 'Уборка санузлов · регламент',
          place: 'Астана · 3 этаж · ежедневно',
          status: _St.newO,
          meta: 'Клининг · чек-лист 0/6',
          who: 'КЛ',
        ),
        _TaskCard(
          title: 'Ремонт стула',
          place: 'Астана · Кабинет 512',
          status: _St.done,
          meta: 'Мебель · 40 мин',
          who: 'ИП',
        ),
      ],
    );
  }

  // ---------------- Исполнитель ----------------
  Widget _executors() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: const [
        _Search(hint: 'Поиск исполнителей…'),
        SizedBox(height: 12),
        _OrgCard(name: 'СтройКом', staff: '50–150', busy: '2 / 3', spec: 'Сантехника, климат'),
        _OrgCard(name: 'КлинЛайн', staff: '10–50', busy: '1 / 1', spec: 'Клининг'),
      ],
    );
  }

  // ---------------- Локации ----------------
  Widget _locations() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: const [
        _Search(hint: 'Поиск локаций…'),
        SizedBox(height: 12),
        _LocCard(city: 'Москва', addr: 'Москва, Россия', phone: '+7 (879) 879-87-98', busy: '3 / 5', dark: false),
        _LocCard(city: 'Астана', addr: 'Astana, Казахстан', phone: '+7 (555) 555-20-20', busy: '1 / 1', dark: true),
      ],
    );
  }

  // ---------------- История ----------------
  Widget _history() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: const [
        Text('Выполнено за месяц: 12',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 13)),
        SizedBox(height: 10),
        _TaskCard(title: 'Ремонт стула', place: 'Астана · Кабинет 512', status: _St.done, meta: '12 авг · 40 мин', who: 'ИП'),
        _TaskCard(title: 'Замена фильтров', place: 'Москва · Серверная', status: _St.done, meta: '11 авг · 1 ч 20 мин', who: 'СК'),
        _TaskCard(title: 'Уборка холла', place: 'Москва · 1 этаж', status: _St.done, meta: '11 авг · 55 мин', who: 'КЛ'),
      ],
    );
  }

  // ---------------- Отчёты ----------------
  Widget _reports() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Row(
          children: const [
            Expanded(child: _Kpi(n: '27', t: 'заявок за месяц')),
            SizedBox(width: 10),
            Expanded(child: _Kpi(n: '92%', t: 'в срок')),
            SizedBox(width: 10),
            Expanded(child: _Kpi(n: '1.4ч', t: 'ср. время')),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Заявки по неделям', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bar(0.45), _bar(0.7), _bar(0.55), _bar(0.9),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: _onBrand,
          ),
          child: const Text('Экспорт в PDF', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text('Полные отчёты и фильтры — в web-версии',
              style: TextStyle(color: _muted, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _bar(double h) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: FractionallySizedBox(
            heightFactor: h,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
          ),
        ),
      );

  // ---------------- Профиль ----------------
  Widget _profileView() {
    final name = _profile?.displayName ?? 'Антон';
    final role = _profile?.role.title ?? 'Администратор';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(name.characters.first,
                    style: const TextStyle(color: _onBrand, fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(role, style: const TextStyle(color: _muted, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _row(Icons.apartment_outlined, 'Моя компания'),
        _row(Icons.notifications_none, 'Уведомления'),
        _row(Icons.language, 'Язык · Русский'),
        _row(Icons.settings_outlined, 'Настройки'),
        _row(Icons.logout, 'Выйти', danger: true, onTap: () => _auth.signOut()),
      ],
    );
  }

  Widget _row(IconData icon, String text, {bool danger = false, VoidCallback? onTap}) {
    final color = danger ? const Color(0xFFC24444) : _ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: _cardDeco(),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              if (!danger) const Spacer(),
              if (!danger) const Icon(Icons.chevron_right, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    );

// ==================== Шапка ====================
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
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: HeyHelpyTheme.headerGradient,
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE4F3F0))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800),
                      children: [
                        TextSpan(text: 'Эй, ', style: TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: 'Helpy'),
                      ],
                    ),
                  ),
                  const Icon(Icons.notifications_none, color: _ink),
                ],
              ),
              const SizedBox(height: 12),
              if (section == 0)
                _TopTabs(tab: tab, onTab: onTab)
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 16),
                  child: Text(_titles[section],
                      style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    const labels = ['Заявки', 'Исполнитель', 'Локации'];
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onTab(i),
            child: Padding(
              padding: const EdgeInsets.only(right: 22),
              child: Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: tab == i ? _ink : Colors.transparent, width: 3),
                  ),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tab == i ? _ink : _ink.withOpacity(0.5))),
              ),
            ),
          ),
      ],
    );
  }
}

// ==================== Мелкие виджеты ====================
class _Search extends StatelessWidget {
  const _Search({required this.hint, this.showFilter = false});
  final String hint;
  final bool showFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: _muted),
          const SizedBox(width: 10),
          Expanded(child: Text(hint, style: const TextStyle(color: _muted, fontSize: 15))),
          if (showFilter) const Icon(Icons.tune, size: 20, color: _ink),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap, this.outlined = false});
  final String label;
  final bool active;
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _ink : (outlined ? Colors.white : _panel),
          borderRadius: BorderRadius.circular(20),
          border: outlined ? Border.all(color: _line) : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : (outlined ? _ink : _muted))),
      ),
    );
  }
}

enum _St { newO, prog, late, done }

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.place,
    required this.status,
    required this.meta,
    required this.who,
    this.high = false,
  });
  final String title;
  final String place;
  final _St status;
  final String meta;
  final String? who;
  final bool high;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    late String txt;
    late Color bg;
    late Color fg;
    switch (status) {
      case _St.newO:
        txt = 'Новая';
        bg = const Color(0xFFE8F6F2);
        fg = const Color(0xFF249F88);
        break;
      case _St.prog:
        txt = 'В работе';
        bg = const Color(0xFFFBF0D9);
        fg = const Color(0xFFA9790C);
        break;
      case _St.late:
        txt = 'Просрочено';
        bg = const Color(0xFFFBE8E8);
        fg = const Color(0xFFC24444);
        break;
      case _St.done:
        txt = 'Готово';
        bg = const Color(0xFFEAECEF);
        fg = const Color(0xFF6B7480);
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: high ? const Color(0xFFC24444) : const Color(0xFFD7DBE0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.business, size: 14, color: _muted),
                        const SizedBox(width: 5),
                        Expanded(child: Text(place, style: const TextStyle(color: _muted, fontSize: 13))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(txt, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(meta, style: const TextStyle(color: _muted, fontSize: 12)),
              const Spacer(),
              if (who != null)
                CircleAvatar(radius: 11, backgroundColor: brand, child: Text(who!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _onBrand)))
              else
                const Text('не назначен', style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  const _OrgCard({required this.name, required this.staff, required this.busy, required this.spec});
  final String name, staff, busy, spec;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: const Color(0xFFE8F6F2), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.business, color: brand),
              ),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          _kv('Количество сотрудников', staff),
          _kv('В работе', busy),
          _kv('Специализация', spec),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: _muted, fontSize: 13)),
            const Spacer(),
            Text(v, style: const TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      );
}

class _LocCard extends StatelessWidget {
  const _LocCard({required this.city, required this.addr, required this.phone, required this.busy, required this.dark});
  final String city, addr, phone, busy;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [const Color(0xFF2B2F33), const Color(0xFF111111)]
                    : [const Color(0xFFCFD8DC), const Color(0xFF9AA7AD)],
              ),
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(city, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                Text(addr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                _kv('Контактный номер', phone),
                _kv('В работе', busy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: _muted, fontSize: 13)),
            const Spacer(),
            Text(v, style: const TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.n, required this.t});
  final String n, t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(t, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }
}
