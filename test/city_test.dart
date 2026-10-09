import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/city.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/directory/object_picker.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Obj obj(String id, String name, String? address) =>
    Obj(id: id, name: name, address: address, type: 'office');

void main() {
  test('cityOf: часть адреса до первой запятой', () {
    expect(cityOf('Москва, ул. Лесная (демо)'), 'Москва');
    expect(cityOf('  Абиджан , Кокоди, рядом с Sofitel (демо)'), 'Абиджан');
    expect(cityOf('Без запятой'), '');
    expect(cityOf(', начинается с запятой'), '');
    expect(cityOf(''), '');
    expect(cityOf(null), '');
  });

  test('objectDisplayName: «Город · Название», без города — название', () {
    final o = obj('1', 'Офис 3', 'Москва, Павелецкая пл. (демо)');
    expect(objectDisplayName(o), 'Москва · Офис 3');
    expect(objectDisplayName(o, withCity: false), 'Офис 3');
    expect(objectDisplayName(obj('2', 'Склад', null)), 'Склад');
    expect(objectLabel('Склад', 'просто текст'), 'Склад');
  });

  test(
      'groupObjectsByCity: города по алфавиту, «без города» в конце, '
      'внутри — по названию (числа по значению)', () {
    final groups = groupObjectsByCity([
      obj('a', 'Офис 10', 'Москва, А'),
      obj('b', 'Склад', null),
      obj('c', 'Офис 2', 'Москва, Б'),
      obj('d', 'Офис 1', 'Дубай, Marina'),
      obj('e', 'Хаб 1', 'белград, центр'),
      obj('f', 'Skyline', 'Белград, Kneza Miloša'),
    ]);
    // «белград» и «Белград» — один город (подпись — как встретилась первой).
    expect(
        [for (final g in groups) g.city], ['белград', 'Дубай', 'Москва', '']);
    expect(groups.last.city, '');
    final moscow = groups.firstWhere((g) => g.city == 'Москва');
    expect([for (final o in moscow.items) o.name], ['Офис 2', 'Офис 10']);
    expect([for (final o in groups.first.items) o.name], ['Skyline', 'Хаб 1']);
  });

  test('compareCities и citiesOf', () {
    final list = ['Москва', '', 'Абиджан', 'Шэньчжэнь', 'Белград']
      ..sort(compareCities);
    expect(list, ['Абиджан', 'Белград', 'Москва', 'Шэньчжэнь', '']);
    expect(citiesOf(['Москва, 1', 'Дубай, 2', 'москва, 3', null]),
        ['Дубай', 'Москва']);
  });

  group('Подпись выбора объектов', () {
    final l = lookupAppLocalizations(const Locale('ru'));
    final objects = [
      for (var i = 1; i <= 5; i++) obj('m$i', 'Офис $i', 'Москва, улица $i'),
      obj('d1', 'Офис 1', 'Дубай, Marina'),
      obj('s', 'Склад', null),
    ];

    test('ничего / один / весь город / несколько', () {
      expect(objectsSelectionLabel(l, {}, objects), isNull);
      expect(objectsSelectionLabel(l, {'m3'}, objects), 'Москва · Офис 3');
      expect(objectsSelectionLabel(l, {'m1', 'm2', 'm3', 'm4', 'm5'}, objects),
          'Москва (5)');
      expect(objectsSelectionLabel(l, {'m3', 'm1', 'd1'}, objects),
          'Дубай · Офис 1 +2');
      expect(objectsSelectionLabel(l, {'m1', 'm2'}, objects),
          'Москва · Офис 1 +1');
      expect(objectsSelectionLabel(l, {'s'}, objects), 'Склад');
    });

    test('поиск по названию, городу и адресу', () {
      expect(objectMatches(objects[2], 'москва 3'), isTrue);
      expect(objectMatches(objects[5], 'дубай'), isTrue);
      expect(objectMatches(objects[5], 'москва'), isFalse);
      expect(objectMatches(objects[6], ''), isTrue);
    });
  });
}
