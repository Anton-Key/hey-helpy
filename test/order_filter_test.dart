import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hey_helpy/features/directory/directory.dart';
import 'package:hey_helpy/features/requests/order_filter.dart';
import 'package:hey_helpy/features/requests/order_filter_bar.dart';
import 'package:hey_helpy/features/requests/work_order.dart';
import 'package:hey_helpy/l10n/app_localizations.dart';

/// «Сейчас» для всех тестов: 9 октября 2026, 12:00 (местное время).
final now = DateTime(2026, 10, 9, 12);

WorkOrder wo(
  String id, {
  String status = 'new',
  String priority = 'normal',
  String? object = 'o1',
  String? location,
  String? contractor,
  String? executor,
  String? createdBy = 'u1',
  String? layer,
  String channel = 'button',
  bool recurring = false,
  bool photo = false,
  int returns = 0,
  DateTime? created,
  DateTime? due,
}) =>
    WorkOrder(
      id: id,
      title: 'Заявка $id',
      priority: priority,
      status: status,
      objectId: object,
      locationId: location,
      contractorId: contractor,
      executorId: executor,
      createdBy: createdBy,
      layerId: layer,
      inputChannel: channel,
      recurring: recurring,
      requiresPhoto: photo,
      returnCount: returns,
      createdAt: created ?? DateTime(2026, 10, 1, 10),
      dueAt: due,
    );

List<String> ids(Iterable<WorkOrder> l) => [for (final w in l) w.id];

List<String> conds(OrderFilter f,
        {String? uid = 'u1', List<String> exec = const []}) =>
    [
      for (final c
          in f.serverConditions(now: now, uid: uid, myExecutorIds: exec))
        '$c'
    ];

String utc(DateTime d) => d.toUtc().toIso8601String();

