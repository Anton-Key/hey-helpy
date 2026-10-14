import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design/design.dart';
import '../../core/file_share.dart';
import '../../core/l10n_ext.dart';
import 'photo_repository.dart';

/// Где была сделана фотография относительно геозоны объекта.
enum PhotoPlace { inZone, outOfZone, noZone, noLocation, mock }

/// Геозона объекта заявки: центр и радиус (миграция 0009).
class PhotoGeofence {
  const PhotoGeofence(
      {required this.lat, required this.lng, this.radiusM = 150});
  final double lat;
  final double lng;
  final int radiusM;
}

/// Место снимка: подменённые координаты важнее всего, затем «нет геометки»,
/// затем расстояние до центра объекта.
(PhotoPlace, int?) photoPlace(WorkPhoto p, PhotoGeofence? zone) {
  if (p.mockLocation) return (PhotoPlace.mock, null);
  if (!p.hasLocation) return (PhotoPlace.noLocation, null);
  if (zone == null) return (PhotoPlace.noZone, null);
  final d = const Distance()
      .as(LengthUnit.Meter, LatLng(p.lat!, p.lng!), LatLng(zone.lat, zone.lng))
      .round();
  return (d <= zone.radiusM ? PhotoPlace.inZone : PhotoPlace.outOfZone, d);
}

/// Блок «Фото» в карточке заявки: группы «До» и «После» со счётчиками,
/// миниатюры. По нажатию — просмотр на весь экран с листанием.
/// Фото видят все, кто видит заявку (база: attachments_select, 0006).
class WorkPhotosSection extends StatelessWidget {
  const WorkPhotosSection({
    super.key,
    required this.photos,
    required this.loadFailed,
    this.onAddBefore,
    this.onAddAfter,
    this.busy = false,
    this.geofence,
  });

  final List<WorkPhoto> photos;
  final bool loadFailed;

