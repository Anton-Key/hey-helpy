import '../regions/countries.dart';
import '../regions/region.dart';
import 'directory.dart';

/// Города объектов (шаг 13d). Отдельного поля «город» в базе нет: город —
/// часть адреса до первой запятой («Москва, ул. Лесная (демо)» → «Москва»).
/// Без адреса или без запятой — «без города» (пустая строка; подпись —
/// `l10n.cityNone`). Тесты — `test/city_test.dart`.

/// Город по адресу; `''` — без города.
String cityOf(String? address) {
  final a = address?.trim() ?? '';
  final i = a.indexOf(',');
  if (i <= 0) return '';
  return a.substring(0, i).trim();
}

/// «Город · Название» или просто «Название» (без города или [withCity] = false —
/// например внутри секции, уже сгруппированной по городу).
String objectLabel(String name, String? address, {bool withCity = true}) {
  final city = withCity ? cityOf(address) : '';
  return city.isEmpty ? name : '$city · $name';
}

/// Название объекта для показа: везде, где нет контекста города, —
/// «Москва · Офис 3» (в разных городах бывают одинаковые «Офис 1»).
String objectDisplayName(Obj object, {bool withCity = true}) {
  final c = withCity ? object.cityName : '';
  return c.isEmpty ? object.name : '$c · ${object.name}';
}

String _key(String s) => s.toLowerCase().replaceAll('ё', 'е');

/// Порядок городов: по алфавиту без учёта регистра, «без города» — в конце.
int compareCities(String a, String b) {
  if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
  return _key(a).compareTo(_key(b));
}

/// Группа объектов одного города.
class CityGroup<T> {
  const CityGroup(this.city, this.items);

  /// `''` — без города.
  final String city;
  final List<T> items;
}

/// Делит на города: города по алфавиту («без города» — в конце), внутри —
/// по названию.
List<CityGroup<T>> groupByCity<T>(Iterable<T> items,
        {required String? Function(T) address,
        required String Function(T) name}) =>
    groupByCityName(items, city: (i) => cityOf(address(i)), name: name);

/// То же по готовому названию города ('' — без города).
List<CityGroup<T>> groupByCityName<T>(Iterable<T> items,
    {required String Function(T) city, required String Function(T) name}) {
  final cityFn = city;
  // Регистр не важен: «москва» и «Москва» — один город (подпись — первая).
  final map = <String, List<T>>{};
  final shown = <String, String>{};
  for (final i in items) {
    final city = cityFn(i).trim();
    shown.putIfAbsent(_key(city), () => city);
    map.putIfAbsent(_key(city), () => []).add(i);
  }
  final cities = shown.values.toList()..sort(compareCities);
  return [
    for (final c in cities)
      CityGroup(
          c,
          map[_key(c)]!
            ..sort((a, b) => _naturalCompare(_key(name(a)), _key(name(b))))),
  ];
}

/// Объекты по городам: поле города (0015), иначе часть адреса до запятой.
List<CityGroup<Obj>> groupObjectsByCity(Iterable<Obj> objects) =>
    groupByCityName(objects, city: (o) => o.cityName, name: (o) => o.name);

/// Страна внутри региона: код ISO ('' — страна не указана) и её города.
class CountryGroup {
  const CountryGroup(this.code, this.cities);
  final String code;
  final List<CityGroup<Obj>> cities;
  int get count => cities.fold(0, (n, c) => n + c.items.length);
  List<Obj> get objects => [for (final c in cities) ...c.items];
}

/// Регион ([region] null — «Без региона») и его страны.
class RegionGroup {
  const RegionGroup(this.region, this.countries);
  final Region? region;
  final List<CountryGroup> countries;
  int get count => countries.fold(0, (n, c) => n + c.count);
  List<Obj> get objects => [for (final c in countries) ...c.objects];
}

/// Регион → страна → город (шаг 16). Регионы — в порядке списка компании
/// ([sortRegions]), «Без региона» — в конце; страны — по названию на языке
/// [localeCode], «без страны» — в конце; города — как [groupObjectsByCity].
/// null — у компании нет регионов или ни один объект не привязан к региону:
/// тогда группируем, как раньше, только по городам.
List<RegionGroup>? groupObjectsByRegion(
    Iterable<Obj> objects, List<Region> regions, String localeCode) {
  if (regions.isEmpty) return null;
  final byId = {for (final r in regions) r.id: r};
  final list = objects.toList();
  if (!list.any((o) => byId.containsKey(o.regionId))) return null;
  final byRegion = <String?, List<Obj>>{};
  for (final o in list) {
    final rid = byId.containsKey(o.regionId) ? o.regionId : null;
    byRegion.putIfAbsent(rid, () => []).add(o);
  }
  String countryKey(String code) => code.isEmpty
      ? '\uFFFF'
      : _key(countryLabel(code, localeCode, flag: false));
  List<CountryGroup> countries(List<Obj> items) {
    final byCountry = <String, List<Obj>>{};
    for (final o in items) {
      final c = (o.countryCode ?? '').trim().toUpperCase();
      byCountry.putIfAbsent(c, () => []).add(o);
    }
    final codes = byCountry.keys.toList()
      ..sort((a, b) => countryKey(a).compareTo(countryKey(b)));
    return [
      for (final c in codes) CountryGroup(c, groupObjectsByCity(byCountry[c]!))
    ];
  }

  return [
    for (final r in sortRegions(regions))
      if (byRegion.containsKey(r.id))
        RegionGroup(r, countries(byRegion[r.id]!)),
    if (byRegion.containsKey(null))
      RegionGroup(null, countries(byRegion[null]!)),
  ];
}

/// Города без повторов (регистр не важен), по алфавиту (без «без города»).
List<String> citiesOf(Iterable<String?> addresses) {
  final byKey = <String, String>{};
  for (final a in addresses) {
    final c = cityOf(a);
    if (c.isNotEmpty) byKey.putIfAbsent(_key(c), () => c);
  }
  return byKey.values.toList()..sort(compareCities);
}

/// Сравнение с числами по значению: «Офис 2» < «Офис 10».
int _naturalCompare(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final pa = re.allMatches(a).map((m) => m[0]!).toList();
  final pb = re.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = int.tryParse(pa[i]), y = int.tryParse(pb[i]);
    final c =
        (x != null && y != null) ? x.compareTo(y) : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
