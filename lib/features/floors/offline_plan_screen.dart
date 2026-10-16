import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import 'floor_models.dart';
import 'plan_image.dart';
import 'plan_logic.dart';

/// Шаг 28: план этажа без сети — картинка, сохранённая на телефоне при
/// предзагрузке, и маркер места заявки. Только просмотр (масштаб пальцами);
/// полный экран плана с заявками и редактированием — когда есть сеть.
class OfflinePlanScreen extends StatelessWidget {
  const OfflinePlanScreen({super.key, required this.floor, required this.item});
  final Floor floor;
  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final size = planSize(floor);
    return AppScaffold(
      title: floor.name,
      large: false,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            Text(l.planOfflineNote, style: AppText.footnote),
            const SizedBox(height: AppSpace.s),
          ]),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpace.l),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.group),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: size.width / size.height,
                    child: LayoutBuilder(builder: (context, c) {
                      final x = (item.x ?? 0.5) * c.maxWidth;
                      final y = (item.y ?? 0.5) * c.maxHeight;
                      return Stack(clipBehavior: Clip.none, children: [
                        Positioned.fill(child: PlanPicture(floor: floor)),
                        PositionedDirectional(
                          start: x - 70,
                          top: y - 46,
                          width: 140,
                          child: _Pin(label: item.label),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpace.s, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.iconTile),
              boxShadow: AppShadows.floating),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontWeight: FontWeight.w600)),
        ),
        const Icon(AppIcons.place,
            size: AppSizes.iconL, color: AppColors.danger),
      ]);
}
