import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../regions/countries.dart';
import '../regions/region.dart';
import 'city.dart';
import 'directory.dart';

bool _sameSet(Set<String> ids, Iterable<Obj> items) {
  final other = {for (final o in items) o.id};
  return other.length == ids.length && other.containsAll(ids);
}

/// Подпись выбранных объектов (таблетка фильтра заявок, фильтр отчётов):
/// один — «Москва · Офис 3»; ровно весь регион — «Европа (7)»; весь город —
/// «Россия · Москва (5)» (без страны — «Москва (5)»); вся страна —
/// «Сербия (7)»; несколько — «Москва · Офис 1 +2». null — ничего не выбрано.
/// [regions] — регионы компании (по умолчанию — последний загруженный
/// список [RegionRepository.cached]); без регионов — только города.
String? objectsSelectionLabel(
    AppLocalizations l, Set<String> ids, List<Obj> objects,
    {List<Region>? regions}) {
  if (ids.isEmpty) return null;
  final loc = l.localeName;
  final geo = groupObjectsByRegion(
      objects, regions ?? RegionRepository.cached ?? const [], loc);
  if (geo != null) {
    for (final r in geo) {
      if (r.region != null && r.count >= 2 && _sameSet(ids, r.objects)) {
        return l.filterCityWhole(r.region!.name, r.count);
      }
    }
    for (final r in geo) {
      for (final c in r.countries) {
        for (final g in c.cities) {
          if (g.city.isEmpty || g.items.length < 2) continue;
          if (_sameSet(ids, g.items)) {
            final name = c.code.isEmpty
                ? g.city
                : '${countryLabel(c.code, loc, flag: false)} · ${g.city}';
            return l.filterCityWhole(name, g.items.length);
          }
        }
        if (c.code.isNotEmpty && c.count >= 2 && _sameSet(ids, c.objects)) {
          return l.filterCityWhole(
              countryLabel(c.code, loc, flag: false), c.count);
        }
      }
    }
  } else {
    for (final g in groupObjectsByCity(objects)) {
      if (g.city.isEmpty || g.items.length < 2) continue;
      if (_sameSet(ids, g.items)) {
        return l.filterCityWhole(g.city, g.items.length);
      }
    }
  }
  Obj? first;
  for (final g in groupObjectsByCity(objects)) {
    for (final o in g.items) {
      if (ids.contains(o.id)) {
        first = o;
        break;
      }
    }
    if (first != null) break;
  }
  final name = first == null ? '…' : objectDisplayName(first);
  return ids.length == 1 ? name : l.filterPlus(name, ids.length - 1);
}

