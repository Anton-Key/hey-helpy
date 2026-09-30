import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/requests/create_request_screen.dart';
import 'package:hey_helpy/features/requests/requests.dart';

/// Репозиторий без Supabase: запоминает, что отправил экран.
class FakeRepo extends RequestsRepo {
  final created = <WorkOrderDraft>[];
  final updated = <String, WorkOrderDraft>{};
  Completer<void>? gate;
  Object? error;

  @override
  Future<String> createOrder(WorkOrderDraft d) async {
    created.add(d);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return 'new-id';
  }

  @override
  Future<void> update(String id, WorkOrderDraft d) async {
    updated[id] = d;
  }
}

final objects = [Obj(id: 'o1', name: 'БЦ Север', type: 'office')];

Future<void> pumpScreen(WidgetTester tester, FakeRepo repo, {Map<String, dynamic>? existing}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: CreateRequestScreen(repo: repo, objects: objects, existing: existing),
  ));
}

Finder field(String hint) => find.widgetWithText(TextField, hint);

void main() {
  testWidgets('без описания проблемы заявка не отправляется', (tester) async {
    final repo = FakeRepo();
    await pumpScreen(tester, repo);

    await tester.tap(find.byKey(const Key('submitRequest')));
    await tester.pump();

    expect(find.text('Опишите проблему в двух словах'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('создаёт заявку с приоритетом, периодом и чек-листом', (tester) async {
    final repo = FakeRepo();
    await pumpScreen(tester, repo);

    await tester.enterText(field('Например, протекает кран'), '  Протекает кран ');
    await tester.tap(find.text('Сантехника'));
    await tester.tap(find.text('Высокий'));
    await tester.tap(find.text('Регламентная'));
    await tester.pump();
    await tester.tap(find.text('Ежемесячно'));

    await tester.enterText(field('Добавить пункт, например «Перекрыть воду»'), 'Перекрыть воду');
    await tester.tap(find.byTooltip('Добавить пункт'));
    await tester.pump();
    // Недописанный пункт тоже должен попасть в заявку.
    await tester.enterText(field('Добавить пункт, например «Перекрыть воду»'), 'Заменить прокладку');

    await tester.tap(find.byKey(const Key('submitRequest')));
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    final d = repo.created.single;
    expect(d.title, 'Протекает кран');
    expect(d.workType, 'Сантехника');
    expect(d.priority, 'high');
    expect(d.period, 'month');
    expect(d.checklist, ['Перекрыть воду', 'Заменить прокладку']);
  });

  testWidgets('повторное нажатие во время сохранения не создаёт дубль', (tester) async {
    final repo = FakeRepo()..gate = Completer<void>();
    await pumpScreen(tester, repo);

    await tester.enterText(field('Например, протекает кран'), 'Не работает свет');
    await tester.tap(find.byKey(const Key('submitRequest')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submitRequest')));
    await tester.pump();

    expect(repo.created, hasLength(1));
    repo.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('ошибка сервера показывается, форма остаётся открытой', (tester) async {
    final repo = FakeRepo()..error = Exception('user has no company');
    await pumpScreen(tester, repo);

    await tester.enterText(field('Например, протекает кран'), 'Сломан стул');
    await tester.tap(find.byKey(const Key('submitRequest')));
    await tester.pumpAndSettle();

    expect(find.text('Профиль не привязан к компании'), findsOneWidget);
    expect(find.byType(CreateRequestScreen), findsOneWidget);
  });

  testWidgets('редактирование заявки с удалённым объектом не падает', (tester) async {
    final repo = FakeRepo();
    await pumpScreen(tester, repo, existing: {
      'id': 'w1', 'title': 'Старая', 'description': null, 'work_type': 'Электрика',
      'priority': 'low', 'object_id': 'deleted-object', 'recurrence': {'kind': 'regular'},
      'due_at': null,
    });

    expect(find.text('Редактировать заявку'), findsOneWidget);
    expect(find.text('Чек-лист'), findsNothing);

    await tester.tap(find.byKey(const Key('submitRequest')));
    await tester.pumpAndSettle();

    final d = repo.updated['w1']!;
    expect(d.title, 'Старая');
    expect(d.objectId, isNull);
    expect(d.period, 'week');
    expect(d.priority, 'low');
  });
}
