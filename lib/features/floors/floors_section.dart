import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import 'floor_models.dart';
import 'floor_repository.dart';
import 'plan_image.dart';
import 'plan_logic.dart';
import 'plan_sheets.dart';

/// Адрес экрана «План этажа» (на вебе — ссылка, которой можно поделиться).
/// [focus] — маркер, на котором план откроется ([PlanItem.key]),
/// [edit] — сразу режим расстановки (только менеджер).
String floorPlanLocation(String objectId, String floorId,
    {String? focus, bool edit = false}) {
  final q = {
    if (focus != null) 'focus': focus,
    if (edit) 'edit': '1',
  };
  return Uri(
          path: '/objects/$objectId/floors/$floorId',
          queryParameters: q.isEmpty ? null : q)
      .toString();
}

/// Открыть план этажа (поверх текущего экрана, адрес страницы меняется).
Future<void> openFloorPlan(
        BuildContext context, String objectId, String floorId,
        {String? focus, bool edit = false}) =>
    GoRouter.of(context).push<void>(
        floorPlanLocation(objectId, floorId, focus: focus, edit: edit));

/// Подпись «12 помещений · 3 открытые заявки» для строки этажа.
String floorSummary(
    AppLocalizations l, Floor f, List<PlanItem> items, List<PlanOrder> orders) {
  final places = {
    for (final i in items)
      if (i.isPlace && i.floorId == f.id) i.id
  };
  final assets = {
    for (final i in items)
      if (!i.isPlace && i.floorId == f.id) i.id
  };
  final open = orders
      .where((o) =>
          o.isOpen &&
          (places.contains(o.locationId) || assets.contains(o.assetId)))
      .length;
  return '${l.floorPlacesCount(places.length)} · ${l.floorOpenOrders(open)}';
}

/// Раздел «Этажи · N» карточки объекта: строки этажей с превью плана,
/// у менеджера — «+ Этаж», «+» (помещение на этаж) и меню «⋯».
class FloorsSection extends StatelessWidget {
  const FloorsSection({
    super.key,
    required this.objectId,
    required this.companyId,
    required this.isManager,
    required this.floors,
    required this.items,
    required this.orders,
    required this.onChanged,
  });

  final String objectId;
  final String? companyId;
  final bool isManager;
  final List<Floor> floors;
  final List<PlanItem> items;
  final List<PlanOrder> orders;

