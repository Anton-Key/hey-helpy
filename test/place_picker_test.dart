import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/floors/floor_models.dart';
import 'package:hey_helpy/features/floors/plan_logic.dart';
import 'package:hey_helpy/features/requests/requests.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// Шаг 21: помещения в новой заявке — «301 · Переговорная», по этажу и
/// номеру, поиск по номеру и названию.
PlanItem _p(String id, String name, {String? code, String? floor}) => PlanItem(
    kind: PlanKind.place, id: id, name: name, code: code, floorId: floor);

const _floors = [
  Floor(id: 'f3', objectId: 'o', companyId: 'c', name: '3 этаж', level: 3),
  Floor(id: 'f1', objectId: 'o', companyId: 'c', name: '1 этаж', level: 1),
];

final _places = [
  _p('a', 'Серверная', code: '303', floor: 'f3'),
  _p('b', 'Переговорная', code: '301', floor: 'f3'),
  _p('c', 'Склад', floor: 'f1'),
  _p('d', 'Кухня', code: '10', floor: 'f1'),
  _p('e', 'Лобби', code: '2', floor: 'f1'),
  _p('f', 'Холл', code: '101', floor: 'f1'),
  _p('g', 'Парковка'),
];

void main() {
  test('по этажу, затем по номеру (2, 10, 101), без номера — после', () {
    final sorted = sortPlacesForPicker(_places, _floors);
    expect(sorted.map((p) => p.label), [
      '2 · Лобби',
      '10 · Кухня',
      '101 · Холл',
      'Склад',
      '301 · Переговорная',
      '303 · Серверная',
      'Парковка',
    ]);
  });

  test('поиск по номеру и по названию, без учёта регистра', () {
    List<String> find(String q) =>
        [for (final p in _places) if (placeMatchesQuery(p, q)) p.id];
    expect(find('301'), ['b']);
    expect(find('перег'), ['b']);
    expect(find('СЕРВЕР'), ['a']);
    expect(find(''), hasLength(_places.length));
    expect(find('нет такого'), isEmpty);
  });

  testWidgets('окно выбора: «301 · Переговорная», поиск по номеру',
      (t) async {
    String? picked;
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
      home: Builder(
        builder: (context) => Scaffold(
          body: AppButton(
            label: 'open',
            onPressed: () async {
              picked = await showAppSheet<String>(
                  context: context,
                  builder: (_) => PlacePickerSheet(
                      places: sortPlacesForPicker(_places, _floors),
                      floors: const {'f1': '1 этаж', 'f3': '3 этаж'},
                      selected: null));
            },
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('301 · Переговорная'), findsOneWidget);
    expect(find.text('Без помещения'), findsOneWidget);
    await t.enterText(find.byType(TextField), '301');
    await t.pumpAndSettle();
    expect(find.text('303 · Серверная'), findsNothing);
    expect(find.text('Без помещения'), findsNothing);
    await t.tap(find.text('301 · Переговорная'));
    await t.pumpAndSettle();
    expect(picked, 'b');
  });
}
