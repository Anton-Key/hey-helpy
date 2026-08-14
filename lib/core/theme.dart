import 'package:flutter/material.dart';

/// Единая тема Hey Helpy: дружелюбная, светлая, с фирменным акцентом.
class HeyHelpyTheme {
  const HeyHelpyTheme._();

  static const Color seed = Color(0xFF35C4AB); // мягкий мятно-бирюзовый Helpy
  static const Color ink = Color(0xFF1C1E22); // почти чёрный (текст, акценты)

  // Светлый градиент шапки (по референсу): светлее вверху-справа → белый
  static const List<Color> headerGradient = [
    Color(0xFFC3F5EF),
    Color(0xFFE6FBF8),
    Color(0xFFFBFFFE),
  ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
