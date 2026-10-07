import 'package:flutter/material.dart';

import '../../core/l10n_ext.dart';
import 'photo_repository.dart';

const _ink = Color(0xFF1C1E22);
const _muted = Color(0xFF8A9098);
const _line = Color(0xFFE8EAED);
const _mint = Color(0xFFD8F0EA);
const _link = Color(0xFF177A65);
const _danger = Color(0xFFC24444);

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
      Text(l.photosTitle,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
      const SizedBox(height: 10),
      if (loadFailed)
        Text(l.photoLoadFailed, style: const TextStyle(color: _danger))
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
          const SizedBox(width: 12),
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
      Text(title,
          style: const TextStyle(
              color: _muted, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      for (final p in photos)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8),
          child: _Thumb(photo: p),
        ),
      if (photos.isEmpty && onAdd == null)
        Container(
          height: 90,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line)),
          child: Text(l.photosNone,
              style: const TextStyle(color: _muted, fontSize: 13)),
        ),
      if (onAdd != null)
        // Material + InkWell: у Container с заливкой эффект нажатия не виден.
        Material(
          color: _mint,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onAdd,
            child: Container(
              constraints: const BoxConstraints(minHeight: 90),
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _link))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_camera_outlined, color: _link),
                      const SizedBox(height: 4),
                      Text(addLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _link,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ]),
            ),
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
        : () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PhotoViewerScreen(photo: photo)));
    // Эффект нажатия рисуется поверх снимка; значок лупы подсказывает,
    // что фото открывается на весь экран.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(fit: StackFit.expand, children: [
          photo.url == null
              ? const ColoredBox(
                  color: _line,
                  child: Icon(Icons.broken_image_outlined, color: _muted))
              : Image.network(photo.url!,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const ColoredBox(
                          color: _line,
                          child: Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                  errorBuilder: (_, __, ___) => const ColoredBox(
                      color: _line,
                      child: Icon(Icons.broken_image_outlined, color: _muted))),
          if (open != null) ...[
            const PositionedDirectional(
              end: 6,
              bottom: 6,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Color(0x99000000),
                child: Icon(Icons.zoom_in, size: 16, color: Colors.white),
              ),
            ),
            Material(
                type: MaterialType.transparency, child: InkWell(onTap: open)),
          ],
        ]),
      ),
    );
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo.stage == 'before' ? l.photosBefore : l.photosAfter),
      ),
      body: Column(children: [
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
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (when != null)
                Expanded(
                    child: Text(when,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13))),
              Icon(
                  photo.mockLocation
                      ? Icons.warning_amber_rounded
                      : Icons.place_outlined,
                  size: 16,
                  color: photo.mockLocation
                      ? const Color(0xFFFFB4A9)
                      : Colors.white70),
              const SizedBox(width: 4),
              Text(where,
                  style: TextStyle(
                      color: photo.mockLocation
                          ? const Color(0xFFFFB4A9)
                          : Colors.white70,
                      fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}
