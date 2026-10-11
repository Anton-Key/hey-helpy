import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import '../directory/object_picker.dart';
import '../regions/region.dart';
import 'zone_logic.dart';
import 'zone_repository.dart';

/// Справочники редактора зон: системы, объекты, регионы, названия этажей
/// и оборудования из правил.
class ZoneRefs {
  ZoneRefs({
    required this.layers,
    required this.objects,
    required this.regions,
    this.floorNames = const {},
    this.floorObject = const {},
    this.assetNames = const {},
    this.assetObject = const {},
  });

  final List<Layer> layers;
  final List<Obj> objects;
  final List<Region> regions;
  final Map<String, String> floorNames;
  final Map<String, String> floorObject;
  final Map<String, String> assetNames;
  final Map<String, String> assetObject;

  static Future<ZoneRefs> load(Iterable<ZoneRow> rows,
      {ZoneRepository? repo}) async {
    final dir = DirectoryRepo();
    final r = await Future.wait<Object>([
      dir.layers().catchError((_) => const <Layer>[]),
      dir.objects(),
      RegionRepository().listOrEmpty(),
    ]);
    final names =
        await (repo ?? ZoneRepository()).placeNames(rows).catchError((_) => (
              floorNames: <String, String>{},
              floorObject: <String, String>{},
              assetNames: <String, String>{},
              assetObject: <String, String>{},
            ));
    return ZoneRefs(
      layers: r[0] as List<Layer>,
      objects: r[1] as List<Obj>,
      regions: r[2] as List<Region>,
      floorNames: names.floorNames,
      floorObject: names.floorObject,
      assetNames: names.assetNames,
      assetObject: names.assetObject,
    );
  }

  ZoneNames names(AppLocalizations l) => ZoneNames(
        locale: l.localeName,
        allSystems: l.zoneAllSystems,
        wholeCompany: l.zoneWholeCompany,
        objectsCount: l.objectsCount,
        layers: layers,
        regions: regions,
        objects: objects,
        floorNames: floorNames,
        floorObject: floorObject,
        assetNames: assetNames,
        assetObject: assetObject,
      );
}

/// Подсказка ⓘ «Зона доступа».
Future<void> showZoneInfo(BuildContext context) {
  final l = context.l10n;
  return showAppInfo(
      context: context,
      title: l.zoneInfoTitle,
      lines: [l.zoneInfo1, l.zoneInfo2, l.zoneInfo3, l.zoneInfo4],
      closeLabel: l.commonGotIt);
}

/// Подсказка ⓘ «Бригады».
Future<void> showCrewInfo(BuildContext context) {
  final l = context.l10n;
  return showAppInfo(
      context: context,
      title: l.crewInfoTitle,
      lines: [l.crewInfo1, l.crewInfo2, l.crewInfo3],
      closeLabel: l.commonGotIt);
}

/// Правила списком: сводка словами, нажатие — изменить, «Добавить правило».
/// Общий для зоны менеджера и зоны бригады.
class ZoneRulesGroup extends StatelessWidget {
  const ZoneRulesGroup({
    super.key,
    required this.rules,
    required this.refs,
    required this.onChanged,
    this.header,
    this.footer,
    this.enabled = true,
  });

  final List<ZoneRule> rules;
  final ZoneRefs refs;
  final ValueChanged<List<ZoneRule>> onChanged;
  final String? header;
  final String? footer;
  final bool enabled;

  Future<void> _edit(BuildContext context, int? index) async {
    final res = await Navigator.push<_RuleResult>(
        context,
        appRoute(
            (_) => ZoneRuleEditorScreen(
                rule: index == null ? const ZoneRule() : rules[index],
                refs: refs,
                canDelete: index != null),
            title: context.l10n.zoneTitle));
    if (res == null) return;
    final next = [...rules];
    if (res.deleted) {
      if (index != null) next.removeAt(index);
    } else if (index == null) {
      next.add(res.rule!);
    } else {
      next[index] = res.rule!;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = refs.names(l);
    return AppGroup(
      header: header ?? l.zoneRules,
      footer: footer ?? l.zoneRulesFooter,
      children: [
        if (rules.isEmpty)
          AppRow(
              title: l.zoneRulesEmpty,
              titleStyle: AppText.callout,
              chevron: false),
        for (final (i, r) in rules.indexed)
          AppRow(
            leading: const LeadingIcon(AppIcons.lock),
            title: systemsText(r.layerIds, n),
            subtitle: ruleSummary(r, n).split(' · ').skip(1).join(' · '),
            subtitleMaxLines: 3,
            onTap: enabled ? () => _edit(context, i) : null,
          ),
        if (enabled)
          AppRow(
            leading: const LeadingIcon(AppIcons.add),
            title: l.zoneRuleAdd,
            chevron: false,
            onTap: () => _edit(context, null),
          ),
      ],
    );
  }
}

class _RuleResult {
  const _RuleResult.save(this.rule) : deleted = false;
  const _RuleResult.delete()
      : rule = null,
        deleted = true;
  final ZoneRule? rule;
  final bool deleted;
}

/// Одно правило: системы (чипы, «Все системы») × места (окно выбора
/// объектов: регион / страна / город / объект; объект можно уточнить до
/// этажа или оборудования).
class ZoneRuleEditorScreen extends StatefulWidget {
  const ZoneRuleEditorScreen(
      {super.key,
      required this.rule,
      required this.refs,
      this.canDelete = false});
  final ZoneRule rule;
  final ZoneRefs refs;
  final bool canDelete;