/// Подходит ли объект под поиск: название, город, страна, адрес (все слова).
bool objectMatches(Obj o, String query) {
  String norm(String s) => s.toLowerCase().replaceAll('ё', 'е');
  final q = norm(query.trim());
  if (q.isEmpty) return true;
  final country = countryByCode(o.countryCode);
  final hay = norm('${o.name} ${o.cityName} ${o.address ?? ''} '
      '${country?.ru ?? ''} ${country?.en ?? ''}');
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// Окно выбора объектов. Без регионов — секции по городам («МОСКВА · 5»)
/// со строкой «Весь город». С регионами (шаг 16) — секции по регионам
/// («ЕВРОПА · 7»): «Весь регион», «Вся страна», «Весь город» (галочка —
/// выбраны все, минус — часть) и объекты. Поиск — по названию, городу,
/// стране. Возвращает выбранные id (Navigator.pop) или null (закрыли).
class ObjectPickerPanel extends StatefulWidget {
  const ObjectPickerPanel(
      {super.key,
      required this.title,
      required this.objects,
      required this.selected,
      this.regions});
  final String title;
  final List<Obj> objects;
  final Set<String> selected;

  /// Регионы компании; null — загрузить самому (или взять из кэша).
  final List<Region>? regions;

  @override
  State<ObjectPickerPanel> createState() => _ObjectPickerPanelState();
}

class _ObjectPickerPanelState extends State<ObjectPickerPanel> {
  late final Set<String> _sel = {...widget.selected};
  String _q = '';
  late List<Region> _regions =
      widget.regions ?? RegionRepository.cached ?? const [];

  @override
  void initState() {
    super.initState();
    if (widget.regions == null) {
      RegionRepository().listOrEmpty().then((r) {
        if (mounted && r.isNotEmpty) setState(() => _regions = r);
      });
    }
  }

  void _toggleAll(Iterable<Obj> items) {
    final ids = {for (final o in items) o.id};
    setState(() =>
        ids.every(_sel.contains) ? _sel.removeAll(ids) : _sel.addAll(ids));
  }

  Widget _wholeRow(
      String title, String semantic, IconData icon, List<Obj> items) {
    final chosen = items.where((o) => _sel.contains(o.id)).length;
    return AppCheckRow(
      title: title,
      semanticLabel: semantic,
      leading: Icon(icon, size: AppSizes.iconS, color: AppColors.accentText),
      selected: chosen == items.length,
      partial: chosen > 0,
      onTap: () => _toggleAll(items),
    );
  }

  Widget _objectRow(Obj o, {bool withCity = false}) => AppCheckRow(
        title: withCity ? objectDisplayName(o) : o.name,
        selected: _sel.contains(o.id),
        onTap: () => setState(
            () => _sel.contains(o.id) ? _sel.remove(o.id) : _sel.add(o.id)),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final geo =
        groupObjectsByRegion(widget.objects, _regions, context.localeCode);
    final children = <Widget>[];
    if (geo != null) {
      for (final r in geo) {
        final w = _regionSection(l, r);
        if (w != null) children.add(w);
      }
    } else {
      final groups = groupObjectsByCity(widget.objects);
      for (final g in groups) {
        final w = _citySection(l, g);
        if (w != null) children.add(w);
      }
    }
    return AppFilterPanel(
      title: widget.title,
      searchHint: l.filterSearchHint,
      onSearch:
          widget.objects.length > 7 ? (v) => setState(() => _q = v) : null,
      resetLabel: l.filterReset,
      onReset: _sel.isEmpty ? null : () => setState(_sel.clear),
      applyLabel:
          _sel.isEmpty ? l.filterApply : l.filterApplyCount(_sel.length),
      onApply: () => Navigator.pop(context, {..._sel}),
      children: [
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(l.reqNothingFound,
                textAlign: TextAlign.center, style: AppText.footnote),
          ),
        ...children,
      ],
    );
  }

  /// Секция города (без регионов). «Весь город» — все объекты города,
  /// а не только найденные поиском.
  Widget? _citySection(AppLocalizations l, CityGroup<Obj> city) {
    final shown = [
      for (final o in city.items)
        if (objectMatches(o, _q)) o
    ];
    if (shown.isEmpty) return null;
    final cityName = city.city.isEmpty ? l.cityNone : city.city;
    return AppPanelGroup(
      header: l.cityCount(cityName, city.items.length),
      children: [
        if (city.city.isNotEmpty && city.items.length > 1)
          _wholeRow(l.filterCityAll, '${l.filterCityAll}: ${city.city}',
              AppIcons.building, city.items),
        for (final o in shown) _objectRow(o),
      ],
    );
  }

  /// Секция региона: «Весь регион», по странам «Вся страна», по городам
  /// «Весь город», объекты. Строки «весь …» — только там, где выбор
  /// отличается от соседней строки (больше одного объекта / страны / города).
  Widget? _regionSection(AppLocalizations l, RegionGroup r) {
    final loc = context.localeCode;
    final rows = <Widget>[];
    final regionName = r.region?.name ?? l.regionNone;
    if (r.region != null && r.count > 1) {
      rows.add(_wholeRow(l.regionWhole, '${l.regionWhole}: $regionName',
          AppIcons.map, r.objects));
    }
    final manyCountries = r.countries.length > 1;
    for (final c in r.countries) {
      final cName = c.code.isEmpty
          ? l.countryNone
          : countryLabel(c.code, loc, flag: true);
      final countryShown = <Widget>[];
      final manyCities = c.cities.length > 1;
      for (final g in c.cities) {
        final shown = [
          for (final o in g.items)
            if (objectMatches(o, _q)) o
        ];
        if (shown.isEmpty) continue;
        if (g.city.isNotEmpty && g.items.length > 1) {
          countryShown.add(_wholeRow(l.geoWholeCity(g.city),
              '${l.filterCityAll}: ${g.city}', AppIcons.building, g.items));
        }
        for (final o in shown) {
          countryShown.add(_objectRow(o, withCity: g.items.length == 1));
        }
      }
      if (countryShown.isEmpty) continue;
      if (c.code.isNotEmpty && (manyCountries || manyCities) && c.count > 1) {
        rows.add(_wholeRow(l.geoWholeCountry(cName), l.geoWholeCountry(cName),
            AppIcons.language, c.objects));
      }
      rows.addAll(countryShown);
    }
    if (rows.isEmpty || !rows.any((w) => w is AppCheckRow)) return null;
    return AppPanelGroup(
      header: l.cityCount(regionName, r.count),
      children: rows,
    );
  }
}
