import '../directory/city.dart';
import '../directory/directory.dart';
import '../regions/countries.dart';
import '../regions/region.dart';

/// Зоны доступа менеджеров и бригад (шаг 17, 0016). Чистые функции:
/// строка базы ↔ модель, правила (системы × места), сводка словами,
/// шаблоны. Тесты — `test/access_zone_test.dart`.
///
/// В базе одна строка = системы (layer_ids, пусто — все) × одно место
/// (scope_kind / scope_ref). На экране строки с одинаковыми системами
/// собраны в одно «правило» с несколькими местами.

/// Вид места (access_zones.scope_kind).
enum ZoneScope {
  company,
  region,
  country,
  city,
  object,
  floor,
  asset;

  static ZoneScope? fromCode(String? code) {
    for (final s in values) {
      if (s.name == code) return s;
    }
    return null;
  }
}

/// Одно место зоны. [ref] — id региона / объекта / этажа / оборудования,
/// код страны («RU») или название города; у [ZoneScope.company] — null.
class ZonePlace {
  const ZonePlace(this.scope, [this.ref]);
  const ZonePlace.company() : this(ZoneScope.company);

  final ZoneScope scope;
  final String? ref;

  @override
  bool operator ==(Object other) =>
      other is ZonePlace && other.scope == scope && other.ref == ref;

  @override
  int get hashCode => Object.hash(scope, ref);

  @override
  String toString() => 'ZonePlace(${scope.name}, $ref)';
}

/// Строка зоны в базе (access_zones / crew_zones).
class ZoneRow {
  const ZoneRow({required this.place, this.layerIds = const {}});

  final ZonePlace place;

  /// Системы (id слоёв); пусто — все системы.
  final Set<String> layerIds;

  static ZoneRow? fromMap(Map<String, dynamic> m) {
    final scope = ZoneScope.fromCode(m['scope_kind'] as String?);
    if (scope == null) return null;
    return ZoneRow(
      place: ZonePlace(
          scope, scope == ZoneScope.company ? null : m['scope_ref'] as String?),
      layerIds: {
        for (final e in (m['layer_ids'] as List?) ?? const [])
          if (e is String) e
      },
    );
  }

  /// Поля строки для вставки (без владельца: profile_id / crew_id и компании
  /// добавляет репозиторий).
  Map<String, dynamic> toMap() => {
        'layer_ids': layerIds.toList()..sort(),
        'scope_kind': place.scope.name,
        'scope_ref': place.scope == ZoneScope.company ? null : place.ref,
      };
}

/// Правило на экране: системы × места.
class ZoneRule {
  const ZoneRule({this.layerIds = const {}, this.places = const []});

  final Set<String> layerIds;
  final List<ZonePlace> places;

  bool get allLayers => layerIds.isEmpty;

  ZoneRule copyWith({Set<String>? layerIds, List<ZonePlace>? places}) =>
      ZoneRule(
          layerIds: layerIds ?? this.layerIds, places: places ?? this.places);

  List<ZoneRow> toRows() => [
        for (final p in places) ZoneRow(place: p, layerIds: layerIds),
      ];
}

String _layersKey(Set<String> ids) => (ids.toList()..sort()).join(',');

/// Собрать строки базы в правила: одинаковые системы — одно правило.
List<ZoneRule> groupRules(Iterable<ZoneRow> rows) {
  final order = <String>[];
  final byKey = <String, ZoneRule>{};
  for (final r in rows) {
    final k = _layersKey(r.layerIds);
    final cur = byKey[k];
    if (cur == null) {
      order.add(k);
      byKey[k] = ZoneRule(layerIds: r.layerIds, places: [r.place]);
    } else if (!cur.places.contains(r.place)) {
      byKey[k] = cur.copyWith(places: [...cur.places, r.place]);
    }
  }
  return [for (final k in order) byKey[k]!];
}

/// Правила → строки для сохранения (пустые правила пропускаются, дубли —
/// один раз).
List<ZoneRow> rulesToRows(Iterable<ZoneRule> rules) {
  final seen = <String>{};
  final out = <ZoneRow>[];
  for (final rule in rules) {
    for (final row in rule.toRows()) {
      final k =
          '${_layersKey(row.layerIds)}|${row.place.scope.name}|${row.place.ref}';
      if (seen.add(k)) out.add(row);
    }
  }
  return out;
}

/// «Вся компания»: зон нет или есть правило «все системы × вся компания».
bool isWholeCompany(Iterable<ZoneRow> rows) =>
    rows.isEmpty ||
    rows.any((r) => r.layerIds.isEmpty && r.place.scope == ZoneScope.company);

// ---------------------------------------------------------------------------
// Шаблоны
// ---------------------------------------------------------------------------