  @override
  State<ZoneRuleEditorScreen> createState() => _ZoneRuleEditorScreenState();
}

class _ZoneRuleEditorScreenState extends State<ZoneRuleEditorScreen> {
  late Set<String> _layers = {...widget.rule.layerIds};
  late List<ZonePlace> _places = [...widget.rule.places];
  late final ZoneRefs _refs = ZoneRefs(
    layers: widget.refs.layers,
    objects: widget.refs.objects,
    regions: widget.refs.regions,
    floorNames: {...widget.refs.floorNames},
    floorObject: {...widget.refs.floorObject},
    assetNames: {...widget.refs.assetNames},
    assetObject: {...widget.refs.assetObject},
  );

  Future<void> _pickPlaces() async {
    final l = context.l10n;
    final kept = [
      for (final p in _places)
        if (p.scope == ZoneScope.floor || p.scope == ZoneScope.asset) p
    ];
    final ids = await showAppSidePanel<Set<String>>(
      context: context,
      builder: (_) => ObjectPickerPanel(
        title: l.zoneRulePlaces,
        objects: _refs.objects,
        selected: selectionFromPlaces(_places, _refs.objects),
        regions: _refs.regions,
      ),
    );
    if (ids == null || !mounted) return;
    setState(() => _places = [
          ...placesFromSelection(ids, _refs.objects, _refs.regions),
          ...kept,
        ]);
  }

