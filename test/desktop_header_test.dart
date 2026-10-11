import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Шаг 21: на ПК в верхней строке нет аватара «Меню профиля» — «Профиль»
/// есть в боковом меню. Главный экран без Supabase не собрать, поэтому
/// проверка — по исходному коду; вид проверяет `/screens` (кадр ПК).
void main() {
  final src = File('lib/features/home/home_screen.dart').readAsStringSync();

  test('в служебных кнопках ПК нет аватара и меню профиля', () {
    final start = src.indexOf('List<Widget> _utilityTail()');
    expect(start, isNot(-1));
    final end = src.indexOf('\n  }\n', start);
    final tail = src.substring(start, end);
    expect(tail, isNot(contains('InitialsTile')));
    expect(tail, isNot(contains('navAccount')));
    expect(src, isNot(contains('_accountMenu')));
  });

  test('всё из бывшего меню есть на экране «Профиль»', () {
    final start = src.indexOf('Widget _profileView()');
    expect(start, isNot(-1));
    final view = src.substring(start);
    for (final k in [
      'l.profileMyCompany',
      'l.profileSettings',
      'l.profileSignOut',
      'l.profileLanguage',
      'l.profileNotifications',
    ]) {
      expect(view, contains(k), reason: k);
    }
  });
}