  /// null — добавлять фото этой стадии нельзя (роль или статус).
  final VoidCallback? onAddBefore;
  final VoidCallback? onAddAfter;
  final bool busy;
  final PhotoGeofence? geofence;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final before = photos.where((p) => p.stage == 'before').toList();
    final after = photos.where((p) => p.stage != 'before').toList();
    // В просмотре листаются все фото заявки: сначала «до», потом «после».
    final all = [...before, ...after];
    void open(WorkPhoto p) => Navigator.push(
        context,
        appRoute(
            (_) => PhotoViewerScreen(
                photos: all, initialIndex: all.indexOf(p), geofence: geofence),
            title: l.photosTitle));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(photos.isEmpty
          ? l.photosTitle
          : '${l.photosTitle} · ${photos.length}'),
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
                  onOpen: open,
                  busy: busy,
                  addLabel:
                      before.isEmpty ? l.photoAddBefore : l.photoTakeMore)),
          const SizedBox(width: AppSpace.m),
          Expanded(
              child: _Column(
                  title: l.photosAfter,
                  photos: after,
                  onAdd: onAddAfter,
                  onOpen: open,
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
      required this.onOpen,
      required this.busy,
      required this.addLabel});
  final String title;
  final String addLabel;
  final List<WorkPhoto> photos;
  final VoidCallback? onAdd;
  final void Function(WorkPhoto) onOpen;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(
            start: AppSpace.xs, bottom: AppSpace.s - 2),
        child: Text(photos.isEmpty ? title : '$title · ${photos.length}',
            style: AppText.footnote.copyWith(fontWeight: FontWeight.w600)),
      ),
      if (photos.isNotEmpty)
        // Первая — крупно, остальные — мелкой сеткой (по 3 в ряд).
        LayoutBuilder(builder: (context, c) {
          final small = (c.maxWidth - AppSpace.s * 2) / 3;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Thumb(photo: photos.first, onOpen: onOpen),
                if (photos.length > 1)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: AppSpace.s),
                    child: Wrap(
                        spacing: AppSpace.s,
                        runSpacing: AppSpace.s,
                        children: [
                          for (final p in photos.skip(1))
                            SizedBox(
                                width: small,
                                child: _Thumb(
                                    photo: p, onOpen: onOpen, square: true)),
                        ]),
                  ),
                const SizedBox(height: AppSpace.s),
              ]);
        }),
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
            constraints: BoxConstraints(minHeight: photos.isEmpty ? 96 : 52),
            padding: const EdgeInsets.all(AppSpace.s),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.group)),
            child: busy
                ? const AppLoader()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(AppIcons.camera,
                        size: photos.isEmpty ? AppSizes.iconL : AppSizes.icon,
                        color: AppColors.accentText),
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
  const _Thumb(
      {required this.photo, required this.onOpen, this.square = false});
  final WorkPhoto photo;
  final void Function(WorkPhoto) onOpen;
  final bool square;

  @override
  Widget build(BuildContext context) {
    const broken = ColoredBox(
        color: AppColors.fill,
        child: Icon(AppIcons.imageBroken, color: AppColors.secondary));
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.group),
      child: AspectRatio(
        aspectRatio: square ? 1 : 4 / 3,
        child: Stack(fit: StackFit.expand, children: [
          !photo.viewable
              ? broken
              : photo.asset != null
                  ? Image.asset(photo.asset!,
                      fit: BoxFit.cover, cacheWidth: square ? 240 : 480)
                  // Миниатюра: тот же файл, но декодируется уменьшенным —
                  // меньше памяти; сам файл кэширует браузер / система.
                  : Image.network(photo.url!,
                      // Не смог раскодировать сам (бывает в Яндекс Браузере) —
                      // картинка обычным элементом <img> браузера (шаг 24).
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      fit: BoxFit.cover,
                      cacheWidth: square ? 240 : 480,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const ColoredBox(
                              color: AppColors.fill, child: AppLoader()),
                      errorBuilder: (_, __, ___) => broken),
          // Фото «после» из файла — не доказательство (шаг 26).
          if (photo.stage != 'before' && photo.fromFile)
            PositionedDirectional(
              start: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpace.s, vertical: 2),
                decoration: BoxDecoration(
                    color: StatusColors.returned.background,
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(context.l10n.photoFromFile,
                    style: AppText.caption.copyWith(
                        color: StatusColors.returned.foreground,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          // Значок лупы подсказывает, что фото открывается на весь экран.
          if (photo.viewable && !square)
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
    if (!photo.viewable) return image;
    return Pressable(
        onTap: () => onOpen(photo),
        effect: PressEffect.highlight,
        borderRadius: BorderRadius.circular(AppRadius.group),
        semanticLabel: photo.stage == 'before'
            ? context.l10n.photosBefore
            : context.l10n.photosAfter,
        child: image);
  }
}

/// Фото на весь экран: листать свайпом, стрелками и клавишами ← / →,
/// Esc — закрыть, увеличение пальцами, колёсиком и двойным касанием.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen(
      {super.key, required this.photos, this.initialIndex = 0, this.geofence});
  final List<WorkPhoto> photos;
  final int initialIndex;
  final PhotoGeofence? geofence;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pages;
  late int _index;
  final _focus = FocusNode();
  final _zoom = <int, TransformationController>{};
  bool _zoomed = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    _focus.dispose();
    for (final c in _zoom.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _zoomOf(int i) => _zoom.putIfAbsent(i, () {
        final c = TransformationController();
        c.addListener(() {
          if (i != _index) return;
          final z = c.value.getMaxScaleOnAxis() > 1.01;
          if (z != _zoomed) setState(() => _zoomed = z);
        });
        return c;
      });

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.photos.length) return;
    _pages.animateToPage(next,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(rtl ? -1 : 1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(rtl ? 1 : -1);
    } else if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.maybePop(context);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _share(WorkPhoto p) async {
    setState(() => _sharing = true);
    try {
      await shareStorageFile(
          context: context,
          url: p.url!,
          fileName: p.fileName,
          mime: 'image/jpeg',
          bytes: () => PhotoRepository().download(p.storagePath));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _caption(WorkPhoto p) {
    final l = context.l10n;
    final when = p.takenAt == null ? null : l.dateTime(p.takenAt!.toLocal());
    final (place, dist) = photoPlace(p, widget.geofence);
    final where = switch (place) {
      PhotoPlace.inZone => l.photoInZone,
      PhotoPlace.outOfZone => l.photoOutOfZone(dist ?? 0),
      PhotoPlace.noZone => l.photoWithLocation,
      PhotoPlace.noLocation => l.photoNoLocation,
      PhotoPlace.mock => l.photoMockLocation,
    };
    return [
      p.stage == 'before' ? l.photosBefore : l.photosAfter,
      if (p.uploaderName?.isNotEmpty == true) p.uploaderName!,
      if (when != null) when,
      where,
      if (p.stage != 'before' && p.fromFile) l.photoFromFile,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final photos = widget.photos;
    final p = photos[_index];
    final (place, _) = photoPlace(p, widget.geofence);
    final light = AppColors.surface.withValues(alpha: 0.8);
    final warn = StatusColors.returned.background;
    final placeColor = switch (place) {
      PhotoPlace.mock || PhotoPlace.outOfZone => warn,
      _ => light,
    };
    final wide = MediaQuery.sizeOf(context).width >= AppSpace.wideFrom;
    final many = photos.length > 1;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
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
                      label:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      filled: true,
                      onPressed: () => Navigator.maybePop(context)),
                ),
                middle: Text(
                    many
                        ? l.photoCounter(_index + 1, photos.length)
                        : (p.stage == 'before'
                            ? l.photosBefore
                            : l.photosAfter),
                    style: AppText.headline.copyWith(color: AppColors.surface)),
                trailing: Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpace.s),
                  child: AppIconButton(
                      icon: isWebPlatform ? AppIcons.download : AppIcons.share,
                      label: isWebPlatform ? l.fileDownload : l.fileShare,
                      tooltip: true,
                      filled: true,
                      onPressed:
                          _sharing || p.url == null ? null : () => _share(p)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(children: [
              PageView.builder(
                controller: _pages,
                // Увеличенное фото двигается пальцем, а не листается.
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: photos.length,
                onPageChanged: (i) {
                  _zoomOf(_index).value = Matrix4.identity();
                  setState(() {
                    _index = i;
                    _zoomed = false;
                  });
                },
                itemBuilder: (_, i) =>
                    _ZoomPhoto(photo: photos[i], controller: _zoomOf(i)),
              ),
              if (many && wide) ...[
                if (_index > 0)
                  PositionedDirectional(
                    start: AppSpace.l,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AppIconButton(
                          icon: AppIcons.chevronLeft,
                          label: l.photoPrev,
                          size: 44,
                          filled: true,
                          onPressed: () => _go(-1)),
                    ),
                  ),
                if (_index < photos.length - 1)
                  PositionedDirectional(
                    end: AppSpace.l,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AppIconButton(
                          icon: AppIcons.chevronRight,
                          label: l.photoNext,
                          size: 44,
                          filled: true,
                          onPressed: () => _go(1)),
                    ),
                  ),
              ],
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Row(children: [
                Icon(
                    place == PhotoPlace.mock
                        ? AppIcons.warning
                        : (place == PhotoPlace.noLocation
                            ? AppIcons.placeOff
                            : AppIcons.place),
                    size: 16,
                    color: placeColor),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(_caption(p),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.footnote.copyWith(color: placeColor)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ZoomPhoto extends StatelessWidget {
  const _ZoomPhoto({required this.photo, required this.controller});
  final WorkPhoto photo;
  final TransformationController controller;

  @override
  Widget build(BuildContext context) {
    if (photo.asset != null) {
      return InteractiveViewer(
          transformationController: controller,
          minScale: 1,
          maxScale: 5,
          child: Center(child: Image.asset(photo.asset!, fit: BoxFit.contain)));
    }
    if (photo.url == null) {
      return const Center(
          child: Icon(AppIcons.imageBroken,
              size: AppSizes.iconL, color: AppColors.tertiary));
    }
    // Двойное касание — увеличить вдвое / вернуть как было.
    return GestureDetector(
      onDoubleTap: () => controller.value =
          controller.value.getMaxScaleOnAxis() > 1.01
              ? Matrix4.identity()
              : (Matrix4.identity()..scaleByDouble(2, 2, 1, 1)),
      child: InteractiveViewer(
        transformationController: controller,
        minScale: 1,
        maxScale: 5,
        child: Center(
            child: Image.network(photo.url!,
                // Не смог раскодировать сам (бывает в Яндекс Браузере) —
                // картинка обычным элементом <img> браузера (шаг 24).
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const AppLoader(),
                errorBuilder: (_, __, ___) => const Icon(AppIcons.imageBroken,
                    size: AppSizes.iconL, color: AppColors.tertiary))),
      ),
    );
  }
}
