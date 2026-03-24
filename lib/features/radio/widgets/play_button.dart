import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';

/// Botao principal de reproducao sem container.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    this.size = 96,
    this.enabled = true,
    this.layoutScale,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;
  final double size;

  /// Quando false, o toque é ignorado (ex.: operação bloqueada por outra camada).
  final bool enabled;

  /// Escala mobile-first para sombra (8pt); opcional.
  final double? layoutScale;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Trocamos entre play e pause sem animacoes de pulso.
    final iconData =
        widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final ls = widget.layoutScale ?? 1.0;
    final buttonSize = widget.size.clamp(
      AppSpacing.g(AppSpacing.playControlDiameterMinSteps, ls),
      AppSpacing.g(AppSpacing.playControlDiameterMaxSteps, ls),
    );
    final progressSize = (buttonSize * 0.33).clamp(
      AppSpacing.g(3, ls),
      AppSpacing.g(4, ls),
    );
    final iconSize = (buttonSize * 0.44).clamp(
      AppSpacing.g(4, ls),
      AppSpacing.g(6, ls),
    );
    // Preenchimento sólido: claro = disco preto + ícone branco; escuro = disco claro + ícone escuro.
    final fillColor =
        isDark ? const Color(0xFFECECEC) : const Color(0xFF0D0D0D);
    final borderColor = isDark
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final iconColor = isDark ? const Color(0xFF141414) : Colors.white;

    final canTap = widget.enabled && widget.onTap != null;

    return Semantics(
      button: true,
      enabled: canTap,
      label: widget.isLoading
          ? 'Chargement'
          : widget.isPlaying
              ? 'Mettre en pause la diffusion'
              : 'Reprendre la diffusion',
      child: Tooltip(
        message: widget.isPlaying ? 'Pause' : 'Lecture',
        child: InkWell(
          borderRadius: BorderRadius.circular(buttonSize),
          hoverColor: (isDark ? Colors.black : Colors.white).withValues(
            alpha: isDark ? 0.08 : 0.1,
          ),
          // Mantém o toque em buffering: o loading é só visual no botão.
          onTap: canTap ? widget.onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: widget.enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : Colors.black87).withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    blurRadius: AppSpacing.g(2, ls),
                    offset: Offset(0, AppSpacing.g(1, ls)),
                  ),
                ],
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: progressSize,
                        height: progressSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: iconColor,
                        ),
                      )
                    : Icon(iconData, size: iconSize, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
