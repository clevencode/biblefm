import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bibliofani/core/theme/app_theme.dart';

/// Garante scroll por **toque** no Web móvel (e rato no desktop).
class _RadioAppScrollBehavior extends MaterialScrollBehavior {
  const _RadioAppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

/// Raiz da app: tema **escuro fixo**, acessibilidade e estado restaurável (Material 3).
class RadioApp extends StatelessWidget {
  const RadioApp({
    super.key,
    required this.home,
  });

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bibliofani',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'bibliofani_app',
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark,
      scrollBehavior: const _RadioAppScrollBehavior(),
      home: home,
    );
  }
}