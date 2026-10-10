import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../ppr/ppr_card.dart';
import '../ppr/ppr_tab.dart';
import '../../core/l10n_ext.dart';
import '../../core/schema_compat.dart';
import '../../l10n/app_localizations.dart';
import '../directory/city.dart';
import '../directory/directory.dart';
import '../floors/floor_models.dart';
import '../floors/floor_repository.dart';
import '../floors/order_plan_link.dart';
import '../requests/order_list.dart';
import '../requests/requests.dart';
import 'equipment_form.dart';
import 'equipment_models.dart';
import 'equipment_repository.dart';

/// Карточка оборудования (шаг 16): паспорт, где стоит (помещение, этаж,
/// «Показать на плане»), планы ППР, история заявок, «Создать заявку»
/// (объект, помещение, оборудование и система — заполнены).
class AssetCardScreen extends StatefulWidget {
  const AssetCardScreen({
    super.key,
    required this.asset,
    required this.object,
    required this.places,
    required this.layers,
    required this.isManager,
  });

  final Asset asset;
  final Obj object;
  final List<Place> places;
  final List<Layer> layers;
  final bool isManager;

  @override
  State<AssetCardScreen> createState() => _AssetCardScreenState();
}

class _AssetCardScreenState extends State<AssetCardScreen> {
  final _repo = EquipmentRepo();
  late Asset _asset = widget.asset;
  OrderContext? _ctx;
  Floor? _floor;
  List<AssetPlan> _plans = const [];
  List<Map<String, dynamic>> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ctx = _ctx ?? await OrderContext.load();
      final r = await Future.wait<Object?>([
        _repo.asset(_asset.id),
        _repo.plansOf(_asset.id),
        _repo.ordersOf(_asset.id),
      ]);
      final asset = (r[0] as Asset?) ?? _asset;
      Floor? floor;
      if (asset.floorId != null) {
        try {
          floor = await FloorRepo().floor(asset.floorId!);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _asset = asset;
        _plans = r[1] as List<AssetPlan>;
        _orders = r[2] as List<Map<String, dynamic>>;
        _floor = floor;
      });
    } catch (e) {
      debugPrint('AssetCard: $e');
      if (mounted) {
        showAppMessage(context, context.l10n.assetLoadFailed,
            type: AppMessageType.error);
      }
    }
  }

  Place? get _place {
    for (final p in widget.places) {
      if (p.id == _asset.locationId) return p;
    }
    return null;
  }

  Layer? get _layer {
    for (final y in widget.layers) {
      if (y.id == _asset.layerId) return y;
    }
    return null;
  }

  Future<void> _edit() async {
    final l = context.l10n;
    final ok = await showAssetForm(context,
        objectId: widget.object.id,
        places: widget.places,
        layers: widget.layers,
        existing: _asset);
    if (ok) {
      await _load();
      if (mounted) {
        showAppMessage(context, l.assetSaved, type: AppMessageType.success);
      }
    }
  }

  Future<void> _createOrder() async {
    final ctx = _ctx;
    final company = ctx?.companyId;
    if (ctx == null || company == null) return;
    final ok = await showOrderForm(
      context: context,
      repo: ctx.repo,
      objects: ctx.objects,
      companyId: company,
      initialObjectId: widget.object.id,
      initialLocationId: _asset.locationId,
      initialAssetId: _asset.id,
      initialAssetName: _asset.name,
      initialLayerId: _asset.layerId,
    );
    if (ok == true) {
      await _load();
    }
  }

  /// Карточка плана ППР (раздел «ППР», блок C).
  Future<void> _openPlan(String planId) async {
    try {
      final data = await PprData.load();
      if (!mounted) return;
      await Navigator.push(
          context,
          appRoute((_) => PprPlanCardScreen(planId: planId, data: data),
              title: widget.asset.name));
      if (mounted) await _load();
    } catch (e) {
      debugPrint('Asset plan: $e');
      if (mounted) {
        showAppMessage(context, context.l10n.cardLoadFailed,
            type: AppMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: _asset.name,
      onRefresh: _load,
      actions: [
        if (widget.isManager)
          AppIconButton(
              icon: AppIcons.edit, label: l.assetEdit, onPressed: _edit),
      ],
      bottomBar: _ctx == null
          ? null
          : BottomActionBar(
              child: AppButton.primary(
                  icon: AppIcons.add,
                  label: l.assetCreateOrder,
                  onPressed: _createOrder)),
      slivers: [
        SliverContent(sliver: SliverList.list(children: _content(l))),
        const SliverBottomInset(),
      ],
    );
  }

  List<Widget> _content(AppLocalizations l) {
    final locale = context.localeCode;
    final none = l.commonNotSpecified;
    final noRegistry = SchemaCompat.has('0015') == false;
    final place = _place;
    final ctx = _ctx;
    return [
      AppGroup(
        header: l.assetCardPassport,
        footer: noRegistry ? l.migrationNeeded('0015') : null,
        children: [
          AppRow(
              leading: LeadingIcon(assetIcon(_asset.kind, _asset.category)),
              title: l.assetFieldSystem,
              value: _layer?.label(locale) ?? none,
              chevron: false),
          AppRow(
              title: l.assetFieldInventory,
              value: _asset.inventoryNo ?? none,
              chevron: false),
          AppRow(
              title: l.assetFieldManufacturer,
              value: _asset.manufacturer ?? none,
              chevron: false),
          AppRow(
              title: l.assetFieldModel,
              value: _asset.model ?? none,
              chevron: false),
          AppRow(
              title: l.assetFieldSerial,
              value: _asset.serialNo ?? none,
              chevron: false),
          AppRow(
              title: l.assetFieldInstalled,
              value: _asset.installedAt == null
                  ? none
                  : assetDate(context, _asset.installedAt!),
              chevron: false),
        ],
      ),
      AppGroup(header: l.assetCardWhere, children: [
        AppRow(
            leading: const LeadingIcon(AppIcons.building),
            title: l.assetCardObject,
            value: objectDisplayName(widget.object),
            chevron: false),
        AppRow(
            leading: const LeadingIcon.neutral(AppIcons.room),
            title: l.assetFieldRoom,
            value: place?.label ?? none,
            chevron: false),
        if (_floor != null)
          AppRow(
              leading: const LeadingIcon.neutral(AppIcons.floors),
              title: l.assetCardFloor,
              value: _floor!.name,
              chevron: false),
      ]),
      OrderPlanLink(
        orderId: '',
        objectId: widget.object.id,
        locationId: _asset.locationId,
        assetId: _asset.id,
      ),
      if (SchemaCompat.has('0015') != false)
        AppGroup(header: l.assetCardPlans, children: [
          if (_plans.isEmpty)
            AppRow(
                title: l.assetCardPlansEmpty,
                titleStyle: AppText.callout,
                chevron: false)
          else
            for (final p in _plans)
              AppRow(
                leading: const LeadingIcon(AppIcons.repeat),
                title: p.title,
                subtitle: [
                  assetPeriodLabel(l, p.periodKind, p.periodDays),
                  if (!p.active) l.assetPlanPaused,
                ].join(' · '),
                onTap: () => _openPlan(p.id),
              ),
        ]),
      AppGroup(header: l.assetCardOrders(_orders.length), children: [
        if (_orders.isEmpty)
          AppRow(
              title: l.assetCardOrdersEmpty,
              titleStyle: AppText.callout,
              chevron: false)
        else
          for (final r in _orders)
            AppRow(
              leading: PriorityDot((r['priority'] ?? 'normal') as String),
              title: (r['title'] ?? '') as String,
              subtitle: l.dateTime(DateTime.parse('${r['created_at']}')),
              trailing: StatusPill((r['status'] ?? 'new') as String),
              onTap: ctx == null
                  ? null
                  : () async {
                      await ctx.open(context, r);
                      if (mounted) await _load();
                    },
            ),
      ]),
    ];
  }
}
