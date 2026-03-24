import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/core/theme/app_theme_mode_providers.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart';
import 'package:meu_app/features/radio/services/radio_player_controller.dart';

/// Raiz da app: tema, acessibilidade (escala de texto limitada), system UI e
/// [restorationScopeId] para estado restaurável (Material 3).
class RadioApp extends ConsumerWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    return MaterialApp(
      title: 'Radio Bible FM',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'biblefm_app',
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('fr', 'FR'),
        Locale('en'),
      ],
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        );
        final content = AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
        // Limita o factor de escala do sistema para evitar ruturas de layout
        // (acessibilidade + layouts densos).
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: content,
        );
      },
      home: const _AppLifecycleAudioGuard(
        child: RadioPlayerPage(),
      ),
    );
  }
}

class _AppLifecycleAudioGuard extends ConsumerStatefulWidget {
  const _AppLifecycleAudioGuard({required this.child});

  final Widget child;

  @override
  ConsumerState<_AppLifecycleAudioGuard> createState() =>
      _AppLifecycleAudioGuardState();
}

class _AppLifecycleAudioGuardState
    extends ConsumerState<_AppLifecycleAudioGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(
        ref.read(radioPlayerControllerProvider.notifier).stopForAppExit(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
