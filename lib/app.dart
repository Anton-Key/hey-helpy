import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/locale_controller.dart';
import 'core/router.dart';
import 'core/session_controller.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'core/scrolling.dart';

class HeyHelpyApp extends StatefulWidget {
  const HeyHelpyApp({super.key, required this.locale});
  final LocaleController locale;

  @override
  State<HeyHelpyApp> createState() => _HeyHelpyAppState();
}

class _HeyHelpyAppState extends State<HeyHelpyApp> {
  // Создаются один раз: пересоздание роутера в build() сбрасывало навигацию.
  late final SessionController _session = SessionController();
  late final GoRouter _router = createRouter(_session);

  @override
  void initState() {
    super.initState();
    _session.addListener(_syncLocale);
  }

  String? _seenProfileLocale;

  /// После входа язык из профиля важнее сохранённого на телефоне.
  /// Применяем только новое значение: иначе устаревший профиль (выбор
  /// не записался, например без сети) откатывал бы выбор пользователя.
  void _syncLocale() {
    final code = _session.profile?.locale;
    if (code == _seenProfileLocale) return;
    _seenProfileLocale = code;
    widget.locale.applyFromProfile(code);
  }

  @override
  void dispose() {
    _session.removeListener(_syncLocale);
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: widget.locale,
      child: ListenableBuilder(
        listenable: widget.locale,
        builder: (context, _) => MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          // Прокрутка колесом, ползунком и клавиатурой — на всех экранах.
          scrollBehavior: const AppScrollBehavior(),
          builder: (context, child) =>
              KeyboardScrolling(child: child ?? const SizedBox.shrink()),
          locale: widget.locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}
