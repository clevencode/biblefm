import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';

/// Botão de modo direto em formato **pílula** (barra de transporte).
class LiveModeButton extends StatelessWidget {
  const LiveModeButton({
    super.key,
    required this.isLiveMode,
    required this.isPaused,
    required this.onPressed,
    required this.scale,
    required this.size,
    this.narrowMobile = false,
  });

  final bool isLiveMode;
  final bool isPaused;
  final VoidCallback? onPressed;
  final double scale;

  /// Diâmetro do play à direita; na pílula é a **altura** do comprimido.
  final double size;

  /// Mobile-first: pílula mais longa em ecrãs estreitos (referência visual).
  final bool narrowMobile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final iconColor = AppTheme.transportLiveIcon(brightness);
    // Escuro: painel elevado. Claro: papel (#F3F2EF) — branco puro sumia no gradiente.
    final baseFillColor = brightness == Brightness.light
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHighest;
    final liveBorderColor = brightness == Brightness.light
        ? AppTheme.transportLiveBorder(brightness)
        : scheme.outline.withValues(alpha: 0.85);
    // Preenchimento sólido só com directo **ativo** (a ouvir em live, sem pausa).
    // Em pause ou em différé: só traço (sem preenchimento).
    final liveSurfaceActive = isLiveMode && !isPaused;
    final fillColor = liveSurfaceActive ? baseFillColor : Colors.transparent;
    final borderColor = liveBorderColor;

    final iconSize = (size * 0.38).clamp(
      AppSpacing.g(3, scale),
      AppSpacing.g(5, scale),
    );

    final canTap = onPressed != null;
    String semanticsLabel;
    String tooltipMsg;
    if (isLiveMode && isPaused && canTap) {
      semanticsLabel = 'Rattraper le direct par paliers';
      tooltipMsg =
          'Rapprocher le compteur du direct sans remettre à zéro (répéter après pause)';
    } else if (isLiveMode && !isPaused) {
      semanticsLabel = 'Direct actif';
      tooltipMsg = 'Direct actif';
    } else if (!canTap) {
      semanticsLabel = 'Direct : mettre la lecture en pause pour activer';
      tooltipMsg = 'Mettre la lecture en pause pour activer l’écoute du direct';
    } else {
      semanticsLabel = 'Passer en écoute du direct';
      tooltipMsg = 'Écouter le direct';
    }

    final radius = size / 2;
    final pillWFactor = narrowMobile ? 2.28 : 2.05;
    final pillWidth = math.max(
      size * pillWFactor,
      AppSpacing.g(
        AppSpacing.livePillMinWidthSteps(narrow: narrowMobile),
        scale,
      ),
    );
    final pillHeight = size;

    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
    );

    final child = BroadcastSignalIcon(color: iconColor, size: iconSize);

    Widget pill = InkWell(
      borderRadius: BorderRadius.circular(radius),
      hoverColor: !canTap
          ? Colors.transparent
          : (isDark
                ? AppTheme.darkHoverOverlay(scheme)
                : Colors.black.withValues(alpha: 0.06)),
      splashColor: !canTap
          ? Colors.transparent
          : (isDark
                ? AppTheme.darkHoverOverlay(scheme)
                : Colors.black.withValues(alpha: 0.08)),
      highlightColor: !canTap ? Colors.transparent : null,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: pillWidth,
        height: pillHeight,
        alignment: Alignment.center,
        decoration: decoration,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.g(1, scale)),
        child: child,
      ),
    );
    if (!canTap && !isLiveMode) {
      pill = Opacity(opacity: 0.5, child: pill);
    }

    return Semantics(
      button: true,
      selected: isLiveMode,
      enabled: canTap,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltipMsg,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: pill,
        ),
      ),
    );
  }
}
