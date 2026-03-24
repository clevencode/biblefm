import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme_mode_providers.dart';

/// Toggle **claro / escuro** em pílula: cores e contornos vêm do [ColorScheme]
/// do tema global (`AppTheme` + `MaterialApp`).
class AppThemeModeToggle extends ConsumerWidget {
  const AppThemeModeToggle({super.key, required this.layoutScale});

  final double layoutScale;

  static bool _lightSegmentSelected(ThemeMode mode, BuildContext context) {
    switch (mode) {
      case ThemeMode.light:
        return true;
      case ThemeMode.dark:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.light;
    }
  }

  static bool _darkSegmentSelected(ThemeMode mode, BuildContext context) {
    switch (mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(appThemeModeProvider);
    final lightOn = _lightSegmentSelected(mode, context);
    final darkOn = _darkSegmentSelected(mode, context);

    final h = AppSpacing.g(6, layoutScale);
    final w = AppSpacing.g(15, layoutScale);
    final iconSize = AppSpacing.g(2, layoutScale);
    final radius = BorderRadius.circular(h / 2);

    Color segmentBg(bool selected) {
      return selected ? scheme.surfaceContainerHighest : scheme.surface;
    }

    Color iconColor(bool selected) {
      return selected
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.42);
    }

    void setLight() {
      ref.read(appThemeModeProvider.notifier).state = ThemeMode.light;
    }

    void setDark() {
      ref.read(appThemeModeProvider.notifier).state = ThemeMode.dark;
    }

    return Tooltip(
      message: 'Thème',
      child: SizedBox(
        width: w,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: lightOn,
                    label: 'Thème clair',
                    child: Material(
                      color: segmentBg(lightOn),
                      child: InkWell(
                        onTap: setLight,
                        child: Center(
                          child: Icon(
                            Icons.light_mode_rounded,
                            size: iconSize,
                            color: iconColor(lightOn),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  color: scheme.outline.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: darkOn,
                    label: 'Thème sombre',
                    child: Material(
                      color: segmentBg(darkOn),
                      child: InkWell(
                        onTap: setDark,
                        child: Center(
                          child: Icon(
                            Icons.dark_mode_rounded,
                            size: iconSize,
                            color: iconColor(darkOn),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
