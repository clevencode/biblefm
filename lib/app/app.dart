import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:meu_app/core/theme/app_theme.dart';

/// Raiz da app: tema **escuro fixo**, acessibilidade (escala de texto limitada),
/// system UI e [restorationScopeId] para estado restaurável (Material 3).
class RadioApp extends StatelessWidget {
  const RadioApp({
    super.key,
    required this.home,
  });

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible FM',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'biblefm_app',
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark,
      // Textos da app em português; evita diálogos Material a seguirem só o locale do sistema.
      locale: const Locale('pt'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('fr', 'FR'),
        Locale('en'),
        Locale('pt'),
        Locale('pt', 'BR'),
      ],
      builder: (context, child) {
        final safeChild = child ?? const SizedBox.shrink();
        // Web: sem barra de estado / navegação do SO nem clamp extra de escala.
        if (kIsWeb) return safeChild;

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
          child: safeChild,
        );
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.75,
            ),
          ),
          child: content,
        );
      },
      home: home,
    );
  }
}
