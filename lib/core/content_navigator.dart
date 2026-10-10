import 'package:flutter/material.dart';

/// ПК: навигатор области справа от бокового меню. Экраны, открытые поверх
/// (карточка заявки, объекта, план этажа), открываются в нём — боковое
/// меню остаётся видно. На телефоне его нет (null).
class ContentNavigator extends InheritedWidget {
  const ContentNavigator(
      {super.key, required this.navKey, required super.child});

  final GlobalKey<NavigatorState> navKey;

  static NavigatorState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ContentNavigator>()
      ?.navKey
      .currentState;

  @override
  bool updateShouldNotify(ContentNavigator old) => old.navKey != navKey;
}

/// Область справа от бокового меню: [ContentNavigator] + свой навигатор
/// с одной страницей [home].
///
/// Навигатор — в отдельном контейнере доступности: иначе барьер его
/// страниц (BlockSemantics) прячет от диктора и автотестов всё, что
/// нарисовано раньше, — всё боковое меню.
class ContentNavigatorView extends StatelessWidget {
  const ContentNavigatorView(
      {super.key, required this.navKey, required this.home});

  final GlobalKey<NavigatorState> navKey;
  final Widget home;

  @override
  Widget build(BuildContext context) => ContentNavigator(
        navKey: navKey,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: ClipRect(
            child: Navigator(
              key: navKey,
              pages: [
                MaterialPage<void>(
                    key: const ValueKey('home-section'), child: home),
              ],
              onDidRemovePage: (_) {},
            ),
          ),
        ),
      );
}
