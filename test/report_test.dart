import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/reports/report_repository.dart';

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
    expect(c.onTimeShare, 0.5);
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
    expect(a.stats.visitNorm, 6); // 31 день ≈ месяц: 4 + 2
    final onX = build(objectId: 'X')
        .contractors
        .firstWhere((c) => c.contractorId == 'a');
    expect(onX.stats.visitNorm, 2);
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
}
