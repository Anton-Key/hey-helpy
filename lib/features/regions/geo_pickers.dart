import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/directory.dart';
import 'countries.dart';
import 'name_match.dart';
import 'region.dart';
import 'region_flows.dart';

/// Шторка со списком и поиском: высота — до 75 % экрана.
class _ListSheet extends StatelessWidget {
  const _ListSheet(
      {required this.title, required this.search, required this.children});
  final String title;
  final Widget? search;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.75;
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(title: title),
            if (search != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.screen, 0, AppSpace.screen, AppSpace.s),
                child: search,
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.xl),
                children: children,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Выбор страны из справочника ISO (поиск по-русски, по-английски и по
/// коду). Возвращает код; '' — «не указана»; null — закрыли.
Future<String?> showCountryPicker(BuildContext context, {String? selected}) {
  return showAppSheet<String>(
    context: context,
    builder: (ctx) => _CountryPicker(selected: selected),
  );
}

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({this.selected});
  final String? selected;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final loc = context.localeCode;
    final list = searchCountries(_q, loc);
    return _ListSheet(
      title: l.countryTitle,
      search: AppSearchField(
          hint: l.countrySearchHint,
          autofocus: true,
          onChanged: (v) => setState(() => _q = v)),
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          if (_q.isEmpty)
            AppCheckRow(
                title: l.countryNone,
                selected: (widget.selected ?? '').isEmpty,
                onTap: () => Navigator.pop(context, '')),
          for (final c in list)
            AppCheckRow(
              title: '${c.flag} ${c.name(loc)}',
              subtitle: c.code,
              selected: c.code == widget.selected,
              onTap: () => Navigator.pop(context, c.code),
            ),
        ]),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Text(l.countryNotFound,
                textAlign: TextAlign.center, style: AppText.footnote),
          ),
      ],
    );
  }
}

/// Результат выбора региона: [region] null — «Не указан».
class RegionChoice {
  const RegionChoice(this.region);
  final Region? region;
}

/// Выбор региона из списка компании; менеджер может создать новый
/// («+ Новый регион») — через проверку похожих названий. null — закрыли.
Future<RegionChoice?> showRegionPicker(
  BuildContext context, {
  required List<Region> regions,
  required Map<String, int> counts,
  String? selectedId,
  String? companyId,
  bool canCreate = false,
}) {
  final l = context.l10n;
  return showAppSheet<RegionChoice>(
    context: context,
    builder: (ctx) => _ListSheet(
      title: l.regionPickTitle,
      search: null,
      children: [
        AppGroup(margin: EdgeInsets.zero, children: [
          AppCheckRow(
              title: l.regionNotSet,
              selected: selectedId == null,
              onTap: () => Navigator.pop(ctx, const RegionChoice(null))),
          for (final r in sortRegions(regions))
            AppCheckRow(
              title: r.name,
              subtitle: l.objectsCount(counts[r.id] ?? 0),
              selected: r.id == selectedId,
              onTap: () => Navigator.pop(ctx, RegionChoice(r)),
            ),
          if (canCreate && companyId != null)
            AppRow(
              leading: const LeadingIcon(AppIcons.add),
              title: l.regionAddRow,
              chevron: false,
              onTap: () async {
                final name = await askRegionName(ctx, title: l.regionAdd);
                if (name == null || !ctx.mounted) return;
                final r = await createRegionChecked(ctx,
                    name: name,
                    regions: regions,
                    counts: counts,
                    companyId: companyId);
                if (r != null && ctx.mounted) {
                  Navigator.pop(ctx, RegionChoice(r));
                }
              },
            ),
        ]),
      ],
    ),
  );
}

/// Города компании в стране [countryCode] (без учёта регистра, по алфавиту);
/// [countryCode] null / '' — все города.
List<String> companyCities(Iterable<Obj> objects, String? countryCode,
    {String? exceptObjectId}) {
  final byKey = <String, String>{};
  for (final o in objects) {
    if (o.id == exceptObjectId) continue;
    if ((countryCode ?? '').isNotEmpty &&
        (o.countryCode ?? '').toUpperCase() != countryCode!.toUpperCase()) {
      continue;
    }
    final c = o.cityName.trim();
    if (c.isNotEmpty) byKey.putIfAbsent(normalizeName(c), () => c);
  }
  return byKey.values.toList()
    ..sort((a, b) => normalizeName(a).compareTo(normalizeName(b)));
}

