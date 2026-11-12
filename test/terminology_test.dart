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

  // Шаг 36: название на всех языках — «Dokazio» (одним словом). Старые имена
  // «Hey Helpy», «Эй, Helpy», «Helpy», «CtrlSite» не должны встречаться в том,
  // что видят люди: строки .arb, подпись под иконкой, исходники и сборка сайта,
  // тексты бота. Можно: адрес /hey-helpy/ (GitHub Pages) и имя бота
  // @HeyHelpy_bot — их поменять нельзя (см. отчёт шага 36).
  String visible(String s) => s
      .replaceAll(RegExp(r'hey[-_]helpy', caseSensitive: false), '')
      .replaceAll('HeyHelpy_bot', '');
  final oldName = RegExp(r'helpy|хелпи|ctrl\s*site', caseSensitive: false);
  // «DokaZio», «Doka zio», «DOKAZIO»… — всё, что похоже на имя, но не «Dokazio».
  final misspelled = RegExp(r'doka[\s\-_]*zio', caseSensitive: false);
  bool badSpelling(String s) => misspelled
      .allMatches(s)
      .any((m) => m.group(0) != 'Dokazio' && m.group(0) != 'dokazio');

  List<File> filesIn(String root, RegExp ext) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => ext.hasMatch(f.path) && !f.path.contains('node_modules'))
      .toList();

  final visibleFiles = <File>[
    File('lib/l10n/app_ru.arb'),
    File('lib/l10n/app_en.arb'),
    ...filesIn('android/app/src/main/res', RegExp(r'strings\.xml$')),
    File('web/index.html'),
    File('web/manifest.json'),
    File('supabase/functions/telegram-bot/texts.ts'),
    ...filesIn('tools/site', RegExp(r'content\.(ru|en)\.mjs$|config\.mjs$')),
    ...filesIn('site', RegExp(r'\.(html|txt|xml|json|webmanifest)$')),
  ];

  test('название — Dokazio: нет старых имён там, что видят люди', () {
    final bad = <String>[];
    for (final f in visibleFiles) {
      final text = f.path.endsWith('.arb')
          ? values(f.path).values.join('\n')
          : f.readAsStringSync();
      final m = oldName.firstMatch(visible(text));
      if (m != null) bad.add('${f.path}: «${m.group(0)}»');
    }
    expect(bad, isEmpty);
  });

  test('«Dokazio» написано одним словом и правильно', () {
    final bad = <String>[
      for (final f in visibleFiles)
        if (badSpelling(f.readAsStringSync())) f.path,
    ];
    expect(bad, isEmpty);
    expect(values('lib/l10n/app_en.arb')['appName'], 'Dokazio');
    expect(values('lib/l10n/app_ru.arb')['appName'], 'Dokazio');
    expect(badSpelling('DokaZio'), isTrue);
    expect(badSpelling('Doka zio'), isTrue);
    expect(badSpelling('Dokazio — Contractor Control'), isFalse);
  });

  test('нигде нет «Эй, Helpy» (lib, сайт, функции)', () {
    const roots = ['lib', 'tools/site', 'supabase/functions'];
    final bad = <String>[
      for (final r in roots)
        for (final f in filesIn(r, RegExp(r'\.(dart|arb|ts|mjs|css|json)$')))
          if (f.readAsStringSync().contains('Эй, Helpy')) f.path,
    ];
    expect(bad, isEmpty);
  });
}
