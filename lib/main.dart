import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    // Приложение всё равно запустится и покажет подсказку по настройке,
    // чтобы каркас можно было открыть без готового бэкенда.
    runApp(const _MisconfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const HeyHelpyApp());
}

/// Экран-заглушка, если не переданы SUPABASE_URL / SUPABASE_ANON_KEY.
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_suggest, size: 56),
                SizedBox(height: 16),
                Text(
                  'Не заданы ключи Supabase',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Запусти приложение с параметрами:\n\n'
                  'flutter run \\\n'
                  '  --dart-define=SUPABASE_URL=<url> \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=<anon-key>\n\n'
                  'Подробности — в README.md',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
