import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../directory/directory.dart';
import 'map_logic.dart';

/// Цвет маркера и текста на нём (контраст текста ≥ 4,5:1).
(Color, Color) toneColors(MarkerTone t) => switch (t) {
      MarkerTone.alert => (StatusColors.overdue.foreground, AppColors.surface),
      MarkerTone.warning => (AppColors.priorityHigh, AppColors.ink),
      MarkerTone.open => (AppColors.accent, AppColors.onAccent),
      MarkerTone.idle => (AppColors.tertiary, AppColors.ink),
    };

/// Маркер объекта: круг с числом открытых заявок.
class ObjectMarker extends StatelessWidget {
  const ObjectMarker(
      {super.key,
      required this.name,
      required this.stats,
      required this.selected,
      required this.onTap});
  final String name;
  final ObjectStats stats;
  final bool selected;
  final VoidCallback onTap;

  static const size = 36.0;
  static const selectedSize = 50.0;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(markerTone(stats));
    final d = selected ? selectedSize : size;
    return Center(
      child: Tooltip(
        message: '$name · ${context.l10n.mapOpenOrders(stats.open)}',
        waitDuration: const Duration(milliseconds: 300),
        child: Semantics(
          button: true,
          label: name,
          child: GestureDetector(
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: AppMotion.normal,
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? AppColors.ink : AppColors.surface,
                      width: selected ? 3 : 2.5),
                  boxShadow: AppShadows.floating,
                ),
                child: Text('${stats.open}',
                    style: (selected ? AppText.headline : AppText.caption)
                        .copyWith(color: fg, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кластер: несколько объектов рядом — акцентный круг. Число — сумма
/// открытых заявок, кольцо — цвет самого тревожного объекта.
class ClusterMarker extends StatelessWidget {
  const ClusterMarker(
      {super.key,
      required this.objects,
      required this.open,
      required this.tone,
      required this.onTap});
  final int objects;
  final int open;
  final MarkerTone tone;
  final VoidCallback onTap;

  static const size = 50.0;

  @override
  Widget build(BuildContext context) {
    final (ring, _) = toneColors(tone);
    final label = context.l10n.mapCluster(objects);
    return Center(
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 4),
                  boxShadow: AppShadows.floating,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$open',
                      style: AppText.callout.copyWith(
                          color: AppColors.onAccent,
                          height: 1.1,
                          fontWeight: FontWeight.w700)),
                  const Icon(AppIcons.building,
                      size: 12, color: AppColors.onAccent),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Синяя точка «Я здесь».
class MeDot extends StatelessWidget {
  const MeDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: StatusColors.inProgress.foreground,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 3),
          boxShadow: [
            BoxShadow(
                color:
                    StatusColors.inProgress.foreground.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 4)
          ],
        ),
      );
}

/// Карточка объекта на карте: адрес, счётчики заявок, действия.
class ObjectInfoCard extends StatelessWidget {
  const ObjectInfoCard(
      {super.key,
      required this.object,
      required this.stats,
      required this.isManager,
      required this.onOpen,
      required this.onOrders,
      required this.onCreate,
      required this.onMove,
      required this.onClose});
  final Obj object;
  final ObjectStats stats;
  final bool isManager;
  final VoidCallback onOpen;
  final VoidCallback onOrders;
  final VoidCallback onCreate;
  final VoidCallback onMove;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (bg, fg) = toneColors(markerTone(stats));
    final address = object.address?.isNotEmpty == true
        ? object.address!
        : l.objectType(object.type);
    // Счётчик — капсула статуса: цвет по статусу, число и подпись.
    Widget counter(String status, String label, int value) {
      final c = value > 0 || status == 'overdue'
          ? StatusColors.of(status)
          : StatusColors.cancelled;
      return Expanded(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpace.xs, vertical: AppSpace.s),
          decoration: BoxDecoration(
            color: value > 0 ? c.background : AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: MergeSemantics(
            child: Column(children: [
              Text('$value',
                  style: AppText.headline.copyWith(
                      color: value > 0 ? c.foreground : AppColors.secondary,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                      color: value > 0 ? c.foreground : AppColors.secondary)),
            ]),
          ),
        ),
      );
    }

    const gap = SizedBox(width: 6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Text('${stats.open}',
                style: AppText.headline
                    .copyWith(color: fg, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(object.name, style: AppText.headline),
              const SizedBox(height: 2),
              Text(address, style: AppText.footnote),
              const SizedBox(height: 2),
              Text(l.mapOpenOrders(stats.open),
                  style: AppText.footnote.copyWith(
                      color: AppColors.accentText,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          AppIconButton(
              icon: AppIcons.close,
              label: l.mapClose,
              filled: true,
              size: 30,
              onPressed: onClose),
        ]),
        const SizedBox(height: AppSpace.m),
        Row(children: [
          counter('new', l.mapCountNew, stats.fresh),
          gap,
          counter('in_progress', l.mapCountInWork, stats.inWork),
          gap,
          counter('on_review', l.mapCountOnReview, stats.onReview),
          gap,
          counter('overdue', l.mapCountOverdue, stats.overdue),
        ]),
        const SizedBox(height: AppSpace.m),
        AppButton.primary(
            label: l.mapOpenObject, icon: AppIcons.building, onPressed: onOpen),
        const SizedBox(height: AppSpace.s),
        // Подписи длинные («Создать заявку здесь») — кнопки одна под другой.
        AppButton.tinted(
            label: l.mapOrders, icon: AppIcons.list, onPressed: onOrders),
        const SizedBox(height: AppSpace.s),
        AppButton.tinted(
            label: l.mapCreateHere, icon: AppIcons.add, onPressed: onCreate),
        if (isManager)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpace.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.plain(
                  label: l.mapMoveOnMap,
                  icon: AppIcons.placeEdit,
                  onPressed: onMove),
            ),
          ),
      ],
    );
  }
}

