import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fonte única de verdade para o modo de tema do app.
///
/// Ao atualizar este provider, o `MaterialApp` é reconstruído e o tema
/// passa a refletir em todas as telas (sem ficar restrito a uma página).
final appThemeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.light,
);

