import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'city.dart';
import 'directory.dart';

/// Подпись выбранных объектов (таблетка фильтра заявок, фильтр отчётов):
/// один — «Москва · Офис 3»; ровно весь город (2+ объекта) — «Москва (5)»;
/// несколько — «Москва · Офис 1 +2». null — ничего не выбрано.
String? objectsSelectionLabel(
    AppLocalizations l, Set<String> ids, List<Obj> objects) {
  if (ids.isEmpty) return null;
  final groups = groupObjectsByCity(objects);
  for (final g in groups) {
    if (g.city.isEmpty || g.items.length < 2) continue;
    final cityIds = {for (final o in g.items) o.id};
    if (cityIds.length == ids.length && cityIds.containsAll(ids)) {
      return l.filterCityWhole(g.city, g.items.length);
    }
  }
  Obj? first;
  for (final g in groups) {
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

/// Подходит ли объект под поиск: название, город, адрес (все слова).
bool objectMatches(Obj o, String query) {
  String norm(String s) => s.toLowerCase().replaceAll('ё', 'е');
  final q = norm(query.trim());
  if (q.isEmpty) return true;
  final hay = norm('${o.name} ${o.address ?? ''}');
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// Окно выбора объектов: секции по городам («МОСКВА · 5»), в начале секции —
/// «Весь город» (галочка — выбраны все объекты города, минус — часть),
/// поиск по названию и городу. Возвращает выбранные id (Navigator.pop)
/// или null (закрыли).
class ObjectPickerPanel extends StatefulWidget {
  const ObjectPickerPanel(
      {super.key,
      required this.title,
      required this.objects,
      required this.selected});
  final String title;
  final List<Obj> objects;
  final Set<String> selected;

  @override
  State<ObjectPickerPanel> createState() => _ObjectPickerPanelState();
}

class _ObjectPickerPanelState extends State<ObjectPickerPanel> {
  late final Set<String> _sel = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final groups = groupObjectsByCity(widget.objects);
    final shown = [
      for (final g in groups)
        if (g.items.any((o) => objectMatches(o, _q)))
          CityGroup(g.city, [
            for (final o in g.items)
              if (objectMatches(o, _q)) o
          ]),
    ];
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
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(l.reqNothingFound,
                textAlign: TextAlign.center, style: AppText.footnote),
          ),
        for (final g in shown) _section(l, g, groups),
      ],
    );
  }

  Widget _section(
      AppLocalizations l, CityGroup<Obj> shown, List<CityGroup<Obj>> all) {
    // «Весь город» — все объекты города, а не только найденные поиском.
    final city = all.firstWhere((g) => g.city == shown.city);
    final ids = {for (final o in city.items) o.id};
    final chosen = ids.where(_sel.contains).length;
    final cityName = shown.city.isEmpty ? l.cityNone : shown.city;
    return AppPanelGroup(
      header: l.cityCount(cityName, city.items.length),
      children: [
        if (shown.city.isNotEmpty && city.items.length > 1)
          AppCheckRow(
            title: l.filterCityAll,
            semanticLabel: '${l.filterCityAll}: ${shown.city}',
            leading: const Icon(AppIcons.building,
                size: AppSizes.iconS, color: AppColors.accentText),
            selected: chosen == ids.length,
            partial: chosen > 0,
            onTap: () => setState(() =>
                chosen == ids.length ? _sel.removeAll(ids) : _sel.addAll(ids)),
          ),
        for (final o in shown.items)
          AppCheckRow(
            title: o.name,
            selected: _sel.contains(o.id),
            onTap: () => setState(
                () => _sel.contains(o.id) ? _sel.remove(o.id) : _sel.add(o.id)),
          ),
      ],
    );
  }
}
