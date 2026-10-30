import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Слова в интерфейсе — решения владельца продукта (шаг 32, CLAUDE.md «Слова в интерфейсе»):
/// «оборудование», а не «прибор»; «количество заявок», а не «число заявок».
/// Проверяются только значения строк (ключи и описания `@…` — нет).
void main() {
  Map<String, String> values(String file) {
    final json = jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
    };
  }

  test('RU: нет «прибор» (все формы) и «число заявок»', () {
    final forbidden = RegExp(r'прибор|число заявок', caseSensitive: false);
    final bad = values('lib/l10n/app_ru.arb').entries.where((e) => forbidden.hasMatch(e.value));
    expect(bad.map((e) => '${e.key}: ${e.value}'), isEmpty);
  });

  test('EN: оборудование — equipment, не device / appliance', () {
    // «device» в английском интерфейсе — только телефон пользователя, не оборудование.
    final forbidden = RegExp(r'\b(device|appliance)s?\b', caseSensitive: false);
    final allowed = {'infoFilters3'}; // «remembered on this device» — про телефон
    final bad = values('lib/l10n/app_en.arb')
        .entries
        .where((e) => !allowed.contains(e.key) && forbidden.hasMatch(e.value));
    expect(bad.map((e) => '${e.key}: ${e.value}'), isEmpty);
  });
}
