import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Шаг 21: в строке заявки объект — жирным, город — серым, одна строка.
void main() {
  Future<void> pump(WidgetTester t, double width, String object) async {
    final onest = FontLoader('Onest')
      ..addFont(rootBundle.load('assets/fonts/Onest-Regular.ttf'));
    await onest.load();
    t.view.physicalSize = Size(width, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AppGroup(children: [
            AppRow(
              leading: const PriorityDot('critical'),
              title: 'Застрял лифт в лобби',
              place: ObjectPlaceLine(object, city: 'Санкт-Петербург'),
              subtitle: 'Лобби · Другое',
              trailing: const StatusPill('in_progress'),
              onTap: () {},
            ),
          ]),
        ]),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('объект жирным основным цветом, город — серым через « · »',
      (t) async {
    await pump(t, 1280, 'БЦ «Лахта Плаза»');
    final p = t.renderObject<RenderParagraph>(find.descendant(
        of: find.byType(ObjectPlaceLine), matching: find.byType(RichText)));
    final parts = <TextSpan>[];
    p.text.visitChildren((s) {
      if (s is TextSpan && s.text != null) parts.add(s);
      return true;
    });
    expect(parts[0].text, 'БЦ «Лахта Плаза»');
    expect(parts[0].style!.fontWeight, FontWeight.w600);
    expect(parts[0].style!.color, AppColors.ink);
    expect(parts[1].text, ' · Санкт-Петербург');
    expect(parts[1].style!.color, AppColors.secondary);
    expect(p.didExceedMaxLines, isFalse);
  });

  testWidgets('360 px: длинное название — одна строка с многоточием',
      (t) async {
    await pump(t, 360,
        'Многофункциональный деловой центр «Северная столица» корпус Б');
    final line = find.byType(ObjectPlaceLine);
    expect(line, findsOneWidget);
    final p = t.renderObject<RenderParagraph>(
        find.descendant(of: line, matching: find.byType(RichText)));
    expect(p.maxLines, 1);
    expect(p.overflow, TextOverflow.ellipsis);
    expect(t.getSize(line).height, lessThan(24));
    expect(t.takeException(), isNull);
  });
}
