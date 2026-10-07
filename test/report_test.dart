import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/core/period.dart';
import 'package:hey_helpy/features/reports/report_repository.dart';
import 'package:hey_helpy/features/reports/reports_screen.dart';

void main() {
  final from = DateTime.utc(2026, 10, 1);
  final to = DateTime.utc(2026, 11, 1);
  final now = DateTime.utc(2026, 10, 20);
  DateTime d(int day, [int hour = 0]) => DateTime.utc(2026, 10, day, hour);

  final orders = [
    // принята в срок с первого раза, есть фото «до» и «после»
    ReportOrder(
        id: '1',
        status: 'done',
        contractorId: 'a',
        createdAt: d(1, 8),
        startedAt: d(1, 9),
        submittedAt: d(1, 11),
        acceptedAt: d(2),
        dueAt: d(3),
        hasBeforePhoto: true,
        hasAfterPhoto: true),
    // принята после возврата и позже дедлайна
    ReportOrder(
        id: '2',
        status: 'done',
        contractorId: 'a',
        createdAt: d(2),
        startedAt: d(2, 3),
        submittedAt: d(2, 4),
        acceptedAt: d(6),
        dueAt: d(5),
        returnCount: 1,
        hasAfterPhoto: true),
    // в работе, дедлайн прошёл
    ReportOrder(
        id: '3',
        status: 'in_progress',
        contractorId: 'b',
        createdAt: d(3),
        dueAt: d(10)),
    // отменена с прошедшим дедлайном — не просрочка
    ReportOrder(id: '4', status: 'cancelled', createdAt: d(4), dueAt: d(5)),
  ];
  final visits = [
    ReportVisit(
        contractorId: 'a',
        startedAt: d(1, 9),
        endedAt: d(1, 11),
        inGeofence: true),
    ReportVisit(
        contractorId: 'a',
        startedAt: d(2, 3),
        endedAt: d(2, 4),
        inGeofence: true,
        mockLocation: true),
    ReportVisit(contractorId: 'b', startedAt: d(3), inGeofence: false),
  ];

  Report build({String? objectId}) => Report.build(
        query: ReportQuery(from: from, to: to, objectId: objectId),
        orders: orders,
        visits: visits,
        norms: const [
          VisitNorm(contractorId: 'a', layerId: 'L', visitsPerMonth: 4),
          VisitNorm(
              contractorId: 'a',
              layerId: 'L',
              objectId: 'X',
              visitsPerMonth: 2),
        ],
        contractorOrder: const ['b', 'a'],
        now: now,
      );

  test('показатели компании', () {
    final c = build().company;
    expect(c.total, 4);
    expect(c.accepted, 2);
    expect(c.returned, 1);
    expect(c.overdue, 2); // №2 принята поздно, №3 не сделана к сроку
    // с дедлайном: №1 в срок, №2 принята поздно, №3 не закрыта к сроку; №4 отменена
    expect(c.onTimeShare, closeTo(1 / 3, 1e-9));
    expect(c.firstPassShare, 0.5);
    expect(c.avgReaction, const Duration(minutes: 120)); // (1 ч + 3 ч) / 2
    expect(c.avgExecution, const Duration(minutes: 90)); // (2 ч + 1 ч) / 2
    expect(c.visits, 3);
    expect(c.visitsInGeofence, 1); // с подменой GPS не считается
    expect(c.visitsSuspicious, 2);
    expect(c.onSite, const Duration(hours: 3)); // открытый визит не считается
    expect(c.photoShare, 0.5);
  });

  test('подрядчики по порядку справочника, «без подрядчика» в конце', () {
    final r = build();
    expect([for (final c in r.contractors) c.contractorId], ['b', 'a', null]);
    expect(r.contractors[1].orders.map((o) => o.id), ['2', '1']);
  });

  test('норма визитов пересчитывается на период и учитывает фильтр объекта',
      () {
    final a = build().contractors.firstWhere((c) => c.contractorId == 'a');
    expect(a.stats.visitNorm, closeTo(6.11, 0.01)); // 31 день ≈ месяц: 4 + 2
    final onX = build(objectId: 'X')
        .contractors
        .firstWhere((c) => c.contractorId == 'a');
    expect(onX.stats.visitNorm, closeTo(2.04, 0.01));
  });

  test('возврат до миграции 0010 — по причине возврата', () {
    final old = ReportOrder.fromMap({
      'id': '9',
      'status': 'done',
      'created_at': '2026-10-01T00:00:00Z',
      'return_reason': 'Протекает',
    });
    expect(old.returnCount, 1);
    final fresh = ReportOrder.fromMap({
      'id': '9',
      'status': 'done',
      'created_at': '2026-10-01T00:00:00Z',
      'return_reason': 'Протекает',
      'return_count': 2,
    });
    expect(fresh.returnCount, 2);
  });

  test('норма за неделю не округляется до нуля', () {
    final r = Report.build(
      query: ReportQuery(from: d(5), to: d(12)),
      orders: const [],
      visits: const [],
      norms: const [
        VisitNorm(contractorId: 'e', layerId: 'L', visitsPerMonth: 2),
      ],
      contractorOrder: const [],
      now: now,
    );
    expect(r.contractors.single.stats.visitNorm, closeTo(0.46, 0.01));
  });

  test('границы периода: неделя с понедельника, 30 дней, месяц, свой диапазон',
      () {
    final wed = DateTime(2026, 10, 7, 15); // среда
    final week = const Period(PeriodKind.week).range(wed);
    expect(week.from, DateTime(2026, 10, 5));
    expect(week.to, DateTime(2026, 10, 12));
    final last30 = const Period(PeriodKind.last30).range(wed);
    expect(
        last30.from, DateTime(2026, 9, 8)); // 30 дней по сегодня включительно
    expect(last30.to, DateTime(2026, 10, 8));
    final month = const Period(PeriodKind.month).range(wed);
    expect(month.from, DateTime(2026, 10));
    expect(month.to, DateTime(2026, 11));
    final custom = Period(
            PeriodKind.custom,
            DateTimeRange(
                start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 3)))
        .range(wed);
    expect(custom.from, DateTime(2026, 9, 1));
    expect(custom.to, DateTime(2026, 9, 4)); // последний день включительно
  });

  test('«В срок» — среди всех заявок с дедлайном (как у «ЭлектроПро»)', () {
    final late = [
      // 6 приняты до дедлайна
      for (var i = 0; i < 6; i++)
        ReportOrder(
            id: 'ok$i',
            status: 'done',
            createdAt: d(1),
            acceptedAt: d(2),
            dueAt: d(3)),
      // 2 не закрыты, дедлайн прошёл
      ReportOrder(id: 'r', status: 'returned', createdAt: d(1), dueAt: d(5)),
      ReportOrder(id: 'a', status: 'assigned', createdAt: d(1), dueAt: d(6)),
      // не закрыта, но дедлайн впереди — пока не считается
      ReportOrder(
          id: 'p', status: 'in_progress', createdAt: d(1), dueAt: d(25)),
      // отменена — не считается
      ReportOrder(id: 'c', status: 'cancelled', createdAt: d(1), dueAt: d(2)),
    ];
    final s = ReportStats();
    for (final o in late) {
      s.addOrder(o, now);
    }
    expect(s.withDue, 8);
    expect(s.onTime, 6);
    expect(s.onTimeShare, 0.75);
    expect(s.overdue, 2);
  });

  test('норма визитов: от 1 — целым, меньше 1 — с одним знаком', () {
    expect(formatVisitNorm(3.94, 'ru'), '4');
    expect(formatVisitNorm(1.97, 'en'), '2');
    expect(formatVisitNorm(0.46, 'ru'), '0,5');
    expect(formatVisitNorm(0.46, 'en'), '0.5');
    expect(formatVisitNorm(0.01, 'ru'), isNull);
  });

  test('недобор визитов — по округлённой норме', () {
    expect(visitsBelowNorm(4, 4.07), isFalse);
    expect(visitsBelowNorm(1, 1.97), isTrue);
    expect(visitsBelowNorm(0, 0.46), isTrue);
    expect(visitsBelowNorm(1, 0.46), isFalse);
  });
}
