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

  // Шаг 33: название на всех языках — «Hey Helpy». Голосовая фраза
  // «Эй, Хелпи» (ключ wakePhrase) — другое написание и под правило не попадает.
  test('нигде нет старого названия «Эй, Helpy»', () {
    const roots = ['lib', 'tools/site', 'supabase/functions'];
    final bad = <String>[];
    for (final r in roots) {
      for (final f in Directory(r).listSync(recursive: true)) {
        if (f is! File || f.path.contains('node_modules')) continue;
        if (!RegExp(r'\.(dart|arb|ts|mjs|css|json)$').hasMatch(f.path)) continue;
        if (f.readAsStringSync().contains('Эй, Helpy')) bad.add(f.path);
      }
    }
    for (final f in Directory('android/app/src/main/res')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('strings.xml'))) {
      if (f.readAsStringSync().contains('Эй, Helpy')) bad.add(f.path);
    }
    expect(bad, isEmpty);
  });
}
