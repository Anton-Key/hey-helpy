import '../../l10n/app_localizations.dart';
import '../equipment/equipment_kinds.dart';
import '../floors/plan_logic.dart' show floorPartIfNew;

/// Шильдик, прочитанный моделью (что прочиталось; ничего не выдумано).
class Nameplate {
  const Nameplate({this.manufacturer, this.model, this.serial});
  final String? manufacturer;
  final String? model;
  final String? serial;

  static Nameplate? fromJson(Object? v) {
    if (v is! Map) return null;
    final n = Nameplate(
      manufacturer: _str(v['manufacturer']),
      model: _str(v['model']),
      serial: _str(v['serial']),
    );
    return n.isEmpty ? null : n;
  }

  bool get isEmpty => manufacturer == null && model == null && serial == null;

  /// «Daikin FTXM35R · SN 9931» — одной строкой.
  String get text => [
        [manufacturer, model].whereType<String>().join(' '),
        if (serial != null) 'SN $serial',
      ].where((s) => s.isNotEmpty).join(' · ');
}

/// Кандидат из реестра: «какая это единица».
class IdentifyCandidate {
  const IdentifyCandidate({
    required this.assetId,
    required this.name,
    required this.locationId,
    required this.locationLabel,
    this.floorLabel,
    this.score = 0,
    this.reasons = const [],
  });

  final String assetId;
  final String name;
  final String locationId;
  final String locationLabel;
  final String? floorLabel;
  final double score;

  /// Коды причин: kind, layer, same_room, same_floor, same_object, serial,
  /// model, open_order (подписи — [reasonLabel]).
  final List<String> reasons;

  static IdentifyCandidate? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = _str(v['asset_id']);
    final loc = _str(v['location_id']);
    if (id == null || loc == null) return null;
    return IdentifyCandidate(
      assetId: id,
      name: _str(v['name']) ?? '',
      locationId: loc,
      locationLabel: _str(v['location_label']) ?? '',
      floorLabel: _str(v['floor_label']),
      score: (v['score'] as num?)?.toDouble() ?? 0,
      reasons: [
        for (final r in (v['reasons'] as List?) ?? const [])
          if (r is String) r
      ],
    );
  }

  /// «301 Переговорная · 3 этаж»; этаж — только если его нет в названии
  /// помещения («Переговорная, 3 этаж» — без повтора).
  String get placeText => [
        locationLabel,
        floorPartIfNew(floorLabel, [locationLabel]),
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
}

/// Ответ функции photo-identify.
class PhotoIdentification {
  const PhotoIdentification({
    required this.kind,
    this.layerId,
    this.layerName,
    this.nameplate,
    this.defect,
    this.confidence,
    this.candidates = const [],
    this.model,
    this.ms,
  });

  final String kind;
  final String? layerId;
  final String? layerName;
  final Nameplate? nameplate;
  final String? defect;
  final double? confidence;
  final List<IdentifyCandidate> candidates;

  /// main | lite — какая модель ответила.
  final String? model;

  /// Время на сервере, мс.
  final int? ms;

  static PhotoIdentification? fromJson(Object? v) {
    if (v is! Map || v['source'] != 'ai') return null;
    final c = (v['confidence'] as num?)?.toDouble();
    return PhotoIdentification(
      kind: equipmentKind(_str(v['kind']))?.code ?? 'other',
      layerId: _str(v['layer_id']),
      layerName: _str(v['layer']),
      nameplate: Nameplate.fromJson(v['nameplate']),
      defect: _str(v['defect']),
      confidence: c?.clamp(0, 1).toDouble(),
      candidates: [
        for (final x in (v['candidates'] as List?) ?? const [])
          if (IdentifyCandidate.fromJson(x) case final c?) c
      ],
      model: switch (v['model']) {
        'main' => 'main',
        'lite' => 'lite',
        _ => null
      },
      ms: (v['ms'] as num?)?.toInt(),
    );
  }

  IdentifyCandidate? get top => candidates.isEmpty ? null : candidates.first;

  /// «91%» — уверенность в процентах; null — модель не сказала.
  int? get percent => confidence == null ? null : (confidence! * 100).round();
}

/// Подпись причины совпадения на языке интерфейса.
String reasonLabel(AppLocalizations l, String code) => switch (code) {
      'serial' => l.photoReasonSerial,
      'model' => l.photoReasonModel,
      'kind' => l.photoReasonKind,
      'layer' => l.photoReasonLayer,
      'same_room' => l.photoReasonRoom,
      'same_floor' => l.photoReasonFloor,
      'same_object' => l.photoReasonObject,
      'open_order' => l.photoReasonOpenOrder,
      _ => code,
    };

/// «тот же вид · то же помещение» — без причины «та же система» (она почти
/// всегда идёт вместе с видом и только удлиняет строку).
String reasonsText(AppLocalizations l, List<String> reasons) => [
      for (final r in reasons)
        if (r != 'layer' || !reasons.contains('kind')) reasonLabel(l, r)
    ].join(' · ');

/// Заголовок новой заявки: неисправность с фото или «{вид}: проверить».
String photoOrderTitle(AppLocalizations l, PhotoIdentification r) {
  final d = r.defect?.trim();
  if (d != null && d.isNotEmpty) {
    return d.length <= 60 ? d : '${d.substring(0, 59).trimRight()}…';
  }
  return l.photoOrderTitleCheck(equipmentKindLabel(l, r.kind));
}

/// Описание заявки: что увидел ИИ (вид, шильдик) — для исполнителя.
String photoOrderDescription(AppLocalizations l, PhotoIdentification r) => [
      l.photoOrderDescKind(equipmentKindLabel(l, r.kind)),
      if (r.nameplate != null) l.photoOrderDescPlate(r.nameplate!.text),
      if (r.defect != null) l.photoOrderDescDefect(r.defect!),
    ].join('\n');

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
