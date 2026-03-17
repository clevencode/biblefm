import 'package:flutter/material.dart';
import 'package:meu_app/core/constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.darkGreen,
          surface: Colors.black,
        ),
      );
}
