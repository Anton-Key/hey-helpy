import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/ppr/ppr_logic.dart';
import 'package:hey_helpy/features/ppr/ppr_repository.dart';
import 'package:hey_helpy/features/ppr/ppr_tab.dart';
import 'package:hey_helpy/features/ppr/ppr_view.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Самые длинные строки демо: Абиджан, «каждые полгода», «Без подрядчика».
PlanView _view(String title, PeriodKind kind, String object, String city,
        String? contractor) =>
    PlanView(
      plan: MaintenancePlan(
          id: 'p',
          objectId: 'o',
          layerId: 'l',
          title: title,
          kind: kind,
          startsOn: DateTime(2026, 4, 1)),
      object: Obj(id: 'o', name: object, type: 'office', city: city),
      layer: const Layer(id: 'l', name: 'Системы безопасности'),
      contractor:
          contractor == null ? null : Contractor(id: 'c', orgName: contractor),
      period: PeriodBounds(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
      state: PeriodState.notStarted,
    );

void main() {
  for (final width in [412.0, 360.0]) {
    for (final locale in ['ru', 'en']) {
      testWidgets('строка ППР на $width ($locale): подрядчик не обрезан',
          (t) async {
        // Настоящий шрифт: тестовый по умолчанию шире (каждая буква — квадрат).
        final onest = FontLoader('Onest')
          ..addFont(rootBundle.load('assets/fonts/Onest-Regular.ttf'));
        await onest.load();
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          locale: Locale(locale),
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
                PprPlanRow(
                    view: _view(
                        'Проверка генератора',
                        PeriodKind.month,
                        'Ivoire Trade Center',
                        'Абиджан',
                        'Ivoire Maintenance')),
                // Без подрядчика: «… · II полугодие 2026 · Без подрядчика».
                PprPlanRow(
                    view: _view('Поверка датчиков дыма', PeriodKind.halfYear,
                        'БЦ «Демо»', 'Белград', null)),
                PprPlanRow(
                    view: _view(
                        'Чистка фильтров кондиционеров',
                        PeriodKind.halfYear,
                        'Офис 2',
                        'Дубай',
                        'Gulf FM Services')),
              ]),
            ]),
          ),
        ));
        await t.pumpAndSettle();
        for (final p
            in t.renderObjectList<RenderParagraph>(find.byType(RichText))) {
          expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
          // Шаг 21: в русском интерфейсе нет аббревиатуры «ППР».
          expect(p.text.toPlainText(), isNot(contains('ППР')));
        }
      });
    }
  }
}