/// Правка страны, города и региона объекта (только менеджер, шаг 16).
/// Возвращает true, если сохранили.
Future<bool?> showObjectGeoSheet(
  BuildContext context, {
  required Obj object,
  required List<Obj> allObjects,
  required List<Region> regions,
  required String? companyId,
}) {
  return showAppSheet<bool>(
    context: context,
    builder: (ctx) => _ObjectGeoSheet(
        object: object,
        allObjects: allObjects,
        regions: regions,
        companyId: companyId),
  );
}

class _ObjectGeoSheet extends StatefulWidget {
  const _ObjectGeoSheet(
      {required this.object,
      required this.allObjects,
      required this.regions,
      required this.companyId});
  final Obj object;
  final List<Obj> allObjects;
  final List<Region> regions;
  final String? companyId;

  @override
  State<_ObjectGeoSheet> createState() => _ObjectGeoSheetState();
}

class _ObjectGeoSheetState extends State<_ObjectGeoSheet> {
  late String? _country = widget.object.countryCode;
  // По умолчанию — город из адреса (если поле города пустое).
  late final _city = TextEditingController(text: widget.object.cityName);
  late List<Region> _regions = widget.regions;
  late String? _regionId = widget.object.regionId;
  bool _saving = false;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Map<String, int> get _counts =>
      regionObjectCounts(widget.allObjects, (Obj o) => o.regionId);

  Future<void> _pickCountry() async {
    final c = await showCountryPicker(context, selected: _country);
    if (c != null && mounted) {
      setState(() => _country = c.isEmpty ? null : c);
    }
  }

  Future<void> _pickRegion() async {
    final r = await showRegionPicker(context,
        regions: _regions,
        counts: _counts,
        selectedId: _regionId,
        companyId: widget.companyId,
        canCreate: true);
    if (r == null || !mounted) return;
    final region = r.region;
    setState(() {
      if (region != null && !_regions.any((x) => x.id == region.id)) {
        _regions = [..._regions, region];
      }
      _regionId = region?.id;
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    var city = _city.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (city.isNotEmpty) {
      final known = companyCities(widget.allObjects, _country,
          exceptObjectId: widget.object.id);
      final exact = known
          .where((c) => normalizeName(c) == normalizeName(city))
          .firstOrNull;
      if (exact != null) {
        city = exact; // «москва» → «Москва», как у остальных объектов
      } else {
        final similar = findSimilar(city, known, (String c) => c);
        if (similar != null) {
          final use = await askUseSimilar(context,
              title: l.geoCitySimilarTitle,
              text: l.geoCitySimilar(similar),
              useLabel: l.regionUseExisting(similar),
              anywayLabel: l.geoCityKeep(city));
          if (use == null || !mounted) return;
          if (use) city = similar;
        }
      }
    }
    setState(() => _saving = true);
    try {
      await RegionRepository().setObjectGeo(widget.object.id,
          countryCode: _country, city: city, regionId: _regionId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('setObjectGeo: $e');
      if (mounted) {
        setState(() => _saving = false);
        showAppMessage(context, l.saveFailed, type: AppMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final loc = context.localeCode;
    final suggestions = companyCities(widget.allObjects, _country);
    final region = _regions.where((r) => r.id == _regionId).firstOrNull;
    return Padding(
      padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
            title: l.geoEditTitle,
            doneLabel: l.commonSave,
            doneLoading: _saving,
            onDone: _saving ? null : _save,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppGroup(children: [
                    AppRow(
                      leading: const LeadingIcon(AppIcons.language),
                      title: l.countryTitle,
                      value: _country == null
                          ? l.countryNone
                          : countryLabel(_country, loc),
                      onTap: _pickCountry,
                    ),
                    AppRow(
                      leading: const LeadingIcon(AppIcons.map),
                      title: l.regionPickTitle,
                      value: region?.name ?? l.regionNotSet,
                      onTap: _pickRegion,
                    ),
                  ]),
                  SectionHeader(l.geoCity),
                  TextField(
                    controller: _city,
                    maxLength: 100,
                    decoration: InputDecoration(hintText: l.geoCityHint),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    SectionHeader(l.geoCitySuggestions),
                    Wrap(
                      spacing: AppSpace.s,
                      runSpacing: AppSpace.s,
                      children: [
                        for (final c in suggestions)
                          AppChip(
                            label: c,
                            selected:
                                normalizeName(c) == normalizeName(_city.text),
                            onTap: () => setState(() => _city.text = c),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
