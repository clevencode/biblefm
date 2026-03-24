import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';

/// Botão de modo direto: formato **pílula** (barra inferior) ou círculo (legado).
///
/// Na barra de transporte use [pillShaped]: true — altura [size], largura proporcional.
class LiveModeButton extends StatelessWidget {
  const LiveModeButton({
    super.key,
    required this.isLiveMode,
    required this.isTransitioning,
    required this.onPressed,
    required this.scale,
    required this.size,
    required this.isDark,
    this.pillShaped = false,
    this.narrowMobile = false,
  });

  final bool isLiveMode;
  final bool isTransitioning;
  final VoidCallback? onPressed;
  final double scale;
  /// Diâmetro do play à direita; na pílula é a **altura** do comprimido.
  final double size;
  final bool isDark;
  final bool pillShaped;

  /// Mobile-first: pílula mais longa em ecrãs estreitos (referência visual).
  final bool narrowMobile;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white : const Color(0xFF141414);
    // Pílula em contraste com o play: claro = branco + contorno escuro; escuro = cinza + contorno claro.
    final fillColor = isDark ? const Color(0xFF2E2E2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.18);

    final effectiveOnTap = isTransitioning ? null : onPressed;
    final iconSize = (size * 0.38).clamp(
      AppSpacing.g(3, scale),
      AppSpacing.g(5, scale),
    );
    final progressSize = (size * 0.33).clamp(
      AppSpacing.g(3, scale),
      AppSpacing.g(4, scale),
    );

    String semanticsLabel;
    if (isTransitioning) {
      semanticsLabel = 'Connexion au direct en cours';
    } else if (isLiveMode) {
      semanticsLabel = 'Mode direct, actif';
    } else {
      semanticsLabel = 'Passer en mode direct';
    }

    final radius = size / 2;
    final pillWFactor = pillShaped ? (narrowMobile ? 2.28 : 2.05) : 1.0;
    final pillWidth = pillShaped
        ? math.max(
            size * pillWFactor,
            AppSpacing.g(
              AppSpacing.livePillMinWidthSteps(narrow: narrowMobile),
              scale,
            ),
          )
        : size;
    final pillHeight = size;

    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
          blurRadius: AppSpacing.g(2, scale),
          offset: Offset(0, AppSpacing.g(1, scale)),
        ),
      ],
    );

    final child = isTransitioning
        ? SizedBox(
            width: progressSize,
            height: progressSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: iconColor,
            ),
          )
        : pillShaped
            ? BroadcastSignalIcon(color: iconColor, size: iconSize)
            : Icon(
                Icons.podcasts_rounded,
                color: iconColor,
                size: iconSize,
              );

    return Semantics(
      button: true,
      enabled: effectiveOnTap != null,
      label: semanticsLabel,
      child: Tooltip(
        message: isTransitioning
            ? 'Connexion…'
            : isLiveMode
                ? 'Direct (actif)'
                : 'Écouter le direct',
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: effectiveOnTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: pillWidth,
            height: pillHeight,
            alignment: Alignment.center,
            decoration: decoration,
            padding: pillShaped
                ? EdgeInsets.symmetric(horizontal: AppSpacing.g(1, scale))
                : EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}
