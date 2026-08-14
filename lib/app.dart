import 'package:flutter/material.dart';

import 'core/router.dart';
import 'core/theme.dart';

class HeyHelpyApp extends StatelessWidget {
  const HeyHelpyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter();
    return MaterialApp.router(
      title: 'Hey Helpy',
      debugShowCheckedModeBanner: false,
      theme: HeyHelpyTheme.light(),
      routerConfig: router,
    );
  }
}
