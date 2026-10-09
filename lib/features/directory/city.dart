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
String objectDisplayName(Obj object, {bool withCity = true}) =>
    objectLabel(object.name, object.address, withCity: withCity);

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
    {required String? Function(T) address, required String Function(T) name}) {
  // Регистр не важен: «москва» и «Москва» — один город (подпись — первая).
  final map = <String, List<T>>{};
  final shown = <String, String>{};
  for (final i in items) {
    final city = cityOf(address(i));
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

/// Объекты по городам.
List<CityGroup<Obj>> groupObjectsByCity(Iterable<Obj> objects) =>
    groupByCity(objects, address: (o) => o.address, name: (o) => o.name);

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
