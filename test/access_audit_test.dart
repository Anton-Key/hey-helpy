import 'package:flutter_test/flutter_test.dart';
import 'package:hey_helpy/features/access/audit_logic.dart';
import 'package:hey_helpy/features/access/zone_logic.dart';

AuditEntry e(String action, String entity, int sec,
        {String actor = 'admin',
        String? target = 'm2',
        Map<String, dynamic> d = const {}}) =>
    AuditEntry(
        id: '$entity-$action-$sec',
        action: action,
        entity: entity,
        at: DateTime(2026, 10, 11, 3, 0, sec),
        actorId: actor,
        targetId: target,
        details: d);

void main() {
  group('Журнал доступа (шаг 18)', () {
    test('сохранение зоны (удалено + вставлено в одну секунду) — одно действие',
        () {
      final items = groupAudit([
        e('insert', 'access_zones', 10,
            d: {'scope_kind': 'city', 'scope_ref': 'Москва', 'layer_ids': ['hvac']}),
        e('delete', 'access_zones', 10, d: {'scope_kind': 'company'}),
        e('role', 'profiles', 5, d: {'from': 'requester', 'to': 'manager'}),
      ]);
      expect(items.length, 2);
      final z = items.first;
      expect(z.kind, AuditKind.zone);
      expect(z.added.single.place, const ZonePlace(ZoneScope.city, 'Москва'));
      expect(z.added.single.layerIds, {'hvac'});
      expect(z.removed.single.place, const ZonePlace.company());
      expect(items.last.kind, AuditKind.role);
      expect(items.last.from, 'requester');
      expect(items.last.to, 'manager');
    });

    test('разные сотрудники или далеко по времени — отдельные действия', () {
      final items = groupAudit([
        e('insert', 'access_zones', 30, d: {'scope_kind': 'company'}),
        e('insert', 'access_zones', 30,
            target: 'm3', d: {'scope_kind': 'company'}),
        e('insert', 'access_zones', 10, d: {'scope_kind': 'company'}),
      ]);
      expect(items.length, 3);
    });

    test('бригады: создана, переименована, состав, зона', () {
      final items = groupAudit([
        e('insert', 'crew_members', 20, target: 'c1', d: {'executor_id': 'x'}),
        e('insert', 'crew_members', 20, target: 'c1', d: {'executor_id': 'y'}),
        e('delete', 'crew_members', 20, target: 'c1', d: {'executor_id': 'z'}),
        e('update', 'crews', 15, target: 'c1', d: {
          'old': {'name': 'Пекин'},
          'new': {'name': 'Пекин-1'}
        }),
        e('insert', 'crews', 10, target: 'c1', d: {'name': 'Пекин'}),
      ]);
      expect(items.map((i) => i.kind), [
        AuditKind.crewMembers,
        AuditKind.crewRenamed,
        AuditKind.crewCreated,
      ]);
      expect(items[0].membersAdded, 2);
      expect(items[0].membersRemoved, 1);
      expect(items[1].from, 'Пекин');
      expect(items[1].to, 'Пекин-1');
    });

    test('фильтр по сотруднику: автор или тот, кому меняли', () {
      final items = groupAudit([
        e('role', 'profiles', 5, target: 'm2', d: {'from': 'manager', 'to': 'admin'}),
        e('insert', 'crews', 3, actor: 'm9', target: 'c1', d: {'name': 'A'}),
      ]);
      expect(items.where((i) => i.involves('m2')).length, 1);
      expect(items.where((i) => i.involves('m9')).length, 1);
      expect(auditPeople(items), {'admin', 'm2', 'm9'});
    });
  });
}