/// «Вся компания» — без строк (как у менеджера без зон).
List<ZoneRule> templateWholeCompany() => const [];

/// «Одна система во всех объектах».
List<ZoneRule> templateOneSystem(String layerId) => [
      ZoneRule(layerIds: {layerId}, places: const [ZonePlace.company()]),
    ];

/// «Регион целиком» — все системы.
List<ZoneRule> templateRegion(String regionId) => [
      ZoneRule(places: [ZonePlace(ZoneScope.region, regionId)]),
    ];

// ---------------------------------------------------------------------------
// Какие объекты покрывает место
// ---------------------------------------------------------------------------

String _cityKey(String s) => s.trim().toLowerCase().replaceAll('ё', 'е');

/// Объект [o] попадает в место [p]. Этаж / оборудование — по объекту, где
/// они находятся ([floorObject] / [assetObject]: id → id объекта).
bool placeCovers(ZonePlace p, Obj o,
    {Map<String, String> floorObject = const {},
    Map<String, String> assetObject = const {}}) {
  switch (p.scope) {
    case ZoneScope.company:
      return true;
    case ZoneScope.region:
      return o.regionId != null && o.regionId == p.ref;
    case ZoneScope.country:
      return (o.countryCode ?? '').toUpperCase() ==
              (p.ref ?? '').toUpperCase() &&
          (p.ref ?? '').isNotEmpty;
    case ZoneScope.city:
      return o.cityName.isNotEmpty &&
          _cityKey(o.cityName) == _cityKey(p.ref ?? '');
    case ZoneScope.object:
      return o.id == p.ref;
    case ZoneScope.floor:
      return floorObject[p.ref] == o.id;
    case ZoneScope.asset:
      return assetObject[p.ref] == o.id;
  }
}

/// Сколько объектов покрывают места.
int coveredObjects(Iterable<ZonePlace> places, Iterable<Obj> objects,
        {Map<String, String> floorObject = const {},
        Map<String, String> assetObject = const {}}) =>
    objects
        .where((o) => places.any((p) => placeCovers(p, o,
            floorObject: floorObject, assetObject: assetObject)))
        .length;

/// Выбор в окне объектов → места: целый регион, затем целая страна, целый
/// город, иначе отдельные объекты. Регион / страна / город берутся, только
/// если в них больше одного объекта (один объект — просто объект).
/// Если регион состоит ровно из объектов одной страны или одного города
/// (или страна — из одного города), берётся более узкое место: окно выбора
/// отдаёт только объекты, и «Весь город: Москва» в регионе «СНГ» из одной
/// Москвы не должен стать регионом — иначе новый объект региона в другом
/// городе окажется в зоне без ведома администратора (шаг 18).
List<ZonePlace> placesFromSelection(
    Set<String> ids, List<Obj> objects, List<Region> regions) {
  final chosen = [
    for (final o in objects)
      if (ids.contains(o.id)) o
  ];
  if (chosen.isEmpty) return const [];
  if (chosen.length == objects.length && objects.length > 1) {
    return const [ZonePlace.company()];
  }
  final left = {for (final o in chosen) o.id};
  final out = <ZonePlace>[];
  bool whole(Iterable<Obj> group) {
    final g = group.toList();
    return g.length > 1 && g.every((o) => left.contains(o.id));
  }

  final cityGroups = [
    for (final g in groupObjectsByCity(objects))
      if (g.city.isNotEmpty) {for (final o in g.items) o.id}
  ];
  final countryGroups = [
    for (final c in {
      for (final o in objects)
        if ((o.countryCode ?? '').isNotEmpty) o.countryCode!.toUpperCase()
    })
      {
        for (final o in objects)
          if ((o.countryCode ?? '').toUpperCase() == c) o.id
      }
  ];
  bool sameAsAny(Iterable<Obj> group, List<Set<String>> narrower) {
    final ids = {for (final o in group) o.id};
    return narrower.any((n) => n.length == ids.length && n.containsAll(ids));
  }

  // регионы
  for (final r in regions) {
    final g = objects.where((o) => o.regionId == r.id);
    if (whole(g) && !sameAsAny(g, [...countryGroups, ...cityGroups])) {
      out.add(ZonePlace(ZoneScope.region, r.id));
      left.removeAll(g.map((o) => o.id));
    }
  }
  // страны
  final codes = {
    for (final o in objects)
      if ((o.countryCode ?? '').isNotEmpty) o.countryCode!.toUpperCase()
  }.toList()
    ..sort();
  for (final c in codes) {
    final g = objects.where((o) => (o.countryCode ?? '').toUpperCase() == c);
    if (whole(g) && !sameAsAny(g, cityGroups)) {
      out.add(ZonePlace(ZoneScope.country, c));
      left.removeAll(g.map((o) => o.id));
    }
  }
  // города
  for (final g in groupObjectsByCity(objects)) {
    if (g.city.isEmpty) continue;
    if (whole(g.items)) {
      out.add(ZonePlace(ZoneScope.city, g.city));
      left.removeAll(g.items.map((o) => o.id));
    }
  }
  for (final o in chosen) {
    if (left.contains(o.id)) out.add(ZonePlace(ZoneScope.object, o.id));
  }
  return out;
}

