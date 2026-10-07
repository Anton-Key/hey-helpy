import 'package:flutter/material.dart';

/// Единая тема Hey Helpy: дружелюбная, светлая, с фирменным акцентом.
class HeyHelpyTheme {
  const HeyHelpyTheme._();

  static const Color seed = Color(0xFF35C4AB); // мягкий мятно-бирюзовый Helpy
  static const Color ink = Color(0xFF1C1E22); // почти чёрный (текст, акценты)

  // Цвета бренда (раздел «Дизайн» в CLAUDE.md):
  // бирюзовые кнопки — с тёмно-зелёным текстом [onBrand];
  // тёмно-зелёные [link] (ссылки, мелкий цветной текст, обычные кнопки) — с белым.
  static const Color brand = Color(0xFF2DB89A);
  static const Color onBrand = Color(0xFF06342A);
  static const Color link = Color(0xFF177A65);
  static const Color mint = Color(0xFFD8F0EA);

  // Светлый градиент шапки (по референсу): светлее вверху-справа → белый
  static const List<Color> headerGradient = [
    Color(0xFFC3F5EF),
    Color(0xFFE6FBF8),
    Color(0xFFFBFFFE),
  ];

  static ThemeData light() {
    // primary — тёмно-зелёный с белым текстом: из него Flutter красит обычные
    // кнопки, ссылки и галочки. Без этого fromSeed давал #056B5B, и бирюзовые
    // кнопки с тёмным текстом получались тёмно-зелёными (плохой контраст).
    final scheme = ColorScheme.fromSeed(seedColor: seed)
        .copyWith(primary: link, onPrimary: Colors.white);
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
