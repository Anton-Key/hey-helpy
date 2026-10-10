import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import 'floor_models.dart';
import 'floor_repository.dart';
import 'plan_logic.dart';

/// Картинка плана этажа по подписанной ссылке (кэш ссылок — в
/// [FloorRepo.planUrl]). Этаж без картинки — нейтральная сетка
/// ([PlanGrid]). Пока грузится — та же сетка.
class PlanPicture extends StatefulWidget {
  const PlanPicture(
      {super.key, required this.floor, this.repo, this.fit = BoxFit.fill});
  final Floor floor;
  final FloorRepo? repo;
  final BoxFit fit;

  @override
  State<PlanPicture> createState() => _PlanPictureState();
}

class _PlanPictureState extends State<PlanPicture> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PlanPicture old) {
    super.didUpdateWidget(old);
    if (old.floor.planPath != widget.floor.planPath) _resolve();
  }

  void _resolve() {
    final path = widget.floor.planPath;
    _url = path == null ? null : (widget.repo ?? FloorRepo()).planUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return const PlanGrid();
    return FutureBuilder<String>(
      future: url,
      builder: (context, snap) {
        if (!snap.hasData) return const PlanGrid(loading: true);
        return Image.network(
          snap.data!,
          fit: widget.fit,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : const PlanGrid(loading: true),
          errorBuilder: (_, __, ___) => const PlanGrid(broken: true),
        );
      },
    );
  }
}

/// Сетка вместо плана: этаж без картинки, загрузка или ошибка.
class PlanGrid extends StatelessWidget {
  const PlanGrid({super.key, this.loading = false, this.broken = false});
  final bool loading;
  final bool broken;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _GridPainter(),
        child: broken
            ? const Center(
                child: Icon(AppIcons.imageBroken,
                    size: 48, color: AppColors.tertiary))
            : const SizedBox.expand(),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface);
    final minor = Paint()
      ..color = AppColors.separator
      ..strokeWidth = 1;
    final major = Paint()
      ..color = AppColors.tertiary.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    // Шаг — 1/40 ширины плана: сетка одинаковая при любом размере.
    final step = size.width / 40;
    if (step <= 0) return;
    var i = 0;
    for (double x = 0; x <= size.width; x += step, i++) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    i = 0;
    for (double y = 0; y <= size.height; y += step, i++) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

/// Маленькое превью плана в строке этажа: картинка 56×40 со скруглением
/// или значок «без плана».
class PlanThumb extends StatelessWidget {
  const PlanThumb({super.key, required this.floor, this.width = 56});
  final Floor floor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.7;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.iconTile),
      child: SizedBox(
        width: width,
        height: h,
        child: floor.hasPlan
            ? PlanPicture(floor: floor, fit: BoxFit.cover)
            : const ColoredBox(
                color: AppColors.fill,
                child: Center(
                    child: Icon(AppIcons.imageBroken,
                        size: AppSizes.iconS, color: AppColors.tertiary)),
              ),
      ),
    );
  }
}

/// Размер плана для холста (картинка или сетка 2000×1400).
Size planCanvasSize(Floor f) => planSize(f);