  Future<void> _refine(int index) async {
    final l = context.l10n;
    final p = _places[index];
    final objectId = p.scope == ZoneScope.object
        ? p.ref
        : (p.scope == ZoneScope.floor
            ? _refs.floorObject[p.ref]
            : _refs.assetObject[p.ref]);
    if (objectId == null) return;
    final parts = await ZoneRepository().partsOf(objectId).catchError((_) => (
          floors: <({String id, String name})>[],
          assets: <({String id, String name})>[],
        ));
    if (!mounted) return;
    final chosen = await showAppSheet<ZonePlace>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
              title: l.zoneRuleRefineTitle,
              doneLabel: l.commonCancel,
              onDone: () => Navigator.pop(ctx)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: Column(children: [
                AppGroup(children: [
                  AppCheckRow(
                    title: l.zoneRuleWholeObject,
                    selected: p.scope == ZoneScope.object,
                    onTap: () => Navigator.pop(
                        ctx, ZonePlace(ZoneScope.object, objectId)),
                  ),
                ]),
                if (parts.floors.isNotEmpty)
                  AppGroup(header: l.zoneRuleFloors, children: [
                    for (final f in parts.floors)
                      AppCheckRow(
                        title: f.name,
                        selected: p == ZonePlace(ZoneScope.floor, f.id),
                        onTap: () {
                          _refs.floorNames[f.id] = f.name;
                          _refs.floorObject[f.id] = objectId;
                          Navigator.pop(ctx, ZonePlace(ZoneScope.floor, f.id));
                        },
                      ),
                  ]),
                if (parts.assets.isNotEmpty)
                  AppGroup(header: l.zoneRuleAssets, children: [
                    for (final a in parts.assets)
                      AppCheckRow(
                        title: a.name,
                        selected: p == ZonePlace(ZoneScope.asset, a.id),
                        onTap: () {
                          _refs.assetNames[a.id] = a.name;
                          _refs.assetObject[a.id] = objectId;
                          Navigator.pop(ctx, ZonePlace(ZoneScope.asset, a.id));
                        },
                      ),
                  ]),
              ]),
            ),
          ),
        ]),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _places[index] = chosen);
  }

  void _done() {
    if (_places.isEmpty) {
      showAppMessage(context, context.l10n.zoneRuleEmpty,
          type: AppMessageType.error);
      return;
    }
    Navigator.pop(context,
        _RuleResult.save(ZoneRule(layerIds: _layers, places: _places)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = _refs.names(l);
    return AppScaffold(
      title: l.zoneRuleTitle,
      large: false,
      actions: [
        AppIconButton(
            icon: AppIcons.info,
            label: l.zoneInfoTitle,
            onPressed: () => showZoneInfo(context)),
      ],
      bottomBar: BottomActionBar(
        child: AppButton.primary(label: l.commonSave, onPressed: _done),
      ),
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            SectionHeader(l.zoneRuleSystems),
            Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
              AppChip(
                  label: l.zoneAllSystems,
                  selected: _layers.isEmpty,
                  onTap: () => setState(() => _layers = {})),
              for (final y in _refs.layers)
                AppChip(
                  label: y.label(l.localeName),
                  selected: _layers.contains(y.id),
                  onTap: () => setState(() {
                    _layers = _layers.contains(y.id)
                        ? ({..._layers}..remove(y.id))
                        : {..._layers, y.id};
                  }),
                ),
            ]),
            const SizedBox(height: AppSpace.group),
            AppGroup(
              header: l.zoneRulePlaces,
              footer: _places.isEmpty
                  ? null
                  : ruleSummary(
                      ZoneRule(layerIds: _layers, places: _places), n),
              children: [
                for (final (i, p) in _places.indexed)
                  AppRow(
                    leading: LeadingIcon(switch (p.scope) {
                      ZoneScope.company => AppIcons.building,
                      ZoneScope.region ||
                      ZoneScope.country =>
                        AppIcons.language,
                      ZoneScope.city => AppIcons.map,
                      ZoneScope.object => AppIcons.building,
                      ZoneScope.floor => AppIcons.floors,
                      ZoneScope.asset => AppIcons.wrench,
                    }),
                    title: placeText(p, n),
                    subtitle: p.scope == ZoneScope.object ||
                            p.scope == ZoneScope.floor ||
                            p.scope == ZoneScope.asset
                        ? l.zoneRuleRefine
                        : null,
                    chevron: false,
                    trailing: AppIconButton(
                        icon: AppIcons.close,
                        label: l.filterReset,
                        size: 32,
                        onPressed: () => setState(
                            () => _places = [..._places]..removeAt(i))),
                    onTap: p.scope == ZoneScope.object ||
                            p.scope == ZoneScope.floor ||
                            p.scope == ZoneScope.asset
                        ? () => _refine(i)
                        : null,
                  ),
                AppRow(
                  leading: const LeadingIcon(AppIcons.place),
                  title: l.zoneRuleAddPlace,
                  onTap: _pickPlaces,
                ),
              ],
            ),
            if (widget.canDelete)
              AppGroup(children: [
                AppRow(
                  leading: const LeadingIcon.danger(AppIcons.delete),
                  title: l.zoneRuleDelete,
                  destructive: true,
                  chevron: false,
                  onTap: () =>
                      Navigator.pop(context, const _RuleResult.delete()),
                ),
              ]),
          ]),
        ),
      ],
    );
  }
}

/// «Моя компания» → сотрудник → «Зона доступа» (только администратор).
/// «Вся компания» (по умолчанию, строк нет) или правила; шаблоны.
/// Сохранение заменяет все зоны сотрудника — права проверяет база (0016).
class AccessZoneScreen extends StatefulWidget {
  const AccessZoneScreen(
      {super.key,
      required this.profileId,
      required this.memberName,
      required this.companyId});
  final String profileId;
  final String memberName;
  final String companyId;

  @override
  State<AccessZoneScreen> createState() => _AccessZoneScreenState();
}

