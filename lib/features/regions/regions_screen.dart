import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/directory.dart';
import 'region.dart';
import 'region_flows.dart';

/// «Моя компания» → «Регионы» (шаг 16): один общий список регионов
/// компании. Менеджер добавляет (с проверкой похожих названий),
/// переименовывает, меняет порядок, объединяет и удаляет. Остальные —
/// только смотрят. Права проверяет база (0015).
class RegionsScreen extends StatefulWidget {
  const RegionsScreen(
      {super.key, required this.isManager, required this.companyId});
  final bool isManager;
  final String? companyId;

  @override
  State<RegionsScreen> createState() => _RegionsScreenState();
}

class _RegionsScreenState extends State<RegionsScreen> {
  final _repo = RegionRepository();
  List<Region> _regions = const [];
  List<Obj> _objects = const [];
  bool _loading = true;
  bool _failed = false;
  bool _noMigration = false;

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
      final r =
          await Future.wait<Object>([_repo.list(), DirectoryRepo().objects()]);
      if (!mounted) return;
      setState(() {
        _regions = r[0] as List<Region>;
        _objects = r[1] as List<Obj>;
        _loading = false;
        _noMigration = false;
      });
    } on MigrationMissing {
      if (mounted) {
        setState(() {
          _loading = false;
          _noMigration = true;
        });
      }
    } catch (e) {
      debugPrint('Regions: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Map<String, int> get _counts =>
      regionObjectCounts(_objects, (Obj o) => o.regionId);

  void _msg(String m, {AppMessageType type = AppMessageType.success}) {
    if (mounted) showAppMessage(context, m, type: type);
  }

  Future<void> _add() async {
    final l = context.l10n;
    final cid = widget.companyId;
    if (cid == null) return;
    final name = await askRegionName(context, title: l.regionAdd);
    if (name == null || !mounted) return;
    final before = {for (final r in _regions) r.id};
    final r = await createRegionChecked(context,
        name: name,
        regions: _regions,
        counts: _counts,
        companyId: cid,
        repo: _repo);
    if (r != null && !before.contains(r.id)) _msg(l.regionCreated);
    await _load();
  }

  Future<void> _rename(Region r) async {
    final l = context.l10n;
    final name =
        await askRegionName(context, title: l.regionRename, initial: r.name);
    if (name == null || !mounted) return;
    final ok = await renameRegionChecked(context,
        region: r, name: name, regions: _regions, counts: _counts, repo: _repo);
    if (ok) _msg(l.regionRenamed);
    await _load();
  }

  Future<void> _move(Region r, int delta) async {
    final failed = context.l10n.saveFailed;
    final list = [..._regions];
    final i = list.indexWhere((x) => x.id == r.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    setState(() => _regions = list);
    try {
      await _repo.reorder(list);
    } catch (e) {
      debugPrint('reorder: $e');
      _msg(failed, type: AppMessageType.error);
    }
    await _load();
  }

  Future<void> _merge(Region from) async {
    final l = context.l10n;
    final others = [
      for (final r in _regions)
        if (r.id != from.id) r
    ];
    if (others.isEmpty) {
      _msg(l.regionMergeNoOther, type: AppMessageType.info);
      return;
    }
    final counts = _counts;
    final into = await showAppSheet<Region>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetHeader(title: l.regionMergePick(from.name)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.xl),
              child: AppGroup(margin: EdgeInsets.zero, children: [
                for (final r in others)
                  AppRow(
                      leading: const LeadingIcon(AppIcons.map),
                      title: r.name,
                      subtitle: l.objectsCount(counts[r.id] ?? 0),
                      chevron: false,
                      onTap: () => Navigator.pop(ctx, r)),
              ]),
            ),
          ),
        ]),
      ),
    );
    if (into == null || !mounted) return;
    final plan = planRegionMerge(from, into, _objects,
        regionOf: (Obj o) => o.regionId, idOf: (Obj o) => o.id);
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.regionMergeConfirmTitle,
      message: l.regionMergeConfirm(
          l.objectsCount(plan.count), into.name, from.name),
      actions: [
        AppDialogAction(
            MaterialLocalizations.of(context).cancelButtonLabel, false),
        AppDialogAction(l.regionMergeAction, true, primary: true),
      ],
    );
    if (ok != true) return;
    try {
      await _repo.merge(plan);
      _msg(l.regionMerged);
    } catch (e) {
      debugPrint('merge: $e');
      _msg(l.saveFailed, type: AppMessageType.error);
    }
    await _load();
  }

  Future<void> _delete(Region r) async {
    final l = context.l10n;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.regionDeleteConfirmTitle(r.name),
      message: l.regionDeleteConfirm(l.objectsCount(_counts[r.id] ?? 0)),
      actions: [
        AppDialogAction(
            MaterialLocalizations.of(context).cancelButtonLabel, false),
        AppDialogAction(l.regionDelete, true, destructive: true),
      ],
    );
    if (ok != true) return;
    try {
      await _repo.delete(r.id);
      _msg(l.regionDeleted);
    } catch (e) {
      debugPrint('delete region: $e');
      _msg(l.saveFailed, type: AppMessageType.error);
    }
    await _load();
  }

  Future<void> _menu(BuildContext anchor, Region r, int index) async {
    final l = context.l10n;
    final a = await showFilterPicker<int>(
      context: anchor,
      builder: (ctx) => AppGroup(margin: EdgeInsets.zero, children: [
        AppRow(
            leading: const LeadingIcon(AppIcons.edit),
            title: l.regionRename,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 0)),
        if (index > 0)
          AppRow(
              leading: const LeadingIcon(AppIcons.moveUp),
              title: l.regionMoveUp,
              chevron: false,
              onTap: () => Navigator.pop(ctx, 1)),
        if (index < _regions.length - 1)
          AppRow(
              leading: const LeadingIcon(AppIcons.moveDown),
              title: l.regionMoveDown,
              chevron: false,
              onTap: () => Navigator.pop(ctx, 2)),
        AppRow(
            leading: const LeadingIcon(AppIcons.swap),
            title: l.regionMerge,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 3)),
        AppRow(
            leading: const LeadingIcon.danger(AppIcons.delete),
            title: l.regionDelete,
            destructive: true,
            chevron: false,
            onTap: () => Navigator.pop(ctx, 4)),
      ]),
    );
    switch (a) {
      case 0:
        await _rename(r);
      case 1:
        await _move(r, -1);
      case 2:
        await _move(r, 1);
      case 3:
        await _merge(r);
      case 4:
        await _delete(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: l.regionsTitle,
      onRefresh: _load,
      actions: [
        regionInfoButton(context),
        if (widget.isManager && !_noMigration)
          AppIconButton(
              icon: AppIcons.add, label: l.regionAdd, onPressed: _add),
      ],
      slivers: [_body(l), const SliverBottomInset()],
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading && _regions.isEmpty) {
      return const SliverFillRemaining(
          hasScrollBody: false, child: AppLoader());
    }
    if (_noMigration) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              icon: AppIcons.map, text: l.migrationNeeded('0015')));
    }
    if (_failed) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              text: l.regionsLoadFailed,
              error: true,
              actionLabel: l.commonRetry,
              onAction: _load));
    }
    if (_regions.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              icon: AppIcons.map,
              text: l.regionsEmpty,
              actionLabel: widget.isManager ? l.regionAdd : null,
              onAction: widget.isManager ? _add : null));
    }
    final counts = _counts;
    return SliverContent(
      sliver: SliverList.list(children: [
        AppGroup(
          footer: widget.isManager ? null : l.regionOnlyManager,
          children: [
            for (var i = 0; i < _regions.length; i++)
              AppRow(
                leading: const LeadingIcon(AppIcons.map),
                title: _regions[i].name,
                subtitle: l.objectsCount(counts[_regions[i].id] ?? 0),
                chevron: false,
                trailing: widget.isManager
                    ? Builder(
                        builder: (anchor) => AppIconButton(
                            icon: AppIcons.more,
                            label: l.regionActions(_regions[i].name),
                            onPressed: () => _menu(anchor, _regions[i], i)))
                    : null,
              ),
          ],
        ),
      ]),
    );
  }
}