void main() {
  group('Период', () {
    test('пресеты дают правильные границы', () {
      ({DateTime from, DateTime to}) r(PeriodPreset p) =>
          OrderFilter(period: p).range(now)!;
      expect(r(PeriodPreset.today),
          (from: DateTime(2026, 10, 9), to: DateTime(2026, 10, 10)));
      expect(r(PeriodPreset.days7),
          (from: DateTime(2026, 10, 3), to: DateTime(2026, 10, 10)));
      expect(r(PeriodPreset.days30),
          (from: DateTime(2026, 9, 10), to: DateTime(2026, 10, 10)));
      expect(r(PeriodPreset.thisMonth),
          (from: DateTime(2026, 10), to: DateTime(2026, 11)));
      expect(r(PeriodPreset.lastMonth),
          (from: DateTime(2026, 9), to: DateTime(2026, 10)));
      // январь → прошлый месяц — декабрь прошлого года
      expect(
          const OrderFilter(period: PeriodPreset.lastMonth)
              .range(DateTime(2027, 1, 5)),
          (from: DateTime(2026, 12), to: DateTime(2027, 1)));
    });

    test('«Свой период»: даты включительно, порядок не важен', () {
      final f = OrderFilter(
          period: PeriodPreset.custom,
          customFrom: DateTime(2026, 10, 5),
          customTo: DateTime(2026, 10, 1));
      expect(f.range(now),
          (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 6)));
      expect(
          f.matches(wo('a', created: DateTime(2026, 10, 5, 23, 59)), now: now),
          isTrue);
      expect(f.matches(wo('b', created: DateTime(2026, 10, 6)), now: now),
          isFalse);
      expect(f.matches(wo('c', created: DateTime(2026, 9, 30, 23)), now: now),
          isFalse);
      expect(conds(f), [
        'created_at=gte.${utc(DateTime(2026, 10, 1))}',
        'created_at=lt.${utc(DateTime(2026, 10, 6))}',
      ]);
    });

    test('«Свой период» без дат — не фильтрует', () {
      const f = OrderFilter(period: PeriodPreset.custom);
      expect(f.hasPeriod, isFalse);
      expect(f.hasFilters, isFalse);
      expect(conds(f), isEmpty);
    });

    test('по сроку: заявки без срока не попадают', () {
      const f =
          OrderFilter(period: PeriodPreset.days7, dateField: DateField.due);
      expect(f.matches(wo('a', due: DateTime(2026, 10, 8)), now: now), isTrue);
      expect(f.matches(wo('b'), now: now), isFalse);
      expect(conds(f).first, startsWith('due_at=gte.'));
    });
  });

  group('Поля фильтра', () {
    test('пустой фильтр — без условий и пропускает всё', () {
      expect(conds(OrderFilter.empty), isEmpty);
      expect(OrderFilter.empty.matches(wo('a'), now: now), isTrue);
      expect(OrderFilter.empty.hasFilters, isFalse);
    });

    test('объект и помещение (помещение — только при одном объекте)', () {
      final one = const OrderFilter()
          .copyWith(objectIds: {'o1'}, locationIds: {'l1', 'l2'});
      expect(conds(one), ['object_id=in.(o1)', 'location_id=in.(l1,l2)']);
      expect(one.matches(wo('a', location: 'l2'), now: now), isTrue);
      expect(one.matches(wo('b', location: 'l3'), now: now), isFalse);
      expect(one.matches(wo('c', object: 'o2', location: 'l1'), now: now),
          isFalse);

      final two = one.copyWith(objectIds: {'o1', 'o2'});
      expect(two.locationIds, isEmpty, reason: 'помещения сбрасываются');
      expect(conds(two), ['object_id=in.(o1,o2)']);
    });

    test('подрядчик, «Без подрядчика» и оба вместе', () {
      const only = OrderFilter(contractorIds: {'c1'});
      expect(conds(only), ['assigned_contractor_id=in.(c1)']);
      expect(only.matches(wo('a', contractor: 'c1'), now: now), isTrue);
      expect(only.matches(wo('b'), now: now), isFalse);

      const none = OrderFilter(contractorIds: {kNoContractor});
      expect(conds(none), ['assigned_contractor_id=is.null']);
      expect(none.matches(wo('a'), now: now), isTrue);
      expect(none.matches(wo('b', contractor: 'c1'), now: now), isFalse);

      const both = OrderFilter(contractorIds: {'c2', kNoContractor, 'c1'});
      expect(conds(both), [
        'or=(assigned_contractor_id.in.(c1,c2),assigned_contractor_id.is.null)'
      ]);
      expect(both.matches(wo('a'), now: now), isTrue);
      expect(both.matches(wo('b', contractor: 'c2'), now: now), isTrue);
      expect(both.matches(wo('c', contractor: 'c3'), now: now), isFalse);
    });

    test('срочность — в порядке от критической', () {
      const f = OrderFilter(priorities: {'low', 'critical'});
      expect(conds(f), ['priority=in.(critical,low)']);
      expect(f.matches(wo('a', priority: 'critical'), now: now), isTrue);
      expect(f.matches(wo('b', priority: 'high'), now: now), isFalse);
    });

    test('статус', () {
      const f = OrderFilter(statuses: {'in_progress', 'new'});
      expect(conds(f), ['status=in.(new,in_progress)']);
      expect(f.matches(wo('a', status: 'in_progress'), now: now), isTrue);
      expect(f.matches(wo('b', status: 'done'), now: now), isFalse);
    });

    test('«Просрочено» отдельно и вместе со статусами', () {
      final late = wo('late', status: 'assigned', due: DateTime(2026, 10, 8));
      final ok = wo('ok', status: 'assigned', due: DateTime(2026, 10, 10));
      final doneLate = wo('dl', status: 'done', due: DateTime(2026, 10, 1));

      const only = OrderFilter(statuses: {kOverdue});
      expect(conds(only),
          ['status=not.in.(done,cancelled)', 'due_at=lt.${utc(now)}']);
      expect(ids([late, ok, doneLate].where((w) => only.matches(w, now: now))),
          ['late']);

      const mixed = OrderFilter(statuses: {kOverdue, 'done'});
      expect(conds(mixed), [
        'or=(status.in.(done),and(status.not.in.(done,cancelled),'
            'due_at.lt."${utc(now)}"))'
      ]);
      expect(ids([late, ok, doneLate].where((w) => mixed.matches(w, now: now))),
          ['late', 'dl']);
    });

    test('вид работ', () {
      const f = OrderFilter(layerIds: {'y1'});
      expect(conds(f), ['layer_id=in.(y1)']);
      expect(f.matches(wo('a', layer: 'y1'), now: now), isTrue);
      expect(f.matches(wo('b', layer: 'y2'), now: now), isFalse);
    });

    test('«Ещё»: тип, источник, фото, возвраты, создал я', () {
      const rec = OrderFilter(recurrence: RecurrenceFilter.recurring);
      expect(conds(rec), ['recurrence=not.is.null', 'recurrence->>kind=neq.ppr']);
      expect(rec.matches(wo('a', recurring: true), now: now), isTrue);
      expect(rec.matches(wo('b'), now: now), isFalse);

      // Шаг 16: задача ППР — не «повторяющаяся», а отдельный тип «ППР».
      final pprTask = WorkOrder(
          id: 'p',
          title: 'ТО — октябрь 2026',
          priority: 'normal',
          status: 'assigned',
          recurring: true,
          recurrenceKind: 'ppr',
          planId: 'plan1');
      expect(rec.matches(pprTask, now: now), isFalse);
      const ppr = OrderFilter(recurrence: RecurrenceFilter.ppr);
      expect(conds(ppr), ['recurrence->>kind=eq.ppr']);
      expect(ppr.matches(pprTask, now: now), isTrue);
      expect(ppr.matches(wo('a', recurring: true), now: now), isFalse);

      const once = OrderFilter(recurrence: RecurrenceFilter.once);
      expect(conds(once), ['recurrence=is.null']);
      expect(once.matches(wo('a', recurring: true), now: now), isFalse);

      const src = OrderFilter(channels: {'text', 'voice'});
      expect(conds(src), ['input_channel=in.(voice,text)']);
      expect(src.matches(wo('a', channel: 'voice'), now: now), isTrue);
      expect(src.matches(wo('b', channel: 'button'), now: now), isFalse);

      const photo = OrderFilter(needsPhoto: true);
      expect(conds(photo), ['requires_photo=is.true']);
      expect(photo.matches(wo('a', photo: true), now: now), isTrue);
      expect(photo.matches(wo('b'), now: now), isFalse);

      const ret = OrderFilter(returned: true);
      expect(conds(ret), ['return_count=gt.0']);
      expect(ret.matches(wo('a', returns: 2), now: now), isTrue);
      expect(ret.matches(wo('b'), now: now), isFalse);

      const mine = OrderFilter(createdByMe: true);
      expect(conds(mine, uid: 'u7'), ['created_by=eq.u7']);
      expect(
          mine.matches(wo('a', createdBy: 'u7'), now: now, uid: 'u7'), isTrue);
      expect(mine.matches(wo('b'), now: now, uid: 'u7'), isFalse);
      expect(mine.moreCount, 1);
    });

    test('«Назначено мне»: мне лично или без исполнителя, но не коллеге', () {
      const f = OrderFilter(assignedToMe: true);
      expect(conds(f, exec: ['e1']),
          ['or=(assigned_executor_id.in.(e1),assigned_executor_id.is.null)']);
      bool m(String? e) =>
          f.matches(wo('x', executor: e), now: now, myExecutorIds: ['e1']);
      expect(m('e1'), isTrue);
      expect(m(null), isTrue);
      expect(m('e2'), isFalse);
    });

    test('несколько групп «или» — одним параметром через and()', () {
      const f = OrderFilter(
          contractorIds: {'c1', kNoContractor}, statuses: {'new', kOverdue});
      final c = conds(f);
      expect(c.where((x) => x.startsWith('or=')).length, 1);
      expect(
          c.last,
          'or=(and(or(assigned_contractor_id.in.(c1),assigned_contractor_id.is.null),'
          'or(status.in.(new),and(status.not.in.(done,cancelled),'
          'due_at.lt."${utc(now)}"))))');
    });

    test('все поля вместе: условия сервера и проверка в памяти согласны', () {
      const f = OrderFilter(
        period: PeriodPreset.days30,
        objectIds: {'o1'},
        locationIds: {'l1'},
        contractorIds: {'c1'},
        priorities: {'critical'},
        statuses: {kOverdue},
        layerIds: {'y1'},
        channels: {'voice'},
        recurrence: RecurrenceFilter.once,
        needsPhoto: true,
        returned: true,
        createdByMe: true,
      );
      expect(conds(f), hasLength(14));
      final hit = wo('hit',
          status: 'in_progress',
          priority: 'critical',
          location: 'l1',
          contractor: 'c1',
          layer: 'y1',
          channel: 'voice',
          photo: true,
          returns: 1,
          created: DateTime(2026, 10, 2),
          due: DateTime(2026, 10, 3));
      expect(f.matches(hit, now: now, uid: 'u1'), isTrue);
      // Любое одно несовпадение — мимо.
      for (final miss in [
        wo('1',
            status: 'in_progress',
            priority: 'high',
            location: 'l1',
            contractor: 'c1',
            layer: 'y1',
            channel: 'voice',
            photo: true,
            returns: 1,
            due: DateTime(2026, 10, 3)),
        wo('2',
            status: 'in_progress',
            priority: 'critical',
            location: 'l2',
            contractor: 'c1',
            layer: 'y1',
            channel: 'voice',
            photo: true,
            returns: 1,
            due: DateTime(2026, 10, 3)),
        wo('3',
            status: 'in_progress',
            priority: 'critical',
            location: 'l1',
            contractor: 'c1',
            layer: 'y1',
            channel: 'text',
            photo: true,
            returns: 1,
            due: DateTime(2026, 10, 3)),
        wo('4',
            status: 'in_progress',
            priority: 'critical',
            location: 'l1',
            contractor: 'c1',
            layer: 'y1',
            channel: 'voice',
            photo: true,
            returns: 0,
            due: DateTime(2026, 10, 3)),
        wo('5',
            status: 'in_progress',
            priority: 'critical',
            location: 'l1',
            contractor: 'c1',
            layer: 'y1',
            channel: 'voice',
            photo: true,
            returns: 1,
            due: DateTime(2026, 10, 30)),
        wo('6',
            status: 'in_progress',
            priority: 'critical',
            location: 'l1',
            contractor: 'c1',
            layer: 'y1',
            channel: 'voice',
            photo: true,
            returns: 1,
            recurring: true,
            due: DateTime(2026, 10, 3)),
      ]) {
        expect(f.matches(miss, now: now, uid: 'u1'), isFalse, reason: miss.id);
      }
    });
  });

  group('Сортировка', () {
    final a = wo('a',
        priority: 'low',
        status: 'done',
        object: 'o2',
        created: DateTime(2026, 10, 9, 9),
        due: DateTime(2026, 10, 20));
    final b = wo('b',
        priority: 'critical',
        status: 'assigned',
        object: 'o1',
        created: DateTime(2026, 10, 1),
        due: DateTime(2026, 10, 5)); // просрочена
    final c = wo('c',
        priority: 'high',
        status: 'new',
        object: null,
        created: DateTime(2026, 10, 5));
    final d = wo('d',
        priority: 'critical',
        status: 'on_review',
        object: 'o1',
        created: DateTime(2026, 10, 7),
        due: DateTime(2026, 10, 12));
    final all = [a, b, c, d];
    String name(String? id) =>
        switch (id) { 'o1' => 'Ядро', 'o2' => 'Альфа', _ => '' };
    List<String> s(OrderSort sort) =>
        ids(sortOrders(all, sort, now: now, objectName: name));

    test('сначала новые / старые', () {
      expect(s(OrderSort.newest), ['a', 'd', 'c', 'b']);
      expect(s(OrderSort.oldest), ['b', 'c', 'd', 'a']);
    });
    test('по сроку: ближайший сверху, без срока — в конце', () {
      expect(s(OrderSort.due), ['b', 'd', 'a', 'c']);
    });
    test('по срочности: critical → low, внутри — новые сверху', () {
      expect(s(OrderSort.priority), ['d', 'b', 'c', 'a']);
    });
    test('по статусу: просрочено → новая → … → принята', () {
      expect(s(OrderSort.status), ['b', 'c', 'd', 'a']);
    });
    test('по объекту: А–Я, без объекта — в конце', () {
      expect(s(OrderSort.object), ['a', 'd', 'b', 'c']);
    });

    test('группы: сегодня / ранее и по статусу', () {
      final byDate = groupOrders(
          sortOrders(all, OrderSort.newest, now: now), OrderSort.newest,
          now: now);
      expect([for (final g in byDate) g.key], ['today', 'earlier']);
      expect(ids(byDate.first.items), ['a']);

      final byStatus = groupOrders(
          sortOrders(all, OrderSort.status, now: now), OrderSort.status,
          now: now);
      expect([for (final g in byStatus) g.key],
          [kOverdue, 'new', 'on_review', 'done']);

      final byDue = groupOrders(
          sortOrders(all, OrderSort.due, now: now), OrderSort.due,
          now: now);
      expect(byDue, hasLength(1));
    });
  });

  group('Сегменты и поиск', () {
    final items = [
      wo('a', status: 'new', priority: 'critical', due: DateTime(2026, 10, 1)),
      wo('b', status: 'done', priority: 'critical'),
      wo('c', status: 'assigned', priority: 'low'),
      wo('d', status: 'in_progress', priority: 'critical'),
    ];

    test('счётчики сегментов учитывают остальные фильтры', () {
      const f = OrderFilter(priorities: {'critical'});
      final v = buildOrderList(items, f, now: now);
      expect((v.all, v.open, v.overdue), (3, 2, 1));
      expect(ids(v.items), ['a', 'b', 'd']..sort());
    });

    test('сегмент «Просрочено» поверх фильтра', () {
      const f =
          OrderFilter(priorities: {'critical'}, segment: OrderSegment.overdue);
      final v = buildOrderList(items, f, now: now);
      expect(ids(v.items), ['a']);
      expect(v.all, 3);
    });

    test('сегмент «Открытые» + поиск', () {
      const f = OrderFilter(segment: OrderSegment.open);
      final v = buildOrderList(items, f, now: now, search: (w) => w.id != 'd');
      expect(ids(v.items)..sort(), ['a', 'c']);
      expect((v.all, v.open), (3, 2));
    });
  });

  group('Сохранение', () {
    test('в адрес и обратно — без потерь', () {
      final f = OrderFilter(
        period: PeriodPreset.custom,
        dateField: DateField.due,
        customFrom: DateTime(2026, 9, 1),
        customTo: DateTime(2026, 9, 30),
        objectIds: const {'o1'},
        locationIds: const {'l1'},
        contractorIds: const {'c1', kNoContractor},
        priorities: const {'critical', 'high'},
        statuses: const {kOverdue, 'new'},
        layerIds: const {'y1'},
        channels: const {'voice'},
        recurrence: RecurrenceFilter.recurring,
        needsPhoto: true,
        returned: true,
        createdByMe: true,
        assignedToMe: true,
        sort: OrderSort.due,
        segment: OrderSegment.open,
      );
      expect(OrderFilter.fromQuery(f.toQuery()), f);
      expect(OrderFilter.deserialize(f.serialize()), f);
      expect(f.toQuery()['period'], 'custom');
      expect(f.toQuery()['from'], '2026-09-01');
    });

    test('пустой фильтр — пустой адрес; мусор не ломает разбор', () {
      expect(OrderFilter.empty.toQuery(), isEmpty);
      final f = OrderFilter.fromQuery(const {
        'pri': 'critical,urgent',
        'sort': 'nonsense',
        'st': 'new,bad',
        'from': '2026-13-99',
        'invite': 'abc',
      });
      expect(f.priorities, {'critical'});
      expect(f.statuses, {'new'});
      expect(f.sort, OrderSort.newest);
      expect(OrderFilter.deserialize('%%%'), OrderFilter.empty);
    });

    test('«Сбросить всё» оставляет сортировку', () {
      const f = OrderFilter(
          priorities: {'high'},
          sort: OrderSort.priority,
          segment: OrderSegment.open);
      expect(f.cleared(), const OrderFilter(sort: OrderSort.priority));
    });
  });

  group('Подписи таблеток', () {
    setUpAll(() => initializeDateFormatting('ru'));
    final l = lookupAppLocalizations(const Locale('ru'));
    final lb = OrderFilterLabels(l);

    test('один выбранный — название, несколько — «+N»', () {
      const opts = [
        FilterOption('o1', 'БЦ «Демо»'),
        FilterOption('o2', 'ТЦ «Демо Плаза»'),
      ];
      expect(lb.multi(const {}, opts), isNull);
      expect(lb.multi(const {'o2'}, opts), 'ТЦ «Демо Плаза»');
      expect(lb.multi(const {'o2', 'o1'}, opts), 'БЦ «Демо» +1');
    });

    test('период, срок, «Ещё»', () {
      expect(lb.period(OrderFilter.empty, now), isNull);
      expect(lb.period(const OrderFilter(period: PeriodPreset.days7), now),
          '7 дней');
      expect(
          lb.period(
              const OrderFilter(
                  period: PeriodPreset.today, dateField: DateField.due),
              now),
          'Срок: Сегодня');
      expect(
          lb.period(
              OrderFilter(
                  period: PeriodPreset.custom,
                  customFrom: DateTime(2026, 10, 1),
                  customTo: DateTime(2026, 10, 9)),
              now),
          contains('–'));
      expect(lb.more(const OrderFilter(recurrence: RecurrenceFilter.recurring)),
          'Повторяющаяся');
      expect(lb.more(const OrderFilter(needsPhoto: true, returned: true)),
          'Ещё · 2');
    });

    test('статусы: «Просрочено» первым пунктом, затем по порядку', () {
      expect([for (final o in lb.statusOptions()) o.id], kStatusOrder);
      expect(lb.statusOptions().first.label, 'Просрочено');
      expect(lb.contractorOptions(const []).single.id, kNoContractor);
    });
  });

  group('Компактные фильтры (шаг 13e)', () {
    setUpAll(() => initializeDateFormatting('ru'));
    final l = lookupAppLocalizations(const Locale('ru'));
    final lb = OrderFilterLabels(l);
    final moscow = [
      for (var i = 1; i <= 5; i++)
        Obj(
            id: 'm$i',
            name: 'Офис $i',
            address: 'Москва, ул. $i',
            type: 'office'),
    ];
    final choices = FilterChoices(
        objects: moscow,
        contractors: const [FilterOption('c1', 'МосКлимат')],
        layers: const [],
        isExecutor: false);

    test('число активных фильтров: одна единица на фильтр', () {
      expect(OrderFilter.empty.activeCount, 0);
      // Сортировка и сегмент — не фильтры.
      expect(
          const OrderFilter(
                  sort: OrderSort.priority, segment: OrderSegment.overdue)
              .activeCount,
          0);
      const f = OrderFilter(
        period: PeriodPreset.days30,
        statuses: {'new', kOverdue},
        objectIds: {'m1', 'm2'},
        channels: {'voice', 'text'},
        needsPhoto: true,
      );
      expect(f.activeCount, 5);
      expect(f.activeKeys, [
        FilterKey.period,
        FilterKey.status,
        FilterKey.object,
        FilterKey.channel,
        FilterKey.photo,
      ]);
      // «Свой период» без дат и помещения без одного объекта — не считаются.
      expect(const OrderFilter(period: PeriodPreset.custom).activeCount, 0);
      expect(
          const OrderFilter(objectIds: {'a', 'b'}, locationIds: {'x'})
              .activeCount,
          1);
    });

    test('таблетки применённых фильтров: «Москва (5)», «Просрочено», «30 дней»',
        () {
      final f = OrderFilter(
          objectIds: {for (final o in moscow) o.id},
          statuses: const {kOverdue},
          period: PeriodPreset.days30);
      final chips = lb.applied(f, choices, now);
      expect(chips, [
        (FilterKey.period, '30 дней'),
        (FilterKey.status, 'Просрочено'),
        (FilterKey.object, 'Москва (5)'),
      ]);
      // На ПК главные фильтры стоят рядом с поиском — в строке их нет.
      expect(
          lb.applied(f, choices, now, skip: kMainFilterKeys.toSet()), isEmpty);
      expect(lb.applied(const OrderFilter(returned: true), choices, now),
          [(FilterKey.returned, 'Возвращались на доработку')]);
    });

    test('снятие одного фильтра не трогает остальные и сортировку', () {
      const f = OrderFilter(
        period: PeriodPreset.days7,
        dateField: DateField.due,
        statuses: {'new'},
        contractorIds: {'c1'},
        recurrence: RecurrenceFilter.recurring,
        sort: OrderSort.due,
        segment: OrderSegment.open,
      );
      final a = f.without(FilterKey.period);
      expect(a.hasPeriod, isFalse);
      expect(a.dateField, DateField.created);
      expect(a.statuses, {'new'});
      expect(a.sort, OrderSort.due);
      expect(a.segment, OrderSegment.open);
      expect(f.without(FilterKey.recurrence).recurrence, isNull);
      expect(f.without(FilterKey.contractor).activeKeys,
          [FilterKey.period, FilterKey.status, FilterKey.recurrence]);
      for (final k in FilterKey.values) {
        // Снятие невыбранного фильтра ничего не меняет.
        expect(OrderFilter.empty.without(k), OrderFilter.empty);
      }
    });

    test('адрес: старые ссылки шага 13c открываются как раньше', () {
      // Ссылка из 13c (формат не менялся): объект, статусы, «Ещё», сортировка.
      final f = OrderFilter.fromQuery(Uri.splitQueryString(
          'period=30d&obj=o1&loc=r1&st=new,overdue&rec=recurring&src=voice'
          '&photo=1&sort=priority&seg=open'));
      expect(f.activeKeys, [
        FilterKey.period,
        FilterKey.status,
        FilterKey.object,
        FilterKey.room,
        FilterKey.recurrence,
        FilterKey.channel,
        FilterKey.photo,
      ]);
      expect(f.sort, OrderSort.priority);
      expect(f.segment, OrderSegment.open);
      // Туда и обратно — без потерь.
      expect(OrderFilter.fromQuery(f.toQuery()), f);
    });

    test('количество для «Показать N»: условия сегмента', () {
      expect(OrderFilter.empty.segmentConditions(now), isEmpty);
      expect([
        for (final c in const OrderFilter(segment: OrderSegment.overdue)
            .segmentConditions(now))
          '$c'
      ], [
        'status=not.in.(done,cancelled)',
        'due_at=lt.${utc(now)}'
      ]);
    });
  });
}
