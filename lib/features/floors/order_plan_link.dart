import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../equipment/asset_place.dart';
import '../equipment/asset_place_widgets.dart';
import '../offline/offline_logic.dart' show isNetworkError;
import '../offline/offline_service.dart';
import 'floor_models.dart';
import 'floor_repository.dart';
import 'floors_section.dart';
import 'offline_plan_screen.dart';
import 'plan_image.dart';

/// Строка «Показать на плане» в карточке заявки: если у оборудования или
/// помещения заявки есть точка на плане — превью плана и «3 этаж · 2
/// открытые заявки рядом». Нажатие — план, центрированный на маркере.
/// Ничего не показывает, если точки нет (или этажи недоступны).
class OrderPlanLink extends StatefulWidget {
  const OrderPlanLink({
    super.key,
    required this.orderId,
    required this.objectId,
    this.locationId,
    this.assetId,
    this.showMount = true,
  });

  /// Шаг 27: строка «Где именно: потолок · 2,8 м · над дверью» у
  /// оборудования (в карточке оборудования она своя — там false).
  final bool showMount;

  final String orderId;
  final String? objectId;
  final String? locationId;
  final String? assetId;

  @override
  State<OrderPlanLink> createState() => _OrderPlanLinkState();
}

class _OrderPlanLinkState extends State<OrderPlanLink> {
  PlanItem? _item;
  Floor? _floor;
  int _nearby = 0;
  MountInfo _mount = MountInfo.empty;

  /// Шаг 28: место и этаж — из предзагрузки (сети нет).
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OrderPlanLink old) {
    super.didUpdateWidget(old);
    if (old.locationId != widget.locationId || old.assetId != widget.assetId) {
      _load();
    }
  }

  Future<void> _load() async {
    final objectId = widget.objectId;
    if (objectId == null ||
        (widget.locationId == null && widget.assetId == null)) {
      return;
    }
    final repo = FloorRepo();
    try {
      // Сначала оборудование (точнее), потом помещение.
      PlanItem? item;
      if (widget.assetId != null) {
        item = await repo.assetById(widget.assetId!);
        final mount = item?.mount ?? MountInfo.empty;
        if (mounted && widget.showMount && mount != _mount) {
          setState(() => _mount = mount);
        }
      }
      if ((item == null || !item.placed) && widget.locationId != null) {
        item = await repo.placeById(widget.locationId!);
      }
      if (item == null || !item.placed || item.floorId == null) return;
      final r = await Future.wait<Object?>([
        repo.floor(item.floorId!),
        repo.openOrdersOf(objectId),
      ]);
      final floor = r[0] as Floor?;
      final orders = r[1] as List<PlanOrder>;
      // «Рядом» — другие открытые заявки того же помещения.
      final placeId = item.isPlace ? item.id : item.locationId;
      final nearby = orders
          .where((o) =>
              o.id != widget.orderId && o.isOpen && o.locationId == placeId)
          .length;
      if (!mounted || floor == null) return;
      setState(() {
        _item = item;
        _floor = floor;
        _nearby = nearby;
      });
    } catch (e) {
      debugPrint('OrderPlanLink: ${e.runtimeType}');
      if (isNetworkError(e)) _loadOffline();
    }
  }

  /// Без сети: точка и этаж — из предзагрузки исполнителя, картинка плана —
  /// с телефона (PlanPicture сама возьмёт сохранённую).
  void _loadOffline() {
    final off = OfflineService.instance;
    PlanItem? item;
    final a = off.cachedPlace('assets', widget.assetId);
    if (a != null) item = PlanItem.assetFromMap(a);
    if (item == null || !item.placed) {
      final l = off.cachedPlace('locations', widget.locationId);
      if (l != null) item = PlanItem.placeFromMap(l);
    }
    if (item == null || !item.placed) return;
    final f = off.cachedPlace('floors', item.floorId);
    if (f == null || f['company_id'] == null || !mounted) return;
    final floor = Floor.fromMap(f);
    if (!floor.hasPlan) return;
    setState(() {
      _item = item;
      _floor = floor;
      _nearby = 0;
      _offline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _item, floor = _floor;
    final l = context.l10n;
    final mount = widget.showMount ? mountRow(l, _mount) : null;
    if (item == null || floor == null) {
      return mount == null
          ? const SizedBox.shrink()
          : AppGroup(children: [mount]);
    }
    return AppGroup(children: [
      if (mount != null) mount,
      AppRow(
        leading: PlanThumb(floor: floor, width: 44),
        title: l.orderShowOnPlan,
        titleStyle: AppText.rowTitle.copyWith(color: AppColors.accentText),
        subtitle: _offline ? floor.name : l.planNearby(floor.name, _nearby),
        onTap: () => _offline || !OfflineService.instance.online
            ? Navigator.push(
                context,
                appRoute((_) => OfflinePlanScreen(floor: floor, item: item),
                    title: l.orderShowOnPlan))
            : openFloorPlan(context, widget.objectId!, floor.id,
                focus: item.key),
      ),
    ]);
  }
}
