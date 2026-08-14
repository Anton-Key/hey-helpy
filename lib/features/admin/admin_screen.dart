import 'package:flutter/material.dart';

/// Заготовка раздела администрирования (Фаза 1).
/// Справочники: компания, объекты (+гео), направления, оборудование,
/// подрядчики и инвайт-ссылки, пользователи и роли.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  static const _sections = <(IconData, String)>[
    (Icons.apartment, 'Объекты и геолокация'),
    (Icons.account_tree_outlined, 'Направления / департаменты'),
    (Icons.chair_outlined, 'Оборудование и активы'),
    (Icons.handshake_outlined, 'Подрядные организации'),
    (Icons.link, 'Инвайт-ссылки исполнителям'),
    (Icons.people_outline, 'Пользователи и роли'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Администрирование')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (icon, title) in _sections)
            Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                trailing: const Icon(Icons.lock_outline, size: 18),
                subtitle: const Text('Появится в Фазе 1'),
              ),
            ),
        ],
      ),
    );
  }
}
