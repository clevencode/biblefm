import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_theme.dart';

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
      title: 'Bible FM',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'biblefm_app',
      themeMode: ThemeMode.dark,
      theme: AppTheme.dark,
      scrollBehavior: const _RadioAppScrollBehavior(),
      home: home,
    );
  }
}