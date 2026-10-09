import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/scrolling.dart';

void main() {
  test('куда прокручивать по клавишам', () {
    double t(ScrollKey k, double px) =>
        scrollKeyTarget(k, pixels: px, min: 0, max: 1000, viewport: 500);
    expect(t(ScrollKey.lineDown, 100), 160);
    expect(t(ScrollKey.lineUp, 30), 0);
    expect(t(ScrollKey.pageDown, 0), 450);
    expect(t(ScrollKey.pageDown, 900), 1000);
    expect(t(ScrollKey.pageUp, 450), 0);
    expect(t(ScrollKey.home, 700), 0);
    expect(t(ScrollKey.end, 10), 1000);
  });

  Future<ScrollController> pumpList(WidgetTester tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => KeyboardScrolling(child: child!),
      home: Scaffold(
        body: Column(children: [
          const TextField(key: Key('field')),
          Expanded(
            child: ListView(controller: c, children: [
              for (var i = 0; i < 100; i++)
                SizedBox(height: 50, child: Text('row $i')),
            ]),
          ),
        ]),
      ),
    ));
    return c;
  }

  testWidgets('PageDown, стрелки, End и Home прокручивают без фокуса',
      (tester) async {
    final c = await pumpList(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(c.offset, greaterThan(300));
    final afterPage = c.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(c.offset, afterPage + scrollLineStep);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(c.offset, c.position.maxScrollExtent);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(c.offset, 0);
  });

  testWidgets('фокус в текстовом поле — стрелки для текста', (tester) async {
    final c = await pumpList(tester);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(c.offset, 0);
  });
}
