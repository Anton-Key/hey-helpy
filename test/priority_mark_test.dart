import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Шаг 21: у критичной заявки вместо красной точки — красный «!».
void main() {
  Future<void> pump(WidgetTester t, String priority, String locale) =>
      t.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: PriorityDot(priority))),
      ));

  for (final (locale, label) in [('ru', 'Критический'), ('en', 'Critical')]) {
    testWidgets('критичная ($locale): красный «!» с подсказкой «$label»',
        (t) async {
      await pump(t, 'critical', locale);
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.icon, AppIcons.critical);
      expect(icon.color, AppColors.priorityCritical);
      expect(icon.size, greaterThanOrEqualTo(10));
      expect(t.widget<Tooltip>(find.byType(Tooltip)).message, label);
    });
  }

  testWidgets('остальные приоритеты — по-прежнему точка, той же ширины',
      (t) async {
    await pump(t, 'critical', 'ru');
    final w = t.getSize(find.byType(PriorityDot)).width;
    for (final p in ['high', 'normal', 'low']) {
      await pump(t, p, 'ru');
      expect(find.byType(Icon), findsNothing, reason: p);
      expect(find.byType(Tooltip), findsNothing, reason: p);
      expect(t.getSize(find.byType(PriorityDot)).width, w, reason: p);
    }
  });
}
