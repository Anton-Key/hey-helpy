import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import 'floor_models.dart';
import 'floor_repository.dart';
import 'floors_section.dart';
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
  });

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item, floor = _floor;
    if (item == null || floor == null) return const SizedBox.shrink();
    final l = context.l10n;
    return AppGroup(children: [
      AppRow(
        leading: PlanThumb(floor: floor, width: 44),
        title: l.orderShowOnPlan,
        titleStyle: AppText.rowTitle.copyWith(color: AppColors.accentText),
        subtitle: l.planNearby(floor.name, _nearby),
        onTap: () =>
            openFloorPlan(context, widget.objectId!, floor.id, focus: item.key),
      ),
    ]);
  }
}
