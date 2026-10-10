import 'package:flutter/widgets.dart';

/// Что попросили сделать с вкладкой «Заявки» снаружи (боковое меню ПК,
/// горячие клавиши): создать заявку, голосовая заявка, фокус на поиск.
enum HomeAction { create, voice, search }

/// Связь главного экрана с вкладкой «Заявки»: кнопки создания живут в
/// боковом меню (ПК) и в горячих клавишах, а данные для формы — во вкладке.
/// Главный экран открывает вкладку и оставляет просьбу [request]; вкладка
/// выполняет её, когда справочники загружены ([take]).
class HomeActions extends ChangeNotifier {
  /// Поле поиска заявок (горячая клавиша «/»).
  final searchFocus = FocusNode(debugLabel: 'requests-search');

  HomeAction? _pending;
  int _overdue = 0;

  /// Просроченных заявок (бейдж «Главная» в боковом меню).
  int get overdue => _overdue;

  void request(HomeAction a) {
    _pending = a;
    notifyListeners();
  }

  /// Забрать просьбу (один раз).
  HomeAction? take() {
    final a = _pending;
    _pending = null;
    return a;
  }

  void setOverdue(int n) {
    if (n == _overdue) return;
    _overdue = n;
    notifyListeners();
  }

  @override
  void dispose() {
    searchFocus.dispose();
    super.dispose();
  }
}
