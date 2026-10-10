import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/content_navigator.dart';
import 'package:hey_helpy/core/design/design.dart';

// Шаг 15: на ПК вложенный навигатор справа от меню не должен прятать
// боковое меню от диктора и автотестов (барьер страниц — BlockSemantics).
void main() {
  testWidgets('боковое меню видно диктору рядом с ContentNavigatorView',
      (t) async {
    final h = t.ensureSemantics();
    final key = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          AppSideNav(
            brand: 'Эй, Helpy',
            rail: false,
            index: 0,
            onChanged: (_) {},
            items: const [
              AppNavItem(
                  icon: AppIcons.home,
                  activeIcon: AppIcons.homeActive,
                  label: 'Главная'),
              AppNavItem(
                  icon: AppIcons.profile,
                  activeIcon: AppIcons.profileActive,
                  label: 'Профиль',
                  badge: 1),
            ],
            voiceLabel: 'Эй, Helpy',
            voiceSemantic: 'Голосовая заявка',
            onVoice: () {},
            addLabel: 'Заявка',
            onAdd: () {},
            toggleLabel: 'Свернуть меню',
            onToggle: () {},
          ),
          Expanded(
              child: ContentNavigatorView(
                  navKey: key, home: const Text('Раздел'))),
        ]),
      ),
    ));
    for (final label in [
      'Главная',
      'Профиль, 1',
      'Голосовая заявка',
      'Свернуть меню',
      'Раздел'
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(key.currentState, isNotNull);
    h.dispose();
  });
}
