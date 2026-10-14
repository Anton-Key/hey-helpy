import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

// =====================================================================
// Где именно стоит оборудование (шаг 27, блок 6): монтаж, высота,
// ориентир и фото места — в assets.meta (без миграции; остальные ключи
// meta сохраняются). Чистые функции, тесты — test/asset_place_test.dart.
// =====================================================================

/// Как установлено: пол / стена / потолок / за подвесным потолком /
/// в шкафу / снаружи. Код хранится в assets.meta.mount.
const kMountCodes = [
  'floor',
  'wall',
  'ceiling',
  'above_ceiling',
  'cabinet',
  'outdoor',
];

/// Самая большая высота, которую принимаем (м): больше — опечатка.
const kMaxMountHeight = 100.0;

/// Самый длинный ориентир (символов).
const kMaxLandmark = 200;

/// Ключи assets.meta.
const kMetaMount = 'mount';
const kMetaHeight = 'height_m';
const kMetaLandmark = 'landmark';
const kMetaPlacePhoto = 'place_photo';

/// Уточнение места установки. Всё необязательно.
class MountInfo {
  const MountInfo({this.mount, this.heightM, this.landmark});

  /// Код из [kMountCodes]; null — не указано.
  final String? mount;

  /// Высота от пола, м; null — не указана.
  final double? heightM;

  /// Ориентир: «над дверью, слева».
  final String? landmark;

  static const empty = MountInfo();

  bool get isEmpty => mount == null && heightM == null && landmark == null;

  /// Из assets.meta: неизвестный код, не число, пустая строка — как
  /// «не указано» (мусор в базе ничего не ломает).
  factory MountInfo.fromMeta(Map<dynamic, dynamic>? meta) {
    if (meta == null) return empty;
    final m = meta[kMetaMount];
    final h = meta[kMetaHeight];
    final t = meta[kMetaLandmark];
    double? height;
    if (h is num) {
      height = h.toDouble();
    } else if (h is String) {
      height = parseHeight(h);
    }
    if (height != null && !_heightOk(height)) height = null;
    return MountInfo(
      mount: m is String && kMountCodes.contains(m) ? m : null,
      heightM: height,
      landmark: cleanLandmark(t is String ? t : null),
    );
  }

  /// Новый meta: эти три ключа записаны (или убраны), остальные — как были.
  Map<String, dynamic> applyTo(Map<String, dynamic>? meta) {
    final out = Map<String, dynamic>.of(meta ?? const {});
    void put(String k, Object? v) => v == null ? out.remove(k) : out[k] = v;
    put(kMetaMount, kMountCodes.contains(mount) ? mount : null);
    put(kMetaHeight,
        heightM == null || !_heightOk(heightM!) ? null : roundHeight(heightM!));
    put(kMetaLandmark, cleanLandmark(landmark));
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is MountInfo &&
      other.mount == mount &&
      other.heightM == heightM &&
      other.landmark == landmark;

  @override
  int get hashCode => Object.hash(mount, heightM, landmark);

  @override
  String toString() => 'MountInfo($mount, $heightM, $landmark)';
}

bool _heightOk(double h) => h.isFinite && h >= 0 && h <= kMaxMountHeight;

/// Высота до сантиметра.
double roundHeight(double h) => (h * 100).roundToDouble() / 100;

/// Ориентир без лишних пробелов; пустой — null; длинный — обрезан.
String? cleanLandmark(String? s) {
  final t = s?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  if (t.isEmpty) return null;
  return t.length > kMaxLandmark ? t.substring(0, kMaxLandmark) : t;
}

/// «2,8», «2.8», «2,8 м», «3 m» → 2.8 / 3.0. Пусто или не число, меньше
/// нуля, больше [kMaxMountHeight] — null.
double? parseHeight(String s) {
  var t = s.trim().toLowerCase().replaceAll(',', '.');
  t = t.replaceAll(RegExp(r'\s*(м|m|метр[а-я]*|meters?|metres?)\.?$'), '');
  t = t.trim();
  if (t.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
  final v = double.tryParse(t);
  if (v == null || !_heightOk(v)) return null;
  return roundHeight(v);
}

/// Поле «Высота, м» заполнено правильно (пустое — тоже правильно).
bool heightTextOk(String s) => s.trim().isEmpty || parseHeight(s) != null;

/// «2,8» (ru) / «2.8» (en) — без лишних нулей.
String formatHeightNumber(double h, String locale) =>
    NumberFormat('0.##', locale).format(h);

/// Подпись вида монтажа: «Потолок», «За подвесным потолком».
String mountLabel(AppLocalizations l, String code) => switch (code) {
      'floor' => l.eqPlaceMountFloor,
      'wall' => l.eqPlaceMountWall,
      'ceiling' => l.eqPlaceMountCeiling,
      'above_ceiling' => l.eqPlaceMountAboveCeiling,
      'cabinet' => l.eqPlaceMountCabinet,
      'outdoor' => l.eqPlaceMountOutdoor,
      _ => code,
    };

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// Одна строка «потолок · 2,8 м · над дверью, слева» (карточка
/// оборудования, «Камера-помощник», карточка заявки). Без ориентира
/// ([withLandmark] = false) — для подписи маркера на плане: «потолок · 2,8 м».
/// null — ничего не указано.
String? formatMountLine(AppLocalizations l, MountInfo m,
    {bool withLandmark = true}) {
  final parts = [
    if (m.mount != null) _lowerFirst(mountLabel(l, m.mount!)),
    if (m.heightM != null)
      l.eqPlaceHeightValue(formatHeightNumber(m.heightM!, l.localeName)),
    if (withLandmark && m.landmark != null) m.landmark!,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Точка на плане этажа: этаж и доли 0..1 от ширины и высоты картинки.
class PlanPoint {
  const PlanPoint(this.floorId, this.x, this.y);
  final String floorId;
  final double x;
  final double y;

  /// Доли до 4 знаков (как у маркеров плана) и в пределах 0..1.
  PlanPoint rounded() {
    double r(double v) => (v.clamp(0.0, 1.0) * 10000).roundToDouble() / 10000;
    return PlanPoint(floorId, r(x), r(y));
  }

  @override
  bool operator ==(Object other) =>
      other is PlanPoint &&
      other.floorId == floorId &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(floorId, x, y);

  @override
  String toString() => 'PlanPoint($floorId, $x, $y)';
}

/// Путь фото места установки в хранилище floor-plans — в папке этажа
/// (политики 0013/0014: загружает менеджер своей компании в папку
/// существующего этажа; видит тот, кто видит этаж):
/// `<company_id>/<object_id>/<floor_id>/asset-place-<время>.<расш>`.
String placePhotoPath(String companyId, String objectId, String floorId,
        String ext, DateTime now) =>
    '$companyId/$objectId/$floorId/asset-place-${now.millisecondsSinceEpoch}.$ext';

/// Путь фото места из meta (только похожий на наш — защита от мусора).
String? placePhotoOf(Map<dynamic, dynamic>? meta) {
  final v = meta?[kMetaPlacePhoto];
  if (v is! String) return null;
  return RegExp(
              r'^[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}/asset-place-\d+\.(jpg|png|webp)$')
          .hasMatch(v)
      ? v
      : null;
}

/// meta с фото места (null — убрать).
Map<String, dynamic> withPlacePhoto(Map<String, dynamic>? meta, String? path) {
  final out = Map<String, dynamic>.of(meta ?? const {});
  if (path == null) {
    out.remove(kMetaPlacePhoto);
  } else {
    out[kMetaPlacePhoto] = path;
  }
  return out;
}
