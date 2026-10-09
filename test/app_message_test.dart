import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/design/icons.dart';
import 'package:hey_helpy/core/app_message.dart';

/// Экран с кнопкой внизу — сообщение не должно её закрывать.
Widget _app(void Function(BuildContext) onTap) => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('t')),
        body: Builder(
            builder: (context) => Center(
                child: TextButton(
                    onPressed: () => onTap(context), child: const Text('go')))),
        bottomNavigationBar: const SizedBox(
            height: 80, child: Center(child: Text('bottom-button'))),
      ),
    );

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('ПК: карточка справа сверху, исчезает через 3 с', (tester) async {
    _size(tester, const Size(1280, 720));
    await tester.pumpWidget(_app((c) => showAppMessage(c, 'Сохранено')));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final rect = tester.getRect(find.text('Сохранено'));
    expect(rect.right, greaterThan(1280 - 24 - 360));
    expect(rect.left, greaterThan(1280 - 24 - 360 - 1));
    expect(rect.top, lessThan(200));
    expect(
        rect.bottom, lessThan(tester.getRect(find.text('bottom-button')).top));
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('Сохранено'), findsOneWidget, reason: 'ещё 3 с не прошло');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Сохранено'), findsNothing);
  });

  testWidgets('ошибка висит 5 с, закрывается крестиком', (tester) async {
    _size(tester, const Size(1280, 720));
    await tester.pumpWidget(_app(
        (c) => showAppMessage(c, 'Не удалось', type: AppMessageType.error)));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Не удалось'), findsOneWidget);
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось'), findsNothing);
  });

  testWidgets('телефон: на всю ширину под шапкой; стопка не больше 3',
      (tester) async {
    _size(tester, const Size(412, 700));
    var n = 0;
    await tester.pumpWidget(_app((c) => showAppMessage(c, 'm${++n}')));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('m1'), findsNothing);
    expect(find.text('m2'), findsOneWidget);
    expect(find.text('m4'), findsOneWidget);
    final rect = tester.getRect(find.text('m2'));
    expect(rect.top, greaterThanOrEqualTo(kToolbarHeight));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('m4'), findsNothing);
  });
}
