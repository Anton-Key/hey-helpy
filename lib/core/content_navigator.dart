import 'package:flutter/widgets.dart';

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
