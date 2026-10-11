import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Шаг 21: «ППР» в русском интерфейсе заменено на «Плановое ТО» /
/// «Плановое обслуживание». Идентификаторы в коде и базе (`ppr_*`) остались.
void main() {
  test('ни одна русская строка интерфейса не содержит «ППР»', () {
    final arb = jsonDecode(File('lib/l10n/app_ru.arb').readAsStringSync())
        as Map<String, dynamic>;
    final bad = [
      for (final e in arb.entries)
        if (!e.key.startsWith('@') && '${e.value}'.contains('ППР')) e.key,
    ];
    expect(bad, isEmpty);
  });

  test('меню и вкладка — «Плановое ТО», заголовок — «Плановое обслуживание»',
      () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(ru.tabPpr, 'Плановое ТО');
    expect(ru.pprTitle, 'Плановое обслуживание');
    expect(ru.pprTag, 'Плановое ТО');
    expect(ru.pprTaskLine('октябрь 2026', '31 окт.'),
        'Плановое ТО · октябрь 2026 · до 31 окт.');
    expect(ru.pprSummary('Октябрь', 1, 8), isNot(contains('ППР')));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.pprTitle, 'Preventive maintenance');
  });
}
