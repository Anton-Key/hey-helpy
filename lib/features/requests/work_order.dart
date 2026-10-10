/// Заявка в списке «Заявки»: только поля, нужные строке, фильтрам и сортировке.
class WorkOrder {
  final String id;
  final String title;
  final String? workType;
  final String? layerId;
  final String priority;
  final String status;
  final String? objectId;
  final bool recurring;

  /// Срок (due_at) и дата создания — для фильтра «Просрочено» и групп
  /// «Сегодня / Ранее»; помещение — для подписи строки.
  final DateTime? dueAt;
  final DateTime? createdAt;
  final String? placeName;

  /// Этаж помещения (планы этажей, 0013): название и номер.
  final String? floorName;
  final int? floorLevel;

  /// Поля для фильтров списка (шаг 13c).
  final String? locationId;
  final String? contractorId;
  final String? executorId;
  final String? createdBy;
  final String? inputChannel;
  final bool requiresPhoto;
  final int returnCount;

  /// ППР (0015): вид повторения (recurrence.kind: 'regular' / 'ppr'),
  /// план и границы периода ('2026-10-01'). До 0015 — null.
  final String? recurrenceKind;
  final Object? recurrence;
  final String? planId;
  final String? periodStart;
  final String? periodEnd;

  WorkOrder(
      {required this.id,
      required this.title,
      this.workType,
      this.layerId,
      required this.priority,
      required this.status,
      this.objectId,
      required this.recurring,
      this.dueAt,
      this.createdAt,
      this.placeName,
      this.floorName,
      this.floorLevel,
      this.locationId,
      this.contractorId,
      this.executorId,
      this.createdBy,
      this.inputChannel,
      this.requiresPhoto = false,
      this.returnCount = 0,
      this.recurrenceKind,
      this.recurrence,
      this.planId,
      this.periodStart,
      this.periodEnd});

  /// Задача периода ППР.
  bool get isPpr => planId != null || recurrenceKind == 'ppr';

  /// Колонки для [WorkOrder.fromMap] в запросе списка.
  static const listColumns =
      'id,title,work_type,layer_id,priority,status,recurrence,object_id,'
      'location_id,assigned_contractor_id,assigned_executor_id,created_by,'
      'input_channel,requires_photo,return_count,due_at,created_at,'
      'locations(name,floors(name,level))';

  /// То же + поля ППР (нужна миграция 0015).
  static const listColumns0015 =
      '$listColumns,plan_id,period_start,period_end';

  factory WorkOrder.fromMap(Map<String, dynamic> m) {
    return WorkOrder(
      id: m['id'] as String,
      title: (m['title'] ?? '') as String,
      workType: m['work_type'] as String?,
      layerId: m['layer_id'] as String?,
      priority: (m['priority'] ?? 'normal') as String,
      status: (m['status'] ?? 'new') as String,
      objectId: m['object_id'] as String?,
      recurring: m['recurrence'] != null,
      dueAt: DateTime.tryParse('${m['due_at'] ?? ''}')?.toLocal(),
      createdAt: DateTime.tryParse('${m['created_at'] ?? ''}')?.toLocal(),
      placeName: (m['locations'] as Map<String, dynamic>?)?['name'] as String?,
      floorName: _floor(m)?['name'] as String?,
      floorLevel: (_floor(m)?['level'] as num?)?.toInt(),
      locationId: m['location_id'] as String?,
      contractorId: m['assigned_contractor_id'] as String?,
      executorId: m['assigned_executor_id'] as String?,
      createdBy: m['created_by'] as String?,
      inputChannel: m['input_channel'] as String?,
      requiresPhoto: m['requires_photo'] == true,
      returnCount: (m['return_count'] as num?)?.toInt() ?? 0,
      recurrence: m['recurrence'],
      recurrenceKind: (m['recurrence'] is Map)
          ? (m['recurrence'] as Map)['kind'] as String?
          : null,
      planId: m['plan_id'] as String?,
      periodStart: m['period_start'] as String?,
      periodEnd: m['period_end'] as String?,
    );
  }

  /// Открыта: не принята и не отменена.
  bool get isOpen => status != 'done' && status != 'cancelled';

  /// Просрочена: открыта, а срок прошёл.
  bool isOverdue([DateTime? now]) =>
      isOpen && dueAt != null && dueAt!.isBefore(now ?? DateTime.now());

  static Map<String, dynamic>? _floor(Map<String, dynamic> m) {
    final loc = m['locations'];
    if (loc is! Map<String, dynamic>) return null;
    final f = loc['floors'];
    return f is Map<String, dynamic> ? f : null;
  }
}

/// Помещение с этажом для строки списка: «Лобби · 1 эт.». Если этаж уже
/// есть в названии помещения («Холл, 1 этаж») — без повтора.
String placeWithFloor(String place, String? floorName, String? floorShort) {
  final tag = floorShort ?? floorName;
  if (tag == null || tag.isEmpty) return place;
  final p = place.toLowerCase();
  if (floorName != null && p.contains(floorName.toLowerCase())) return place;
  return '$place · $tag';
}
