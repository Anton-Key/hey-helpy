import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../equipment/asset_card.dart';
import '../equipment/equipment_repository.dart';
import '../requests/order_list.dart';
import 'system_form.dart';
import 'systems_repository.dart';
import 'systems_screen.dart';

/// Карточка системы: оборудование по объектам (→ карточка оборудования),
/// подрядчики, открытые заявки (→ список). Администратор — изменить,
/// архивировать / вернуть, удалить (только если на систему ничего не
/// ссылается — иначе база отвечает «system_in_use»).
class SystemCardScreen extends StatefulWidget {
  const SystemCardScreen(
      {super.key,
      required this.layer,
      required this.companyId,
      required this.canEdit,
      required this.stats});
  final Layer layer;
  final String companyId;
  final bool canEdit;
  final SystemStats stats;

  @override
  State<SystemCardScreen> createState() => _SystemCardScreenState();
}

class _SystemCardScreenState extends State<SystemCardScreen> {
  final _repo = SystemsRepository();
  late Layer _layer = widget.layer;
  List<SystemAsset> _assets = const [];
  List<SystemContractor> _contractors = const [];
  List<Obj> _objects = const [];
  List<Layer> _layers = const [];
  bool _loading = true;
  bool _failed = false;
  bool _changed = false;

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
      final r = await Future.wait<Object>([
        _repo.assets(_layer.id),
        _repo.contractors(_layer.id),
        DirectoryRepo().objects(),
        _repo.list(),
      ]);
      if (!mounted) return;
      final layers = r[3] as List<Layer>;
      setState(() {
        _assets = r[0] as List<SystemAsset>;
        _contractors = r[1] as List<SystemContractor>;
        _objects = r[2] as List<Obj>;
        _layers = layers;
        _layer = layers.where((y) => y.id == _layer.id).firstOrNull ?? _layer;
        _loading = false;
      });
    } catch (e) {
      debugPrint('system card: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _edit() async {
    final ok = await showSystemForm(context,
        companyId: widget.companyId, existing: _layer);
    if (ok == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _archive(bool archive) async {
    final l = context.l10n;
    try {
      await _repo.setArchived(_layer.id, archive);
      _changed = true;
      await _load();
      if (mounted) {
        showAppMessage(
            context, archive ? l.systemArchivedToast : l.systemRestoredToast);
      }
    } catch (e) {
      debugPrint('system archive: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.systemSaveFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.systemDeleteTitle(_layer.label(context.localeCode)),
      message: l.systemDeleteMessage,
      actions: [
        AppDialogAction(l.actionDelete, true, destructive: true),
        AppDialogAction(l.commonCancel, false),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(_layer.id);
      if (mounted) {
        showAppMessage(context, l.systemDeletedToast);
        Navigator.pop(context, true);
      }
    } on SystemInUse {
      if (mounted) {
        showAppMessage(context, l.systemInUse, type: AppMessageType.error);
      }
    } catch (e) {
      debugPrint('system delete: ${e.runtimeType}');
      if (mounted) {
        showAppMessage(context, l.systemSaveFailed, type: AppMessageType.error);
      }
    }
  }

  Future<void> _openAsset(SystemAsset a) async {
    final obj = _objects.where((o) => o.id == a.objectId).firstOrNull;
    if (obj == null) return;
    final asset = await EquipmentRepo().asset(a.id);
    final places = await DirectoryRepo().placesOf(obj.id);
    if (asset == null || !mounted) return;
    await Navigator.push(
        context,
        appRoute(
            (_) => AssetCardScreen(
                asset: asset,
                object: obj,
                places: places,
                layers: _layers,
                isManager: true),
            title: _layer.label(context.localeCode)));
  }

  void _openOrders() {
    final l = context.l10n;
    Navigator.push(
        context,
        appRoute(
            (_) => WorkOrderListScreen(
                title: l.systemOpenOrders,
                subtitle: _layer.label(context.localeCode),
                layerId: _layer.id,
                openOnly: true),
            title: _layer.label(context.localeCode)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = _layer.label(context.localeCode);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: AppScaffold(
        title: name,
        eyebrow: l.systemsTitle,
        onRefresh: _load,
        actions: [
          if (widget.canEdit)
            AppIconButton(
                icon: AppIcons.edit, label: l.systemEdit, onPressed: _edit),
        ],
        slivers: [
          if (_loading && _assets.isEmpty && _contractors.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
          else if (_failed)
            SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                    text: l.systemsLoadFailed,
                    error: true,
                    actionLabel: l.commonRetry,
                    onAction: _load))
          else
            SliverContent(sliver: SliverList.list(children: _content())),
          const SliverBottomInset(),
        ],
      ),
    );
  }

  List<Widget> _content() {
    final l = context.l10n;
    final s = widget.stats;
    // Оборудование — по объектам (объект с городом: «Москва · Офис 1»).
    final byObject = <String?, List<SystemAsset>>{};
    for (final a in _assets) {
      (byObject[a.objectId] ??= []).add(a);
    }
    final objectsSorted = [
      for (final g in groupObjectsByCity(_objects))
        for (final o in g.items)
          if (byObject.containsKey(o.id)) o
    ];
    return [
      AppGroup(children: [
        AppRow(
          leading: SystemTile(_layer),
          title: _layer.label(context.localeCode),
          subtitle: _layer.archived ? l.systemArchivedBadge : null,
          chevron: false,
        ),
        AppRow(
            leading: const LeadingIcon.neutral(AppIcons.wrench),
            title: l.systemAssets,
            value: '${_assets.length}'),
        AppRow(
            leading: const LeadingIcon.neutral(AppIcons.list),
            title: l.systemOpenOrders,
            value: '${s.openOrders}',
            onTap: s.openOrders == 0 ? null : _openOrders),
        AppRow(
            leading: const LeadingIcon.neutral(AppIcons.contractor),
            title: l.tabContractors,
            value: '${_contractors.length}'),
      ]),
      if (_contractors.isNotEmpty)
        AppGroup(header: l.tabContractors, children: [
          for (final c in _contractors)
            AppRow(
              leading: InitialsTile(c.name),
              title: c.name,
              subtitle: c.objects == 0
                  ? l.systemContractorAll
                  : l.objectsCount(c.objects),
              chevron: false,
            ),
        ]),
      if (_assets.isEmpty)
        AppGroup(
            header: l.systemAssets,
            footer: l.systemNoAssets,
            children: const [])
      else
        for (final o in objectsSorted)
          AppGroup(
            header: '${objectDisplayName(o)} · ${byObject[o.id]!.length}',
            separatorInset: AppSpace.separatorInsetIcon,
            children: [
              for (final a in byObject[o.id]!)
                AppRow(
                  leading: LeadingIcon(systemIcon(_layer.icon, _layer.name)),
                  title: a.name,
                  subtitle: a.placeName,
                  onTap: () => _openAsset(a),
                ),
            ],
          ),
      if (widget.canEdit) ...[
        const SizedBox(height: AppSpace.l),
        AppGroup(children: [
          AppRow(
            leading: LeadingIcon.neutral(
                _layer.archived ? AppIcons.unarchive : AppIcons.archive),
            title: _layer.archived ? l.systemRestore : l.systemArchive,
            subtitle: _layer.archived ? null : l.systemArchiveHint,
            subtitleMaxLines: 2,
            chevron: false,
            onTap: () => _archive(!_layer.archived),
          ),
          AppRow(
            leading: const LeadingIcon.danger(AppIcons.delete),
            title: l.actionDelete,
            subtitle: l.systemDeleteHint,
            subtitleMaxLines: 2,
            chevron: false,
            onTap: _delete,
          ),
        ]),
      ],
    ];
  }
}
