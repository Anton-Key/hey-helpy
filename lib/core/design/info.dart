import 'package:flutter/material.dart';

import 'buttons.dart';
import 'icons.dart';
import 'pressable.dart';
import 'surfaces.dart';
import 'tokens.dart';

/// Маленькая кнопка ⓘ рядом с заголовком раздела: открывает короткую
/// подсказку ([showAppInfo]) — заголовок и 2–4 строки. Цель нажатия 44×44,
/// сам значок 18.
class AppInfoButton extends StatelessWidget {
  const AppInfoButton({
    super.key,
    required this.title,
    required this.lines,
    required this.closeLabel,
    this.semanticLabel,
    this.color = AppColors.secondary,
  });

  final String title;
  final List<String> lines;

  /// Кнопка внизу подсказки («Понятно»).
  final String closeLabel;

  /// Для диктора: «Подсказка: Этажи». По умолчанию — [title].
  final String? semanticLabel;
  final Color color;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => showAppInfo(
            context: context,
            title: title,
            lines: lines,
            closeLabel: closeLabel),
        semanticLabel: semanticLabel ?? title,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: AppSizes.minTap,
          height: AppSizes.minTap,
          child: Icon(AppIcons.info, size: AppSizes.iconS, color: color),
        ),
      );
}

/// Короткая подсказка в шторке: заголовок, строки с точкой и «Понятно».
Future<void> showAppInfo({
  required BuildContext context,
  required String title,
  required List<String> lines,
  required String closeLabel,
}) =>
    showAppSheet<void>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.screen),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(AppIcons.info,
                    size: AppSizes.icon, color: AppColors.accentText),
                const SizedBox(width: AppSpace.s),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: AppText.headline),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpace.m),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: AppSpace.s),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                              top: 8, end: AppSpace.s),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle),
                          ),
                        ),
                        Expanded(child: Text(line, style: AppText.body)),
                      ]),
                ),
              const SizedBox(height: AppSpace.s),
              AppButton.secondary(
                  label: closeLabel, onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
