import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/deferred_view.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('загрузка → экран', (tester) async {
    final c = Completer<void>();
    await tester.pumpWidget(_app(DeferredView(
        load: () => c.future, builder: (_) => const Text('Отчёты'))));
    expect(find.text('Отчёты'), findsNothing);
    c.complete();
    await tester.pump();
    expect(find.text('Отчёты'), findsOneWidget);
  });

  testWidgets('нет сети → «Повторить» загружает снова', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(DeferredView(
        load: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
        },
        builder: (_) => const Text('Отчёты'))));
    await tester.pump();
    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Отчёты'), findsOneWidget);
  });
}