class _AccessZoneScreenState extends State<AccessZoneScreen> {
  final _repo = ZoneRepository();
  ZoneRefs? _refs;
  bool _whole = true;
  List<ZoneRule> _rules = const [];
  bool _loading = true;
  bool _failed = false;
  bool _missing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await _repo.zonesOf(widget.profileId);
      final refs = await ZoneRefs.load(rows, repo: _repo);
      if (!mounted) return;
      setState(() {
        _refs = refs;
        _whole = isWholeCompany(rows);
        _rules = _whole ? const [] : groupRules(rows);
        _loading = false;
      });
    } on MigrationMissing {
      if (mounted) {
        setState(() {
          _missing = true;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AccessZone: $e');
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _template() async {
    final l = context.l10n;
    final refs = _refs;
    if (refs == null) return;
    final kind = await showAppSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(
              title: l.zoneTemplates,
              doneLabel: l.commonCancel,
              onDone: () => Navigator.pop(ctx)),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
            child: AppGroup(margin: EdgeInsets.zero, children: [
              AppRow(
                  leading: const LeadingIcon(AppIcons.building),
                  title: l.zoneTemplateCompany,
                  onTap: () => Navigator.pop(ctx, 0)),
              AppRow(
                  leading: const LeadingIcon(AppIcons.workType),
                  title: l.zoneTemplateSystem,
                  onTap: () => Navigator.pop(ctx, 1)),
              AppRow(
                  leading: const LeadingIcon(AppIcons.map),
                  title: l.zoneTemplateRegion,
                  subtitle: refs.regions.isEmpty ? l.zoneNoRegions : null,
                  onTap: refs.regions.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, 2)),
            ]),
          ),
        ]),
      ),
    );
    if (kind == null || !mounted) return;
    switch (kind) {
      case 0:
        setState(() {
          _whole = true;
          _rules = templateWholeCompany();
        });
      case 1:
        final id = await _pickOne(l.zoneTemplatePickSystem,
            [for (final y in refs.layers) (y.id, y.label(l.localeName))]);
        if (id != null) {
          setState(() {
            _whole = false;
            _rules = templateOneSystem(id);
          });
        }
      case 2:
        final id = await _pickOne(l.zoneTemplatePickRegion,
            [for (final r in sortRegions(refs.regions)) (r.id, r.name)]);
        if (id != null) {
          setState(() {
            _whole = false;
            _rules = templateRegion(id);
          });
        }
    }
  }

  Future<String?> _pickOne(String title, List<(String, String)> options) =>
      showAppSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(
                title: title,
                doneLabel: context.l10n.commonCancel,
                onDone: () => Navigator.pop(ctx)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
                child: AppGroup(margin: EdgeInsets.zero, children: [
                  for (final o in options)
                    AppRow(
                        title: o.$2,
                        chevron: false,
                        onTap: () => Navigator.pop(ctx, o.$1)),
                ]),
              ),
            ),
          ]),
        ),
      );

  Future<void> _save() async {
    final l = context.l10n;
    final rows = _whole ? const <ZoneRow>[] : rulesToRows(_rules);
    setState(() => _busy = true);
    try {
      await _repo.replaceZones(
          profileId: widget.profileId, companyId: widget.companyId, rows: rows);
      if (!mounted) return;
      showAppMessage(context, l.zoneSaved, type: AppMessageType.success);
      Navigator.pop(context, true);
    } on MigrationMissing {
      if (mounted) {
        showAppMessage(context, l.migrationNeeded('0016'),
            type: AppMessageType.error);
      }
    } catch (e) {
      debugPrint('AccessZone save: $e');
      if (mounted) {
        showAppMessage(context, l.zoneSaveDenied, type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final refs = _refs;
    final List<Widget> body;
    if (_missing) {
      body = [
        AppEmptyState(icon: AppIcons.lock, text: l.migrationNeeded('0016')),
      ];
    } else if (_loading && refs == null) {
      body = const [AppLoader()];
    } else if (_failed || refs == null) {
      body = [
        AppEmptyState(
            text: l.zoneLoadFailed,
            error: true,
            actionLabel: l.commonRetry,
            onAction: _load),
      ];
    } else {
      body = [
        AppGroup(children: [
          AppRow(
            leading: const LeadingIcon(AppIcons.building),
            title: l.zoneWholeCompany,
            subtitle: l.zoneWholeCompanyHint,
            chevron: false,
            trailing: Switch(
                value: _whole,
                onChanged: (v) => setState(() {
                      _whole = v;
                      if (v) _rules = const [];
                    })),
          ),
          AppRow(
            leading: const LeadingIcon(AppIcons.list),
            title: l.zoneTemplates,
            onTap: _template,
          ),
        ]),
        if (!_whole)
          ZoneRulesGroup(
            rules: _rules,
            refs: refs,
            onChanged: (r) => setState(() => _rules = r),
          ),
      ];
    }
    return AppScaffold(
      title: l.zoneTitle,
      eyebrow: widget.memberName,
      actions: [
        AppIconButton(
            icon: AppIcons.info,
            label: l.zoneInfoTitle,
            onPressed: () => showZoneInfo(context)),
      ],
      bottomBar: refs == null || _missing
          ? null
          : BottomActionBar(
              child: AppButton.primary(
                  label: l.commonSave,
                  loading: _busy,
                  onPressed:
                      _busy || (!_whole && _rules.isEmpty) ? null : _save),
            ),
      slivers: [
        SliverContent(sliver: SliverList.list(children: body)),
      ],
    );
  }
}
