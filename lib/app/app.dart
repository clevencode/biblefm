import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart';

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rádio Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const RadioPlayerPage(),
    );
  }
}
