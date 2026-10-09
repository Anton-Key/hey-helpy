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

  /// Поля для фильтров списка (шаг 13c).
  final String? locationId;
  final String? contractorId;
  final String? executorId;
  final String? createdBy;
  final String? inputChannel;
  final bool requiresPhoto;
  final int returnCount;

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
      this.locationId,
      this.contractorId,
      this.executorId,
      this.createdBy,
      this.inputChannel,
      this.requiresPhoto = false,
      this.returnCount = 0});

  /// Колонки для [WorkOrder.fromMap] в запросе списка.
  static const listColumns =
      'id,title,work_type,layer_id,priority,status,recurrence,object_id,'
      'location_id,assigned_contractor_id,assigned_executor_id,created_by,'
      'input_channel,requires_photo,return_count,due_at,created_at,'
      'locations(name)';

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
      locationId: m['location_id'] as String?,
      contractorId: m['assigned_contractor_id'] as String?,
      executorId: m['assigned_executor_id'] as String?,
      createdBy: m['created_by'] as String?,
      inputChannel: m['input_channel'] as String?,
      requiresPhoto: m['requires_photo'] == true,
      returnCount: (m['return_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Открыта: не принята и не отменена.
  bool get isOpen => status != 'done' && status != 'cancelled';

  /// Просрочена: открыта, а срок прошёл.
  bool isOverdue([DateTime? now]) =>
      isOpen && dueAt != null && dueAt!.isBefore(now ?? DateTime.now());
}