/// Объекты, выбранные местами (для окна выбора объектов при изменении).
Set<String> selectionFromPlaces(
        Iterable<ZonePlace> places, List<Obj> objects) =>
    {
      for (final o in objects)
        if (places.any((p) =>
            p.scope != ZoneScope.floor &&
            p.scope != ZoneScope.asset &&
            placeCovers(p, o)))
          o.id
    };

// ---------------------------------------------------------------------------
// Сводка словами
// ---------------------------------------------------------------------------

/// Подписи, которые сводка берёт из переводов и справочников.
class ZoneNames {
  const ZoneNames({
    required this.locale,
    required this.allSystems,
    required this.wholeCompany,
    required this.objectsCount,
    this.layers = const [],
    this.regions = const [],
    this.objects = const [],
    this.floorNames = const {},
    this.assetNames = const {},
    this.floorObject = const {},
    this.assetObject = const {},
  });

  final String locale;
  final String allSystems;
  final String wholeCompany;
  final String Function(int count) objectsCount;
  final List<Layer> layers;
  final List<Region> regions;
  final List<Obj> objects;

  /// id этажа / оборудования → название; → id объекта.
  final Map<String, String> floorNames;
  final Map<String, String> assetNames;
  final Map<String, String> floorObject;
  final Map<String, String> assetObject;
}

/// «Климат, Сантехника» или «Все системы».
String systemsText(Set<String> layerIds, ZoneNames n) {
  if (layerIds.isEmpty) return n.allSystems;
  final names = [
    for (final y in n.layers)
      if (layerIds.contains(y.id)) y.label(n.locale)
  ];
  final unknown = layerIds.length - names.length;
  return [...names, if (unknown > 0) '+$unknown'].join(', ');
}

/// Название места: «Вся компания», «Европа», «Россия», «Москва»,
/// «Москва · Офис 1», «Офис 1 · 3 этаж», «ИБП серверной».
String placeText(ZonePlace p, ZoneNames n) {
  String objName(String? id) {
    for (final o in n.objects) {
      if (o.id == id) return objectDisplayName(o);
    }
    return '…';
  }

  switch (p.scope) {
    case ZoneScope.company:
      return n.wholeCompany;
    case ZoneScope.region:
      for (final r in n.regions) {
        if (r.id == p.ref) return r.name;
      }
      return '…';
    case ZoneScope.country:
      return countryLabel(p.ref, n.locale, flag: false);
    case ZoneScope.city:
      return p.ref ?? '';
    case ZoneScope.object:
      return objName(p.ref);
    case ZoneScope.floor:
      final f = n.floorNames[p.ref] ?? '…';
      final o = n.floorObject[p.ref];
      return o == null ? f : '${objName(o)} · $f';
    case ZoneScope.asset:
      return n.assetNames[p.ref] ?? '…';
  }
}

/// «Климат, Сантехника · Москва (5 объектов)»; несколько мест — через запятую,
/// число — объектов во всех местах правила.
String ruleSummary(ZoneRule r, ZoneNames n, {bool withCount = true}) {
  final places = r.places.map((p) => placeText(p, n)).join(', ');
  final onlyCompany =
      r.places.length == 1 && r.places.single.scope == ZoneScope.company;
  final count = coveredObjects(r.places, n.objects,
      floorObject: n.floorObject, assetObject: n.assetObject);
  final tail = withCount && !onlyCompany && n.objects.isNotEmpty
      ? ' (${n.objectsCount(count)})'
      : '';
  return '${systemsText(r.layerIds, n)} · $places$tail';
}

/// Короткая сводка всех правил для таблетки роли на ПК: «Климат, Москва».
/// null — ограничений нет (вся компания).
String? zonesShortText(Iterable<ZoneRow> rows, ZoneNames n) {
  if (isWholeCompany(rows)) return null;
  final rules = groupRules(rows);
  final parts = <String>[];
  for (final r in rules) {
    final places = r.places.map((p) => placeText(p, n)).join(', ');
    parts.add(
        r.layerIds.isEmpty ? places : '${systemsText(r.layerIds, n)}, $places');
  }
  return parts.join('; ');
}
