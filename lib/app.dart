import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/session_controller.dart';
import 'core/theme.dart';

class HeyHelpyApp extends StatefulWidget {
  const HeyHelpyApp({super.key});

  @override
  State<HeyHelpyApp> createState() => _HeyHelpyAppState();
}

class _HeyHelpyAppState extends State<HeyHelpyApp> {
  // Создаются один раз: пересоздание роутера в build() сбрасывало навигацию.
  late final SessionController _session = SessionController();
  late final GoRouter _router = createRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Hey Helpy',
      debugShowCheckedModeBanner: false,
      theme: HeyHelpyTheme.light(),
      routerConfig: _router,
    );
  }
}
