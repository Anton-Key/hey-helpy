import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';
import '../../l10n/app_localizations.dart';
import '../floors/floor_models.dart';
import '../floors/floor_repository.dart';
import '../floors/plan_image.dart';
import '../floors/plan_logic.dart';
import 'asset_place.dart';

/// Миниатюра плана этажа с точкой оборудования: картинка растянута по
/// своим пропорциям (точка стоит ровно там, где на плане).
class PlanPointThumb extends StatelessWidget {
  const PlanPointThumb(
      {super.key, required this.floor, required this.point, this.width = 56});
  final Floor floor;
  final PlanPoint point;
  final double width;

  @override
  Widget build(BuildContext context) {
    final plan = planSize(floor);
    final h = (width * plan.height / plan.width).clamp(24.0, width * 1.4);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.iconTile),
      child: SizedBox(
        width: width,
        height: h,
        child: Stack(children: [
          Positioned.fill(child: PlanPicture(floor: floor)),
          Positioned(
            left: point.x * width - 5,
            top: point.y * h - 5,
            width: 10,
            height: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Строка «Место на плане»: «Не указано · Указать на плане» или
/// миниатюра с точкой и «3 этаж · 301 Переговорная · Изменить».
class AssetPlanRow extends StatelessWidget {
  const AssetPlanRow({
    super.key,
    required this.floor,
    required this.point,
    required this.roomLabel,
    required this.onTap,
  });

  /// Этаж точки (null — точки нет или этаж не загружен).
  final Floor? floor;
  final PlanPoint? point;
  final String? roomLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = floor, p = point;
    if (f == null || p == null) {
      return AppRow(
        leading: const LeadingIcon(AppIcons.place),
        title: l.eqPlaceOnPlan,
        subtitle: l.eqPlaceNotSet,
        onTap: onTap,
      );
    }
    return AppRow(
      leading: PlanPointThumb(floor: f, point: p, width: 44),
      title: l.eqPlaceOnPlan,
      subtitle: [
        f.name,
        if (roomLabel != null) roomLabel!,
        if (onTap != null) l.eqPlaceChange,
      ].join(' · '),
      onTap: onTap,
    );
  }
}

/// Выбор «Где именно»: чипы (пол, стена, потолок…), повторное нажатие —
/// снять выбор.
class MountChips extends StatelessWidget {
  const MountChips(
      {super.key, required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
      for (final code in kMountCodes)
        AppChip(
          label: mountLabel(l, code),
          selected: selected == code,
          onTap: () => onChanged(selected == code ? null : code),
        ),
    ]);
  }
}

/// Фото места установки по пути в floor-plans (подписанная ссылка).
class PlacePhotoImage extends StatefulWidget {
  const PlacePhotoImage(
      {super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;

  @override
  State<PlacePhotoImage> createState() => _PlacePhotoImageState();
}

class _PlacePhotoImageState extends State<PlacePhotoImage> {
  late Future<String> _url = FloorRepo().planUrl(widget.path);

  @override
  void didUpdateWidget(PlacePhotoImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = FloorRepo().planUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _url,
        builder: (context, snap) {
          if (snap.hasError) return const _PhotoBroken();
          if (!snap.hasData) return const ColoredBox(color: AppColors.fill);
          return Image.network(snap.data!,
              fit: widget.fit,
              errorBuilder: (_, __, ___) => const _PhotoBroken());
        },
      );
}

class _PhotoBroken extends StatelessWidget {
  const _PhotoBroken();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: AppColors.fill,
        child: Center(
            child: Icon(AppIcons.imageBroken,
                size: AppSizes.iconS, color: AppColors.tertiary)),
      );
}

/// Квадратная миниатюра фото места (из файла или из хранилища).
class PlacePhotoThumb extends StatelessWidget {
  const PlacePhotoThumb({super.key, this.bytes, this.path, this.size = 44});
  final Uint8List? bytes;
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.iconTile),
        child: SizedBox(
          width: size,
          height: size,
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : path != null
                  ? PlacePhotoImage(path: path!)
                  : const _PhotoBroken(),
        ),
      );
}

/// Фото места на весь экран (масштаб пальцами / колесом).
Future<void> openPlacePhoto(BuildContext context, String path, String title) =>
    Navigator.push(
        context,
        appRoute(
            (_) => Scaffold(
                  backgroundColor: AppColors.camera,
                  appBar: AppNavBar(title: title),
                  body: InteractiveViewer(
                    maxScale: 6,
                    child: Center(
                        child:
                            PlacePhotoImage(path: path, fit: BoxFit.contain)),
                  ),
                ),
            title: title));

/// Снимок места установки камерой (в браузере без камеры — выбор файла).
/// Возвращает байты и формат или null (отмена). [onBad] — не картинка
/// нужного формата или больше 15 МБ.
Future<(Uint8List, PlanImageInfo)?> capturePlacePhoto(
    {required VoidCallback onBad}) async {
  final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final (info, problem) = checkPlanFile(bytes);
  if (info == null || problem != null) {
    onBad();
    return null;
  }
  return (bytes, info);
}

/// Строка «Где именно» для карточек: «потолок · 2,8 м · над дверью».
AppRow? mountRow(AppLocalizations l, MountInfo m) {
  final text = formatMountLine(l, m);
  if (text == null) return null;
  return AppRow(
    leading: const LeadingIcon.neutral(AppIcons.placeEdit),
    title: l.eqPlaceWhereExactly,
    subtitle: text,
    chevron: false,
  );
}
