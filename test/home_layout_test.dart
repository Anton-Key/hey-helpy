import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/design.dart';
import 'package:hey_helpy/features/home/hotkeys.dart';
import 'package:hey_helpy/features/requests/order_filter.dart';
import 'package:hey_helpy/features/requests/order_filter_bar.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

void main() {
  group('раскладка меню по ширине', () {
    test('< 900 — нижняя панель, 900–1199 — узкая колонка, ≥ 1200 — широкая',
        () {
      expect(appNavLayoutFor(360), AppNavLayout.bottom);
      expect(appNavLayoutFor(412), AppNavLayout.bottom);
      expect(appNavLayoutFor(899), AppNavLayout.bottom);
      expect(appNavLayoutFor(900), AppNavLayout.rail);
      expect(appNavLayoutFor(1199), AppNavLayout.rail);
      expect(appNavLayoutFor(1200), AppNavLayout.sidebar);
      expect(appNavLayoutFor(1920), AppNavLayout.sidebar);
    });

    test('выбор «Свернуть / Развернуть» действует только на ПК', () {
      expect(appNavLayoutFor(1920, collapsed: true), AppNavLayout.rail);
      expect(appNavLayoutFor(1000, collapsed: false), AppNavLayout.sidebar);
      expect(appNavLayoutFor(412, collapsed: false), AppNavLayout.bottom);
      expect(appNavLayoutFor(412, collapsed: true), AppNavLayout.bottom);
    });
  });

  group('горячие клавиши', () {
    test('N, V, /, ? — когда курсор не в поле ввода', () {
      expect(hotkeyFor(PhysicalKeyboardKey.keyN, typing: false),
          HomeHotkey.newOrder);
      expect(
          hotkeyFor(PhysicalKeyboardKey.keyV, typing: false), HomeHotkey.voice);
      expect(hotkeyFor(PhysicalKeyboardKey.slash, typing: false),
          HomeHotkey.search);
      expect(hotkeyFor(PhysicalKeyboardKey.slash, typing: false, shift: true),
          HomeHotkey.help);
      expect(
          hotkeyFor(PhysicalKeyboardKey.digit7,
              typing: false, shift: true, character: '?'),
          HomeHotkey.help);
    });

    test('в поле ввода и с Ctrl / Cmd — не срабатывают', () {
      for (final k in [
        PhysicalKeyboardKey.keyN,
        PhysicalKeyboardKey.keyV,
        PhysicalKeyboardKey.slash,
      ]) {
        expect(hotkeyFor(k, typing: true), isNull);
        expect(hotkeyFor(k, typing: false, modifier: true), isNull);
      }
      expect(hotkeyFor(PhysicalKeyboardKey.keyN, typing: false, shift: true),
          isNull);
      expect(hotkeyFor(PhysicalKeyboardKey.keyQ, typing: false), isNull);
    });

    testWidgets('буква в поле ввода — текст, а не команда', (tester) async {
      final got = <HomeHotkey>[];
      final field = FocusNode();
      final other = FocusNode();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeHotkeys(
            enabled: () => true,
            onHotkey: got.add,
            child: Column(children: [
              TextField(focusNode: field),
              Focus(focusNode: other, child: const SizedBox(height: 10)),
            ]),
          ),
        ),
      ));
      field.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(got, isEmpty);

      other.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      expect(got, [HomeHotkey.newOrder]);
      field.dispose();
      other.dispose();
    });
  });

  group('список заявок: числа в сегментах и заголовки групп', () {
    final l = lookupAppLocalizations(const Locale('ru'));

    test('выбранный сегмент при фильтрах — «12 из 72», на < 400 — «12»', () {
      String t({bool selected = true, bool narrowed = true, double w = 412}) =>
          segmentCountText(l,
              count: 12,
              total: 72,
              selected: selected,
              narrowed: narrowed,
              width: w);
      expect(t(), '12 из 72');
      expect(l.reqSegAll(t()), 'Все · 12 из 72');
      expect(t(w: 360), '12');
      expect(t(narrowed: false), '12');
      expect(t(selected: false), '12');
      // Подпись для диктора — из тех же чисел.
      expect(l.filterFound(12, 72), 'Найдено 12 из 72');
    });

    test('одна группа — без заголовка, несколько — с заголовками', () {
      expect(showGroupHeaders(const []), isFalse);
      expect(showGroupHeaders(const [OrderGroup('earlier', [])]), isFalse);
      expect(
          showGroupHeaders(
              const [OrderGroup('today', []), OrderGroup('earlier', [])]),
          isTrue);
    });
  });
}
