import 'zone_logic.dart';

/// Строка журнала access_audit (0016): кто, когда, что изменил в доступе.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    required this.at,
    this.actorId,
    this.targetId,
    this.details = const {},
  });

  final String id;

  /// insert / update / delete / role.
  final String action;

  /// access_zones / crews / crew_members / crew_zones / profiles.
  final String entity;
  final DateTime at;
  final String? actorId;

  /// Сотрудник (зоны, роль) или бригада (бригады, состав, зона бригады).
  final String? targetId;
  final Map<String, dynamic> details;

  static AuditEntry fromMap(Map<String, dynamic> m) => AuditEntry(
        id: m['id'] as String,
        action: m['action'] as String? ?? '',
        entity: m['entity'] as String? ?? '',
        at: DateTime.parse(m['created_at'] as String).toLocal(),
        actorId: m['actor'] as String?,
        targetId: m['target'] as String?,
        details: (m['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

enum AuditKind {
  role,
  zone,
  crewCreated,
  crewRenamed,
  crewDeleted,
  crewMembers,
  crewZone,
  other
}

/// Одно действие администратора: сохранение зоны — это несколько строк
/// журнала (старые правила удалены, новые вставлены) в одну секунду.
class AuditItem {
  AuditItem({
    required this.kind,
    required this.at,
    this.actorId,
    this.targetId,
    this.entity = '',
    this.from,
    this.to,
    List<ZoneRow>? added,
    List<ZoneRow>? removed,
    this.membersAdded = 0,
    this.membersRemoved = 0,
  })  : added = added ?? [],
        removed = removed ?? [];

  final AuditKind kind;
  final DateTime at;
  final String? actorId;
  final String? targetId;
  final String entity;

  /// Роль: было / стало; бригада: старое / новое название (или название).
  final String? from;
  final String? to;
  final List<ZoneRow> added;
  final List<ZoneRow> removed;
  int membersAdded;
  int membersRemoved;

  /// Сотрудники, к которым относится действие (для фильтра).
  bool involves(String personId) => actorId == personId || targetId == personId;
}

Map<String, dynamic> _row(AuditEntry e) {
  if (e.action == 'update') {
    return (e.details['new'] as Map?)?.cast<String, dynamic>() ?? const {};
  }
  return e.details;
}

/// Строки журнала (новые сверху) → действия. Строки одной сущности, одного
/// автора и одной цели с разницей не больше [window] — одно действие.
List<AuditItem> groupAudit(List<AuditEntry> entries,
    {Duration window = const Duration(seconds: 2)}) {
  final out = <AuditItem>[];
  AuditItem? open;
  for (final e in entries) {
    final family = e.entity;
    final groupable = family == 'access_zones' ||
        family == 'crew_zones' ||
        family == 'crew_members';
    if (groupable &&
        open != null &&
        open.entity == family &&
        open.actorId == e.actorId &&
        open.targetId == e.targetId &&
        open.at.difference(e.at).abs() <= window) {
      _addTo(open, e);
      continue;
    }
    final item = _start(e);
    out.add(item);
    open = groupable ? item : null;
  }
  return out;
}

AuditItem _start(AuditEntry e) {
  final row = _row(e);
  switch (e.entity) {
    case 'profiles':
      return AuditItem(
          kind: AuditKind.role,
          at: e.at,
          actorId: e.actorId,
          targetId: e.targetId,
          entity: e.entity,
          from: e.details['from'] as String?,
          to: e.details['to'] as String?);
    case 'crews':
      final name = row['name'] as String?;
      if (e.action == 'insert') {
        return AuditItem(
            kind: AuditKind.crewCreated,
            at: e.at,
            actorId: e.actorId,
            targetId: e.targetId,
            entity: e.entity,
            to: name);
      }
      if (e.action == 'delete') {
        return AuditItem(
            kind: AuditKind.crewDeleted,
            at: e.at,
            actorId: e.actorId,
            targetId: e.targetId,
            entity: e.entity,
            from: name);
      }
      final old = (e.details['old'] as Map?)?['name'] as String?;
      return AuditItem(
          kind: AuditKind.crewRenamed,
          at: e.at,
          actorId: e.actorId,
          targetId: e.targetId,
          entity: e.entity,
          from: old,
          to: name);
    case 'access_zones':
    case 'crew_zones':
    case 'crew_members':
      final item = AuditItem(
          kind: e.entity == 'access_zones'
              ? AuditKind.zone
              : (e.entity == 'crew_zones'
                  ? AuditKind.crewZone
                  : AuditKind.crewMembers),
          at: e.at,
          actorId: e.actorId,
          targetId: e.targetId,
          entity: e.entity);
      _addTo(item, e);
      return item;
    default:
      return AuditItem(
          kind: AuditKind.other,
          at: e.at,
          actorId: e.actorId,
          targetId: e.targetId,
          entity: e.entity);
  }
}

void _addTo(AuditItem item, AuditEntry e) {
  if (e.entity == 'crew_members') {
    if (e.action == 'insert') item.membersAdded++;
    if (e.action == 'delete') item.membersRemoved++;
    return;
  }
  if (e.action == 'update') {
    final o = ZoneRow.fromMap(
        (e.details['old'] as Map?)?.cast<String, dynamic>() ?? const {});
    final n = ZoneRow.fromMap(_row(e));
    if (o != null) item.removed.add(o);
    if (n != null) item.added.add(n);
    return;
  }
  final z = ZoneRow.fromMap(e.details);
  if (z == null) return;
  (e.action == 'delete' ? item.removed : item.added).add(z);
}

/// Сотрудники журнала (авторы и цели-сотрудники) — для фильтра.
Set<String> auditPeople(List<AuditItem> items) => {
      for (final i in items) ...[
        if (i.actorId != null) i.actorId!,
        if (i.targetId != null &&
            (i.kind == AuditKind.role || i.kind == AuditKind.zone))
          i.targetId!,
      ]
    };
