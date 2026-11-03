import 'package:flutter/material.dart';

import '../../core/app_message.dart';
import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../equipment/equipment_kinds.dart';
import 'eval_labels.dart';
import 'eval_models.dart';
import 'eval_repository.dart';

/// Фото набора (шаг 34): миниатюра, что на фото, dev / test, условия.
/// Пока набор не заморожен — фото можно удалить (ошиблись с разметкой —
/// удалить и снять заново; менять разметку база не даёт).
class EvalPhotosScreen extends StatefulWidget {
  const EvalPhotosScreen(
      {super.key,
      required this.set,
      required this.samples,
      required this.repo});
  final EvalSet set;
  final List<EvalSample> samples;
  final EvalRepository repo;

  @override
  State<EvalPhotosScreen> createState() => _EvalPhotosScreenState();
}

class _EvalPhotosScreenState extends State<EvalPhotosScreen> {
  late List<EvalSample> _samples = widget.samples.reversed.toList();

  Future<void> _delete(EvalSample s) async {
    final l = context.l10n;
    final ok = await showAppDialog<bool>(
      context: context,
      title: l.evalDeleteTitle,
      actions: [
        AppDialogAction(l.commonCancel, false),
        AppDialogAction(l.evalDeletePhoto, true, destructive: true),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repo.deleteSample(s);
      if (!mounted) return;
      setState(() => _samples = [..._samples]..remove(s));
      showAppMessage(context, l.evalDeleted);
    } catch (e) {
      debugPrint('eval delete: $e');
      if (mounted) {
        showAppMessage(context, l.evalSaveFailed, type: AppMessageType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      title: l.evalPhotos,
      slivers: [
        SliverContent(
          sliver: SliverList.list(children: [
            AppGroup(
              footer: widget.set.frozen
                  ? l.evalSetFrozen(l.dateTime(widget.set.frozenAt!))
                  : l.evalSetOpen,
              children: [
                for (final s in _samples)
                  AppRow(
                    leading: _Thumb(path: s.photoPath, repo: widget.repo),
                    title: l.evalPhotoRow(
                        s.unregistered
                            ? l.evalNotInRegistry
                            : s.trueKind == null
                                ? l.evalUnknownKind
                                : equipmentKindLabel(l, s.trueKind!),
                        s.split),
                    subtitle: [
                      evalConditionLabel(l, 'light', s.light),
                      evalConditionLabel(l, 'distance', s.distance),
                      evalConditionLabel(l, 'angle', s.angle),
                      if (s.occlusion) l.evalOcclusion,
                      l.dateTime(s.createdAt),
                    ].join(' · '),
                    trailing: widget.set.frozen
                        ? null
                        : AppIconButton(
                            icon: AppIcons.delete,
                            label: l.evalDeletePhoto,
                            tooltip: true,
                            onPressed: () => _delete(s)),
                    chevron: false,
                  ),
              ],
            ),
          ]),
        ),
        const SliverBottomInset(),
      ],
    );
  }
}

/// Миниатюра фото из закрытого хранилища (скачивается под входом).
class _Thumb extends StatefulWidget {
  const _Thumb({required this.path, required this.repo});
  final String path;
  final EvalRepository repo;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final _bytes = widget.repo.photo(widget.path);

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.iconTile),
        child: SizedBox.square(
          dimension: AppSizes.iconTile,
          child: FutureBuilder(
            future: _bytes,
            builder: (_, snap) => snap.data == null
                ? const ColoredBox(color: AppColors.fill)
                : Image.memory(snap.data!, fit: BoxFit.cover),
          ),
        ),
      );
}
