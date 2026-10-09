import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Тема приложения — единственное место, где собирается [ThemeData].
/// Значения — только из токенов (`tokens.dart`).
///
/// - Шрифт Onest на всех экранах.
/// - Без «волн» Material (`NoSplash`): нажатие показывают сами компоненты.
/// - Переходы между экранами — как в iOS, на всех платформах.
/// - Поля ввода — белые, скругление 12, без рамки; в фокусе — акцентная.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      surface: AppColors.surface,
    ).copyWith(
      // primary — им Flutter красит курсор, выделение, переключатели,
      // календарь. Акцентный текст проходит по контрасту с белым.
      primary: AppColors.accentText,
      onPrimary: AppColors.surface,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      error: AppColors.danger,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.secondary,
      outline: AppColors.separator,
      outlineVariant: AppColors.separator,
      surfaceContainerHighest: AppColors.fill,
      surfaceTint: const Color(0x00000000),
    );
    final field = OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide.none);
    const textTheme = TextTheme(
      displaySmall: AppText.largeTitle,
      headlineMedium: AppText.title,
      headlineSmall: AppText.title2,
      titleLarge: AppText.title2,
      titleMedium: AppText.headline,
      titleSmall: AppText.rowTitle,
      bodyLarge: AppText.body,
      bodyMedium: AppText.callout,
      bodySmall: AppText.footnote,
      labelLarge: AppText.headline,
      labelMedium: AppText.footnote,
      labelSmall: AppText.caption,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppText.family,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      dividerColor: AppColors.separator,
      dividerTheme: const DividerThemeData(
          color: AppColors.separator, thickness: 0.5, space: 0.5),
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.pressOverlay,
      hoverColor: const Color(0x00000000),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      }),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.accentText,
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: CupertinoTextThemeData(
          textStyle: AppText.body,
          navTitleTextStyle: AppText.headline,
          navLargeTitleTextStyle: AppText.largeTitle,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.headline,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpace.rowH, vertical: 13),
        hintStyle: AppText.body.copyWith(color: AppColors.secondary),
        labelStyle: AppText.body.copyWith(color: AppColors.secondary),
        floatingLabelStyle: AppText.footnote
            .copyWith(color: AppColors.accentText, fontWeight: FontWeight.w600),
        helperStyle: AppText.footnote,
        errorStyle: AppText.footnote.copyWith(color: AppColors.danger),
        border: field,
        enabledBorder: field,
        disabledBorder: field,
        focusedBorder: field.copyWith(
            borderSide:
                const BorderSide(color: AppColors.accentText, width: 1.5)),
        errorBorder: field.copyWith(
            borderSide: const BorderSide(color: AppColors.danger, width: 1)),
        focusedErrorBorder: field.copyWith(
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accentText,
        selectionColor: AppColors.mint,
        selectionHandleColor: AppColors.accentText,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.fill),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0x00000000)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.fill,
        circularTrackColor: Color(0x00000000),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
        textStyle: AppText.footnote.copyWith(color: AppColors.surface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 8,
        shadowColor: const Color(0x330F1A17),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field)),
        textStyle: AppText.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Color(0x00000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.group)),
        titleTextStyle: AppText.headline,
        contentTextStyle: AppText.callout,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: const Color(0x00000000),
        headerBackgroundColor: AppColors.accentTint,
        headerForegroundColor: AppColors.ink,
        rangeSelectionBackgroundColor: AppColors.mint,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.group)),
      ),
      // Стандартные кнопки Material, если где-то остались (календарь,
      // системные диалоги), — капсулы без волны в цветах бренда.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentText,
          textStyle: AppText.headline,
          splashFactory: NoSplash.splashFactory,
          shape: const StadiumBorder(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          textStyle: AppText.headline,
          splashFactory: NoSplash.splashFactory,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.fill,
          side: BorderSide.none,
          textStyle: AppText.headline,
          splashFactory: NoSplash.splashFactory,
          shape: const StadiumBorder(),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink, size: AppSizes.icon),
    );
  }
}
