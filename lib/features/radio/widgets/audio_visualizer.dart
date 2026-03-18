import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meu_app/core/constants/app_colors.dart';

/// Visualizer simples em barras para indicar atividade de audio.
///
/// Esta versao usa animacao procedural sincronizada ao estado de reproducao.
class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({
    super.key,
    required this.isActive,
    this.barCount = 14,
  });

  final bool isActive;
  final int barCount;

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> {
  final Random _random = Random();
  late List<double> _heights;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _heights = List<double>.filled(widget.barCount, 6);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.barCount != widget.barCount) {
      if (oldWidget.barCount != widget.barCount) {
        _heights = List<double>.filled(widget.barCount, 6);
      }
      _syncTicker();
    }
  }

  void _syncTicker() {
    _tick?.cancel();
    if (!widget.isActive) {
      setState(() {
        _heights = List<double>.filled(widget.barCount, 6);
      });
      return;
    }

    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        _heights = List<double>.generate(widget.barCount, (index) {
          final middle = (widget.barCount - 1) / 2;
          final distance = (index - middle).abs() / middle;
          final weight = 1 - (distance * 0.45);
          final minH = 8.0;
          final maxH = 36.0 * weight.clamp(0.45, 1.0);
          return minH + _random.nextDouble() * (maxH - minH);
        });
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      width: 230,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(widget.barCount, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              width: 4.5,
              height: _heights[index],
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withValues(
                  alpha: widget.isActive ? 1 : 0.35,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }),
      ),
    );
  }
}

