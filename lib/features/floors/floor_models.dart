import 'plan_logic.dart' show parsePlanShape;

/// Этаж объекта (таблица floors, миграция 0013).
class Floor {
  const Floor({
    required this.id,
    required this.objectId,
    required this.companyId,
    required this.name,
    this.level,
    this.sort = 0,
    this.planPath,
    this.planW,
    this.planH,
  });

  final String id;
  final String objectId;
  final String companyId;
  final String name;

  /// Номер этажа: −2 — парковка, 0 — цоколь, null — не задан.
  final int? level;

  /// Порядок в списке этажей объекта.
  final int sort;

  /// Путь картинки плана в бакете floor-plans; null — плана нет.
  final String? planPath;
  final int? planW;
  final int? planH;

  bool get hasPlan => planPath != null && planW != null && planH != null;

  static const columns =
      'id,object_id,company_id,name,level,sort,plan_path,plan_w,plan_h';

  factory Floor.fromMap(Map<String, dynamic> m) => Floor(
        id: m['id'] as String,
        objectId: m['object_id'] as String,
        companyId: m['company_id'] as String,
        name: (m['name'] ?? '') as String,
        level: (m['level'] as num?)?.toInt(),
        sort: (m['sort'] as num?)?.toInt() ?? 0,
        planPath: m['plan_path'] as String?,
        planW: (m['plan_w'] as num?)?.toInt(),
        planH: (m['plan_h'] as num?)?.toInt(),
      );
}

/// Что стоит на плане: помещение или оборудование.
enum PlanKind { place, asset }

/// Маркер плана: помещение (locations) или оборудование (assets) с этажом
/// и точкой ([x], [y] — доли 0..1 от ширины и высоты картинки).
class PlanItem {
  const PlanItem({
    required this.kind,
    required this.id,
    required this.name,
    this.floorId,
    this.x,
    this.y,
    this.locationId,
    this.category,
    this.equipmentKind,
    this.inventoryNo,
    this.code,
    this.shape,
  });

  final PlanKind kind;
  final String id;
  final String name;
  final String? floorId;
  final double? x;
  final double? y;

  /// Оборудование: помещение, где оно стоит.
  final String? locationId;

  /// Оборудование: категория из базы (equipment / furniture / infra / other).
  final String? category;

  /// Оборудование: вид для значка (assets.meta.kind: ac, fancoil, panel,
  /// light, smoke, ups, …); null — по категории.
  final String? equipmentKind;
  final String? inventoryNo;

  /// Помещение: номер («305», locations.code, 0015); null — без номера.
  final String? code;

  /// Помещение: область на плане — многоугольник, точки долями 0..1
  /// (locations.plan_shape, 0013); null — области нет.
  final List<(double, double)>? shape;

  bool get isPlace => kind == PlanKind.place;

  /// Подпись: «305 · Переговорная» (с номером) или название.
  String get label {
    final c = code?.trim() ?? '';
    return c.isEmpty ? name : '$c · $name';
  }

  /// Есть область на плане этажа [floorId].
  bool hasAreaOn(String floorId) =>
      isPlace && this.floorId == floorId && (shape?.length ?? 0) >= 3;

  /// Есть точка на плане.
  bool get placed => x != null && y != null;

  /// Стоит на плане этажа [floorId].
  bool isOn(String floorId) => this.floorId == floorId && placed;

  /// Ключ маркера: помещение и оборудование могут иметь одинаковые id
  /// в разных таблицах только теоретически — всё равно различаем.
  String get key => '${kind.name}:$id';

  PlanItem copyWith({
    String? name,
    String? floorId,
    bool clearFloor = false,
    double? x,
    double? y,
    bool clearPoint = false,
    String? locationId,
    String? code,
    bool clearCode = false,
    List<(double, double)>? shape,
    bool clearShape = false,
  }) =>
      PlanItem(
        kind: kind,
        id: id,
        name: name ?? this.name,
        floorId: clearFloor ? null : (floorId ?? this.floorId),
        x: clearPoint ? null : (x ?? this.x),
        y: clearPoint ? null : (y ?? this.y),
        locationId: locationId ?? this.locationId,
        category: category,
        equipmentKind: equipmentKind,
        inventoryNo: inventoryNo,
        code: clearCode ? null : (code ?? this.code),
        shape: clearShape ? null : (shape ?? this.shape),
      );

  /// Колонки помещения: без номера — для базы до миграции 0015
  /// (plan_shape есть с 0013).
  static const placeColumnsLegacy =
      'id,object_id,name,floor_id,plan_x,plan_y,plan_shape';
  static const placeColumns = '$placeColumnsLegacy,code';
  static const assetColumns =
      'id,location_id,name,category,inventory_no,meta,floor_id,plan_x,plan_y,'
      'locations!inner(object_id)';

  factory PlanItem.placeFromMap(Map<String, dynamic> m) => PlanItem(
        kind: PlanKind.place,
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        floorId: m['floor_id'] as String?,
        x: (m['plan_x'] as num?)?.toDouble(),
        y: (m['plan_y'] as num?)?.toDouble(),
        code: switch ((m['code'] as String?)?.trim()) {
          final c? when c.isNotEmpty => c,
          _ => null,
        },
        shape: parsePlanShape(m['plan_shape']),
      );

  factory PlanItem.assetFromMap(Map<String, dynamic> m) {
    final meta = m['meta'];
    return PlanItem(
      kind: PlanKind.asset,
      id: m['id'] as String,
      name: (m['name'] ?? '') as String,
      floorId: m['floor_id'] as String?,
      x: (m['plan_x'] as num?)?.toDouble(),
      y: (m['plan_y'] as num?)?.toDouble(),
      locationId: m['location_id'] as String?,
      category: m['category'] as String?,
      equipmentKind: meta is Map ? meta['kind'] as String? : null,
      inventoryNo: m['inventory_no'] as String?,
    );
  }
}

/// Открытая заявка объекта — для маркеров и шторки маркера.
class PlanOrder {
  const PlanOrder({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.locationId,
    this.assetId,
    this.dueAt,
    this.row = const {},
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final String? locationId;
  final String? assetId;
  final DateTime? dueAt;

  /// Строка базы целиком — чтобы открыть карточку заявки.
  final Map<String, dynamic> row;

  bool get isOpen => status != 'done' && status != 'cancelled';
  bool isOverdue(DateTime now) =>
      isOpen && dueAt != null && dueAt!.isBefore(now);

  static const columns =
      'id,title,status,priority,due_at,created_at,object_id,location_id,'
      'asset_id,layer_id,work_type,assigned_contractor_id,locations(name)';

  factory PlanOrder.fromMap(Map<String, dynamic> m) => PlanOrder(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        status: (m['status'] ?? 'new') as String,
        priority: (m['priority'] ?? 'normal') as String,
        locationId: m['location_id'] as String?,
        assetId: m['asset_id'] as String?,
        dueAt: DateTime.tryParse('${m['due_at'] ?? ''}')?.toLocal(),
        row: m,
      );
}