  /// Перечитать данные карточки (после изменений и возврата с плана).
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.floorsTitle(floors.length),
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.rowH, AppSpace.s, 0, 0),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            floorsInfo(l),
            if (isManager && companyId != null)
              AppButton.tinted(
                  icon: AppIcons.add,
                  label: l.floorAdd,
                  small: true,
                  expand: false,
                  onPressed: () => _add(context)),
          ]),
        ),
        const SizedBox(height: AppSpace.xs),
        AppGroup(
          footer: floors.isEmpty && isManager ? l.floorsEmptyManager : null,
          children: [
            if (floors.isEmpty)
              AppRow(title: l.floorsEmpty, titleStyle: AppText.callout)
            else
              for (var i = 0; i < floors.length; i++)
                _row(context, l, floors[i], i),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, AppLocalizations l, Floor f, int index) {
    return AppRow(
      leading: PlanThumb(floor: f, width: 52),
      title: f.name,
      subtitle: [
        floorSummary(l, f, items, orders),
        if (!f.hasPlan) l.floorNoPlan,
      ].join('\n'),
      trailing: isManager
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              AppIconButton(
                  icon: AppIcons.add,
                  label: l.floorAddPlace(f.name),
                  size: AppSizes.minTap,
                  onPressed: () async {
                    await openFloorPlan(context, objectId, f.id, edit: true);
                    await onChanged();
                  }),
              Builder(
                builder: (anchor) => AppIconButton(
                    icon: AppIcons.more,
                    label: l.floorMenu(f.name),
                    size: AppSizes.minTap,
                    onPressed: () => _menu(anchor, f, index)),
              ),
            ])
          : null,
      chevron: !isManager,
      onTap: () async {
        await openFloorPlan(context, objectId, f.id);
        await onChanged();
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final l = context.l10n;
    final r = await showFloorForm(context, floors: floors);
    if (r == null || !context.mounted) return;
    final repo = FloorRepo();
    try {
      final f = await repo.createFloor(
          objectId: objectId,
          companyId: companyId!,
          name: r.name,
          level: r.level,
          sort: nextFloorSort(floors));
      if (r.plan != null) {
        try {
          await repo.uploadPlan(f, r.plan!.bytes, r.plan!.info);
        } catch (e) {
          logPlanError('FloorsSection upload', e);
          if (context.mounted) {
            showAppMessage(context, planErrorText(l, e, isManager: isManager),
                type: AppMessageType.error);
          }
        }
      }
      if (context.mounted) {
        showAppMessage(context, l.toastSaved, type: AppMessageType.success);
      }
    } catch (e) {
      logPlanError('FloorsSection create', e);
      if (context.mounted) {
        showAppMessage(context, planErrorText(l, e, isManager: isManager),
            type: AppMessageType.error);
      }
    }
    await onChanged();
  }

  Future<void> _menu(BuildContext context, Floor f, int index) async {
    final l = context.l10n;
    final a =
        await showActionSheet<_FloorAction>(context, title: f.name, actions: [
      SheetAction(_FloorAction.rename, l.floorRename, AppIcons.edit),
      SheetAction(
          _FloorAction.upload,
          f.hasPlan ? l.floorReplacePlan : l.floorUploadPlan,
          AppIcons.imageAdd),
      if (f.hasPlan)
        SheetAction(
            _FloorAction.clearPlan, l.floorRemovePlan, AppIcons.imageOff),
      if (index > 0)
        SheetAction(_FloorAction.up, l.floorMoveUp, AppIcons.moveUp),
      if (index < floors.length - 1)
        SheetAction(_FloorAction.down, l.floorMoveDown, AppIcons.moveDown),
      SheetAction(_FloorAction.delete, l.floorDelete, AppIcons.delete,
          destructive: true),
    ]);
    if (a == null || !context.mounted) return;
    final repo = FloorRepo();
    try {
      switch (a) {
        case _FloorAction.rename:
          final r = await showFloorForm(context, floors: floors, existing: f);
          if (r == null) return;
          await repo.renameFloor(f.id, r.name, r.level);
        case _FloorAction.upload:
          final p = await pickPlanFile(context);
          if (p == null) return;
          await repo.uploadPlan(f, p.bytes, p.info);
          if (context.mounted) {
            showAppMessage(context, l.planUploaded,
                type: AppMessageType.success);
          }
        case _FloorAction.clearPlan:
          await repo.clearPlan(f);
          if (context.mounted) showAppMessage(context, l.planRemoved);
        case _FloorAction.up:
          await repo.setSorts(moveFloor(floors, f.id, -1));
        case _FloorAction.down:
          await repo.setSorts(moveFloor(floors, f.id, 1));
        case _FloorAction.delete:
          final ok = await showAppDialog<bool>(
            context: context,
            title: l.floorDeleteConfirm(f.name),
            message: l.floorDeleteHint,
            actions: [
              AppDialogAction(l.actionDelete, true, destructive: true),
              AppDialogAction(l.commonCancel, false),
            ],
          );
          if (ok != true) return;
          await repo.deleteFloor(f);
          if (context.mounted) showAppMessage(context, l.floorDeleted);
      }
    } catch (e) {
      logPlanError('FloorsSection ${a.name}', e);
      if (context.mounted) {
        showAppMessage(context, planErrorText(l, e, isManager: isManager),
            type: AppMessageType.error);
      }
    }
    await onChanged();
  }
}

enum _FloorAction { rename, upload, clearPlan, up, down, delete }
