import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/requests/order_menu.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

Widget _app(Widget menu, {Widget? body}) => MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
          appBar: AppBar(title: const Text('Заявка'), actions: [menu]),
          body: body),
    );

void main() {
  testWidgets('менеджер: в меню «⋯» есть «Отменить» и «Удалить»',
      (tester) async {
    var deleted = 0, cancelled = 0;
    await tester.pumpWidget(_app(OrderMenu(
        canCancel: true,
        canDelete: true,
        onCancel: () => cancelled++,
        onDelete: () => deleted++)));
    // Кнопка меню — в шапке, видна без прокрутки.
    final menu = find.byTooltip('Ещё');
    expect(menu, findsOneWidget);
    expect(tester.getRect(menu).top, lessThan(kToolbarHeight));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Отменить'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(cancelled, 0);
  });

  testWidgets('не менеджер: «Удалить» нет; нечего показать — нет и меню',
      (tester) async {
    await tester.pumpWidget(_app(OrderMenu(
        canCancel: true, canDelete: false, onCancel: () {}, onDelete: () {})));
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить'), findsOneWidget);
    expect(find.text('Удалить'), findsNothing);

    await tester.pumpWidget(_app(OrderMenu(
        canCancel: false, canDelete: false, onCancel: () {}, onDelete: () {})));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ещё'), findsNothing);
  });

  testWidgets('диалог удаления: текст, «Удалить» и «Отмена»', (tester) async {
    bool? answer;
    await tester.pumpWidget(_app(const SizedBox(),
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () async =>
                    answer = await confirmDeleteOrder(context),
                child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Удалить заявку безвозвратно?'), findsOneWidget);
    expect(find.textContaining('лучше «Отменить»'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Удалить'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });
}
