import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import 'photo_repository.dart';

/// Блок «Фото» в карточке заявки: две колонки «До» и «После».
/// По нажатию фото открывается на весь экран.
class WorkPhotosSection extends StatelessWidget {
  const WorkPhotosSection({
    super.key,
    required this.photos,
    required this.loadFailed,
    this.onAddBefore,
    this.onAddAfter,
    this.busy = false,
  });

  final List<WorkPhoto> photos;
  final bool loadFailed;

  /// null — добавлять фото этой стадии нельзя (роль или статус).
  final VoidCallback? onAddBefore;
  final VoidCallback? onAddAfter;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final before = photos.where((p) => p.stage == 'before').toList();
    final after = photos.where((p) => p.stage != 'before').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l.photosTitle),
      if (loadFailed)
        AppCard(
            child: Text(l.photoLoadFailed,
                style: AppText.callout.copyWith(color: AppColors.danger)))
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _Column(
                  title: l.photosBefore,
                  photos: before,
                  onAdd: onAddBefore,
                  busy: busy,
                  addLabel:
                      before.isEmpty ? l.photoAddBefore : l.photoTakeMore)),
          const SizedBox(width: AppSpace.m),
          Expanded(
              child: _Column(
                  title: l.photosAfter,
                  photos: after,
                  onAdd: onAddAfter,
                  busy: busy,
                  addLabel:
                      after.isEmpty ? l.photoTakeResult : l.photoTakeMore)),
        ]),
    ]);
  }
}

class _Column extends StatelessWidget {
  const _Column(
      {required this.title,
      required this.photos,
      required this.onAdd,
      required this.busy,
      required this.addLabel});
  final String title;
  final String addLabel;
  final List<WorkPhoto> photos;
  final VoidCallback? onAdd;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(
            start: AppSpace.xs, bottom: AppSpace.s - 2),
        child: Text(title,
            style: AppText.footnote.copyWith(fontWeight: FontWeight.w600)),
      ),
      for (final p in photos)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
          child: _Thumb(photo: p),
        ),
      if (photos.isEmpty && onAdd == null)
        Container(
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.group)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(AppIcons.camera,
                size: AppSizes.icon, color: AppColors.tertiary),
            const SizedBox(height: AppSpace.xs),
            Text(l.photosNone, style: AppText.footnote),
          ]),
        ),
      if (onAdd != null)
        Pressable(
          onTap: busy ? null : onAdd,
          effect: PressEffect.highlight,
          borderRadius: BorderRadius.circular(AppRadius.group),
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(AppSpace.s),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.group)),
            child: busy
                ? const AppLoader()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(AppIcons.camera,
                        size: AppSizes.iconL, color: AppColors.accentText),
                    const SizedBox(height: AppSpace.xs),
                    Text(addLabel,
                        textAlign: TextAlign.center,
                        style: AppText.footnote.copyWith(
                            color: AppColors.accentText,
                            fontWeight: FontWeight.w600)),
                  ]),
          ),
        ),
    ]);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo});
  final WorkPhoto photo;

  @override
  Widget build(BuildContext context) {
    final open = photo.url == null
        ? null
        : () => Navigator.push(
            context,
            appRoute((_) => PhotoViewerScreen(photo: photo),
                title: context.l10n.detailTitle));
    // Значок лупы подсказывает, что фото открывается на весь экран.
    const broken = ColoredBox(
        color: AppColors.fill,
        child: Icon(AppIcons.imageBroken, color: AppColors.secondary));
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.group),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(fit: StackFit.expand, children: [
          photo.url == null
              ? broken
              : Image.network(photo.url!,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const ColoredBox(
                          color: AppColors.fill, child: AppLoader()),
                  errorBuilder: (_, __, ___) => broken),
          if (open != null)
            PositionedDirectional(
              end: 6,
              bottom: 6,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.6),
                    shape: BoxShape.circle),
                child: const Icon(AppIcons.zoomIn,
                    size: 16, color: AppColors.surface),
              ),
            ),
        ]),
      ),
    );
    if (open == null) return image;
    return Pressable(
        onTap: open,
        effect: PressEffect.highlight,
        borderRadius: BorderRadius.circular(AppRadius.group),
        semanticLabel: photo.stage == 'before'
            ? context.l10n.photosBefore
            : context.l10n.photosAfter,
        child: image);
  }
}

/// Фото на весь экран: можно увеличивать пальцами.
class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.photo});
  final WorkPhoto photo;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final when = photo.takenAt == null
        ? null
        : l.photoTakenAt(l.dateTime(photo.takenAt!));
    final where = photo.mockLocation
        ? l.photoMockLocation
        : (photo.hasLocation ? l.photoWithLocation : l.photoNoLocation);
    // Тёмный просмотр: фото на чёрном фоне, подписи — светлые.
    final light = AppColors.surface.withValues(alpha: 0.75);
    final warn = StatusColors.returned.background;
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Column(children: [
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppSizes.navBar,
            child: NavigationToolbar(
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpace.s),
                child: AppIconButton(
                    icon: AppIcons.close,
                    label: MaterialLocalizations.of(context).closeButtonTooltip,
                    filled: true,
                    onPressed: () => Navigator.maybePop(context)),
              ),
              middle: Text(
                  photo.stage == 'before' ? l.photosBefore : l.photosAfter,
                  style: AppText.headline.copyWith(color: AppColors.surface)),
            ),
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child:
                Center(child: Image.network(photo.url!, fit: BoxFit.contain)),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Row(children: [
              if (when != null)
                Expanded(
                    child: Text(when,
                        style: AppText.footnote.copyWith(color: light))),
              Icon(photo.mockLocation ? AppIcons.warning : AppIcons.place,
                  size: 16, color: photo.mockLocation ? warn : light),
              const SizedBox(width: AppSpace.xs),
              Text(where,
                  style: AppText.footnote
                      .copyWith(color: photo.mockLocation ? warn : light)),
            ]),
          ),
        ),
      ]),
    );
  }
}
