import 'package:flutter/material.dart';

import 'app_message.dart';
import 'design/design.dart';
import 'l10n_ext.dart';
import 'locale_controller.dart';

/// Выбор языка интерфейса (профиль и настройки): нижняя шторка со списком
/// языков. Выбор сохраняется на телефоне и в profiles.locale.
Future<void> pickLanguage(BuildContext context) async {
  final controller = LocaleScope.of(context);
  final chosen = await showAppSheet<Locale>(
    context: context,
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(title: ctx.l10n.profileLanguage),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.screen, AppSpace.s, AppSpace.screen, AppSpace.l),
          child: AppGroup(margin: EdgeInsets.zero, children: [
            for (final loc in LocaleController.supported)
              AppRow(
                title: LocaleController.nativeNames[loc.languageCode] ??
                    loc.languageCode,
                chevron: false,
                trailing: loc == controller.locale
                    ? const Icon(AppIcons.check,
                        size: AppSizes.icon, color: AppColors.accentText)
                    : null,
                onTap: () => Navigator.pop(ctx, loc),
              ),
          ]),
        ),
      ]),
    ),
  );
  if (chosen == null || chosen == controller.locale) return;
  final synced = await controller.select(chosen);
  if (!synced && context.mounted) {
    showAppMessage(context, context.l10n.profileLanguageNotSynced,
        type: AppMessageType.error);
  }
}

/// Название текущего языка на нём самом: «Русский», «English».
String currentLanguageName(BuildContext context) =>
    LocaleController.nativeNames[context.localeCode] ?? context.localeCode;
