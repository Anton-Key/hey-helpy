import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/design.dart';
import '../../core/l10n_ext.dart';

/// Шаг 33: при первом открытии «Камеры-помощника» или «AR-меток» — шторка
/// «Как работают AR-метки» с иллюстрацией. Один раз на устройство (флаг в
/// shared_preferences). Хранилище недоступно (тесты) — не показываем.
const kArIntroSeenKey = 'ar_intro_seen';

Future<void> maybeShowArIntro(BuildContext context) async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return;
  }
  if (prefs.getBool(kArIntroSeenKey) == true || !context.mounted) return;
  try {
    await prefs.setBool(kArIntroSeenKey, true);
  } catch (_) {}
  if (!context.mounted) return;
  final l = context.l10n;
  await showAppSheet<void>(
    context: context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      SheetHeader(
          title: l.arIntroTitle,
          doneLabel: l.arIntroOk,
          onDone: () => Navigator.pop(ctx)),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.xs, AppSpace.screen, AppSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppIllustration(AppIllustrationName.phone,
                key: const ValueKey('ar-intro'),
                note: l.illustrationNote,
                semanticLabel: l.arIntroAlt,
                maxHeight: 320,
                fit: BoxFit.contain),
            const SizedBox(height: AppSpace.m),
            Text(l.arIntroText, style: AppText.body),
          ]),
        ),
      ),
    ]),
  );
}
