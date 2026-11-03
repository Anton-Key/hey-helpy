import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Иллюстрации-концепт (шаг 33): WebP 1200 px в `assets/illustrations/`
/// (исходники PNG — `assets/marketing/`, в сборку не идут). Показывают
/// функцию, а не экран приложения, поэтому под картинкой — мелкая подпись
/// «Иллюстрация» ([note], из `.arb`).
enum AppIllustrationName { hotelAc, fridge, faucet, led, cctv, pipe, phone, iso }

/// Путь к файлу иллюстрации в сборке.
String illustrationAsset(AppIllustrationName n) => 'assets/illustrations/${switch (n) {
      AppIllustrationName.hotelAc => 'hotel_ac',
      AppIllustrationName.fridge => 'fridge',
      AppIllustrationName.faucet => 'faucet',
      AppIllustrationName.led => 'led',
      AppIllustrationName.cctv => 'cctv',
      AppIllustrationName.pipe => 'pipe',
      AppIllustrationName.phone => 'phone',
      AppIllustrationName.iso => 'iso',
    }}.webp';

/// Картинка со скруглением, необязательная подпись [caption] и пометка
/// [note] («Иллюстрация») мелко серым. [semanticLabel] — что изображено
/// (для читалок экрана). Картинка не растягивается выше [maxHeight].
class AppIllustration extends StatelessWidget {
  const AppIllustration(
    this.name, {
    super.key,
    required this.note,
    required this.semanticLabel,
    this.caption,
    this.maxHeight,
    this.fit = BoxFit.cover,
  });

  final AppIllustrationName name;
  final String note;
  final String semanticLabel;
  final String? caption;
  final double? maxHeight;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.group),
      child: Image.asset(illustrationAsset(name),
          fit: fit,
          semanticLabel: semanticLabel,
          // Нет файла (тесты, урезанная сборка) — пустое место, не ошибка.
          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (maxHeight == null)
          image
        else
          ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!), child: image),
        if (caption != null) ...[
          const SizedBox(height: AppSpace.s),
          Text(caption!, textAlign: TextAlign.center, style: AppText.headline),
        ],
        const SizedBox(height: AppSpace.xs),
        Text(note,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.tertiary)),
      ],
    );
  }
}
