/// Оборудование объекта (assets) для реестра (шаг 16).
///
/// Паспортные поля (система, производитель, модель, серийный номер, дата
/// ввода) появляются в базе с миграцией 0015; до неё они null.
class Asset {
  const Asset({
    required this.id,
    required this.locationId,
    required this.name,
    this.category = 'equipment',
    this.inventoryNo,
    this.kind,
    this.layerId,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.installedAt,
    this.floorId,
    this.placed = false,
  });

  final String id;
  final String locationId;
  final String name;
  final String category;
  final String? inventoryNo;

  /// Вид для значка (assets.meta.kind: ac, panel, ups…).
  final String? kind;
  final String? layerId;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final DateTime? installedAt;

  /// Этаж и точка на плане (0013).
  final String? floorId;
  final bool placed;

  /// Колонки до 0015 и после.
  static const legacyColumns =
      'id,location_id,name,category,inventory_no,meta,floor_id,plan_x';
  static const columns =
      '$legacyColumns,layer_id,manufacturer,model,serial_no,installed_at';

  factory Asset.fromMap(Map<String, dynamic> m) {
    final meta = m['meta'];
    String? text(String k) {
      final v = (m[k] as String?)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return Asset(
      id: m['id'] as String,
      locationId: m['location_id'] as String,
      name: (m['name'] ?? '') as String,
      category: (m['category'] ?? 'equipment') as String,
      inventoryNo: text('inventory_no'),
      kind: meta is Map ? meta['kind'] as String? : null,
      layerId: m['layer_id'] as String?,
      manufacturer: text('manufacturer'),
      model: text('model'),
      serialNo: text('serial_no'),
      installedAt: DateTime.tryParse('${m['installed_at'] ?? ''}'),
      floorId: m['floor_id'] as String?,
      placed: m['plan_x'] != null,
    );
  }

  /// «Daikin FTXM35R» (производитель и модель вместе), null — ничего нет.
  String? get makeModel {
    final s = [manufacturer, model].whereType<String>().join(' ');
    return s.isEmpty ? null : s;
  }
}

/// Новая единица оборудования (форма или строка импорта).
class AssetDraft {
  const AssetDraft({
    required this.name,
    required this.locationId,
    this.layerId,
    this.inventoryNo,
    this.manufacturer,
    this.model,
    this.serialNo,
    this.installedAt,
  });

  final String name;
  final String locationId;
  final String? layerId;
  final String? inventoryNo;
  final String? manufacturer;
  final String? model;
  final String? serialNo;
  final DateTime? installedAt;

  Map<String, dynamic> toRow() => {
        'name': name,
        'location_id': locationId,
        'category': 'equipment',
        'inventory_no': inventoryNo,
        'layer_id': layerId,
        'manufacturer': manufacturer,
        'model': model,
        'serial_no': serialNo,
        'installed_at': installedAt == null ? null : isoDate(installedAt!),
      };
}

/// «2026-10-10».
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// План ППР оборудования (для карточки): название и период.
class AssetPlan {
  const AssetPlan(
      {required this.id,
      required this.title,
      required this.periodKind,
      this.periodDays,
      this.active = true});
  final String id;
  final String title;
  final String periodKind;
  final int? periodDays;
  final bool active;

  factory AssetPlan.fromMap(Map<String, dynamic> m) => AssetPlan(
        id: m['id'] as String,
        title: (m['title'] ?? '') as String,
        periodKind: (m['period_kind'] ?? 'month') as String,
        periodDays: (m['period_days'] as num?)?.toInt(),
        active: m['active'] != false,
      );
}