/// Строка объекта в списке рядом с картой.
class ObjectMapRow extends StatelessWidget {
  const ObjectMapRow(
      {super.key,
      required this.object,
      required this.stats,
      required this.selected,
      required this.onTap,
      this.distanceText});
  final Obj object;
  final ObjectStats stats;
  final bool selected;
  final VoidCallback onTap;
  final String? distanceText;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (bg, fg) = toneColors(markerTone(stats));
    final sub = [
      if (distanceText != null) distanceText!,
      object.address?.isNotEmpty == true
          ? object.address!
          : l.objectType(object.type),
    ].join(' · ');
    return ColoredBox(
      color: selected ? AppColors.mint : AppColors.surface,
      child: AppRow(
        onTap: onTap,
        chevron: false,
        leading: Container(
          width: AppSizes.iconTile,
          height: AppSizes.iconTile,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text('${stats.open}',
              style: AppText.caption
                  .copyWith(color: fg, fontWeight: FontWeight.w700)),
        ),
        title: object.name,
        subtitle: sub,
      ),
    );
  }
}

/// Объект без координат: в группе «Без места на карте».
class UnplacedRow extends StatelessWidget {
  const UnplacedRow(
      {super.key,
      required this.object,
      required this.isManager,
      required this.onPlace});
  final Obj object;
  final bool isManager;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppRow(
      leading: const LeadingIcon.neutral(AppIcons.placeOff),
      title: object.name,
      trailing: isManager
          ? AppButton.tinted(
              label: l.mapSetOnMap,
              icon: AppIcons.place,
              small: true,
              expand: false,
              onPressed: onPlace)
          : null,
    );
  }
}

/// Круглая кнопка управления картой (белая, с тенью).
class MapControlButton extends StatelessWidget {
  const MapControlButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.active = false,
      this.busy = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: busy
            ? Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.floating),
                child: const AppLoader(),
              )
            : AppIconButton(
                icon: icon,
                label: label,
                onPressed: onPressed,
                size: 44,
                shadow: true,
                accent: active),
      ),
    );
  }
}
