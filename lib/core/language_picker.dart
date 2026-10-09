import 'package:flutter/material.dart';

import 'l10n_ext.dart';
import 'locale_controller.dart';
import 'app_message.dart';

const _line = Color(0xFFE8EAED);

/// Выбор языка интерфейса (профиль и настройки): нижняя шторка со списком
/// языков. Выбор сохраняется на телефоне и в profiles.locale.
Future<void> pickLanguage(BuildContext context) async {
  final controller = LocaleScope.of(context);
  final chosen = await showModalBottomSheet<Locale>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: _line, borderRadius: BorderRadius.circular(4))),
        Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 6),
            child: Text(ctx.l10n.profileLanguage,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800))),
        for (final loc in LocaleController.supported)
          ListTile(
            title: Text(LocaleController.nativeNames[loc.languageCode] ??
                loc.languageCode),
            trailing: loc == controller.locale
                ? Icon(Icons.check_rounded,
                    color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () => Navigator.pop(ctx, loc),
          ),
        const SizedBox(height: 8),
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
