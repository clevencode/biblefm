import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';

/// Temas Material 3 alinhados à grelha **8pt** ([AppSpacing], [AppRadii]).
abstract final class AppTheme {
  static ThemeData _baseTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFFB8D8A5),
            onPrimary: Color(0xFF132011),
            secondary: Color(0xFFF1C27B),
            onSecondary: Color(0xFF2B1C09),
            error: Color(0xFFF25C54),
            onError: Color(0xFF410002),
            surface: Color(0xFF11180F),
            onSurface: Color(0xFFEFF8DE),
            surfaceContainerHighest: Color(0xFF1A2517),
            outline: Color(0xFF42523C),
            outlineVariant: Color(0xFF313D2D),
          )
        : const ColorScheme.light(
            // Estética Bible FM (mockup): neutro, texto preto, acento verde floresta.
            primary: Color(0xFF1A3D2E),
            onPrimary: Color(0xFFFFFFFF),
            secondary: Color(0xFFBDBDBD),
            onSecondary: Color(0xFF111111),
            error: Color(0xFFD32F2F),
            onError: Color(0xFFFFFFFF),
            surface: Color(0xFFF5F5F5),
            onSurface: Color(0xFF111111),
            surfaceContainerHighest: Color(0xFFFFFFFF),
            outline: Color(0xFFE0E0E0),
            outlineVariant: Color(0xFFEEEEEE),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
        selectedColor: scheme.primary.withValues(alpha: 0.2),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s2,
          ),
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      textTheme: (isDark ? Typography.material2021().white : Typography.material2021().black).apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
    );
  }

  static ThemeData get light => _baseTheme(Brightness.light);

  static ThemeData get dark => _baseTheme(Brightness.dark);
}
