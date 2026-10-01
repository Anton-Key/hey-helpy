import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';

/// Заготовка раздела администрирования (Фаза 1).
/// Справочники: компания, объекты (+гео), направления, оборудование,
/// подрядчики и инвайт-ссылки, пользователи и роли.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  static final _sections = <(IconData, String Function(AppLocalizations))>[
    (Icons.apartment, (l) => l.adminObjects),
    (Icons.account_tree_outlined, (l) => l.adminDepartments),
    (Icons.chair_outlined, (l) => l.adminAssets),
    (Icons.handshake_outlined, (l) => l.adminContractors),
    (Icons.link, (l) => l.adminInvites),
    (Icons.people_outline, (l) => l.adminUsers),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (icon, title) in _sections)
            Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(title(l)),
                trailing: const Icon(Icons.lock_outline, size: 18),
                subtitle: Text(l.adminComingSoon),
              ),
            ),
        ],
      ),
    );
  }
}
