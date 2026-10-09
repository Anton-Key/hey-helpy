import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/design/design.dart';
import 'core/l10n_ext.dart';
import 'core/locale_controller.dart';
import 'core/supabase_config.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Язык нужен до первого кадра, чтобы интерфейс не «переключался» при запуске.
  final locale = await LocaleController.load();

  if (!SupabaseConfig.isConfigured) {
    // Приложение всё равно запустится и покажет подсказку по настройке,
    // чтобы каркас можно было открыть без готового бэкенда.
    runApp(_MisconfiguredApp(locale: locale.locale));
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    // Тот же anon-ключ: в supabase_flutter 2.17 publishableKey заменил anonKey.
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(HeyHelpyApp(locale: locale));
}

/// Экран-заглушка, если не переданы SUPABASE_URL / SUPABASE_ANON_KEY.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp({required this.locale});
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        final l = context.l10n;
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.settings,
                      size: 48, color: AppColors.secondary),
                  const SizedBox(height: 16),
                  Text(
                    l.misconfiguredTitle,
                    style: AppText.title2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l.misconfiguredRunWith}\n\n'
                    'flutter run \\\n'
                    '  --dart-define=SUPABASE_URL=<url> \\\n'
                    '  --dart-define=SUPABASE_ANON_KEY=<anon-key>\n\n'
                    '${l.misconfiguredSeeReadme}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
