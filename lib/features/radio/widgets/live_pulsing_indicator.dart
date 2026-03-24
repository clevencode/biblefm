import 'package:flutter/material.dart';
import 'package:meu_app/core/theme/app_spacing.dart';

/// Indicador «ao vivo»: círculo vermelho com halos que pulsam em sequência.
class LivePulsingIndicator extends StatefulWidget {
  const LivePulsingIndicator({super.key, required this.scale});

  final double scale;

  @override
  State<LivePulsingIndicator> createState() => _LivePulsingIndicatorState();
}

class _LivePulsingIndicatorState extends State<LivePulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _haloRing({
    required double t,
    required double phase,
    required double coreD,
    required Color red,
  }) {
    final u = ((t + phase) % 1.0);
    final eased = Curves.easeOutCubic.transform(u);
    final haloScale = 0.78 + 0.42 * eased;
    final haloOpacity = 0.42 * (1 - eased).clamp(0.0, 1.0);
    return Transform.scale(
      scale: haloScale,
      child: Container(
        width: coreD * 2.35,
        height: coreD * 2.35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: red.withValues(alpha: haloOpacity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    // Núcleo ~14pt: 2 passos 8pt menos meio passo 4pt (alinhado à grelha).
    final coreD = AppSpacing.g(2, s) - AppSpacing.gHalf(s) * 0.5;
    // Ligeiramente menor que antes: alinha melhor à altura da pílula «En direct».
    final outerSize = AppSpacing.g(4, s);
    const red = Color(0xFFE53935);

    return Semantics(
      label: 'En direct',
      child: RepaintBoundary(
        child: SizedBox(
          width: outerSize,
          height: outerSize,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  _haloRing(t: t, phase: 0, coreD: coreD, red: red),
                  _haloRing(t: t, phase: 0.5, coreD: coreD, red: red),
                  Container(
                    width: coreD,
                    height: coreD,
                    decoration: BoxDecoration(
                      color: red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x33E53935),
                          blurRadius: AppSpacing.gHalf(s),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
