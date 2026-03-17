import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meu_app/features/radio/services/radio_player_service.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

const Color _uiAccent = Color(0xFF00260F);

class RadioPlayerPage extends StatefulWidget {
  const RadioPlayerPage({super.key});

  @override
  State<RadioPlayerPage> createState() => _RadioPlayerPageState();
}

class _RadioPlayerPageState extends State<RadioPlayerPage> {
  late final RadioPlayerService _player;

  @override
  void initState() {
    super.initState();
    _player = RadioPlayerService();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _player,
      builder: (context, _) => _RadioPlayerView(player: _player),
    );
  }
}

class _RadioPlayerView extends StatelessWidget {
  const _RadioPlayerView({required this.player});

  final RadioPlayerService player;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0FFCC), Color(0xFFFFFFFF)],
            stops: [0.0, 0.5],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: BibleFmCover(
                        isActive: player.isPlaying && !player.isLoading,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LiveIconButton(
                      isLiveMode: player.isLiveMode,
                      onLiveTap: player.goLive,
                    ),
                    const SizedBox(width: 18),
                    DurationLabel(elapsed: player.displayedElapsed),
                  ],
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PlayButton(
                    isPlaying: player.isPlaying,
                    isLoading: player.isLoading,
                    onTap: player.togglePlayPause,
                  ),
                ),
                SizedBox(height: constraints.maxHeight > 760 ? 24 : 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BibleFmCover extends StatelessWidget {
  const BibleFmCover({
    super.key,
    required this.isActive,
  });

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 420,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            color: const Color(0xFFF0FFCC),
            child: Row(
              children: [
                Text(
                  'BIBLE FM',
                  style: GoogleFonts.russoOne(
                    color: _uiAccent,
                    fontSize: 44,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz_rounded,
                  color: _uiAccent.withValues(alpha: 0.85),
                  size: 34,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _FallbackCover(isActive: isActive),
        ],
      ),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.isActive});
  static const Color _micColor = Color(0xFF00260F);
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF003719),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _micColor.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        child: _MindfulnessVisualizer(isActive: isActive),
      ),
    );
  }
}

class _MindfulnessVisualizer extends StatefulWidget {
  const _MindfulnessVisualizer({required this.isActive});

  final bool isActive;

  @override
  State<_MindfulnessVisualizer> createState() => _MindfulnessVisualizerState();
}

class _MindfulnessVisualizerState extends State<_MindfulnessVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MindfulnessVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _controller.repeat();
    } else {
      _controller.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _MindfulnessVisualizerPainter(
            progress: _controller.value,
            isActive: widget.isActive,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _MindfulnessVisualizerPainter extends CustomPainter {
  const _MindfulnessVisualizerPainter({
    required this.progress,
    required this.isActive,
  });

  final double progress;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final t = isActive ? progress : 0.0;
    final paint = Paint()
      ..color = const Color(0xFFF0FFCC).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    // Visualizer de rádio em barras segmentadas.
    const columns = 10;
    const maxSegments = 14;
    final usableWidth = size.width * 0.88;
    final startX = (size.width - usableWidth) / 2;
    final barWidth = usableWidth / (columns * 1.3);
    final gapX = barWidth * 0.3;
    final segmentHeight = 11.0;
    final segmentGap = 4.0;
    final baselineY = size.height * 0.93;

    for (var i = 0; i < columns; i++) {
      final phase = (i * 0.62) + (t * 2 * pi);
      final normalized = (sin(phase) + 1) / 2;
      final centerShape =
          1 - ((i - (columns - 1) / 2).abs() / (columns / 2)) * 0.22;
      final activeSegments = isActive
          ? (4 + (normalized * (maxSegments - 4) * centerShape)).round()
          : 3;

      final x = startX + i * (barWidth + gapX);
      for (var s = 0; s < activeSegments; s++) {
        final y = baselineY - (s + 1) * segmentHeight - s * segmentGap;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, segmentHeight),
          const Radius.circular(2.2),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MindfulnessVisualizerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isActive != isActive;
  }
}

class LiveIconButton extends StatelessWidget {
  const LiveIconButton({
    super.key,
    required this.isLiveMode,
    required this.onLiveTap,
  });

  final bool isLiveMode;
  final VoidCallback onLiveTap;

  @override
  Widget build(BuildContext context) {
    final color = isLiveMode ? _uiAccent : _uiAccent.withValues(alpha: 0.7);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onLiveTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isLiveMode
              ? _uiAccent.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(color: color, width: 1.4),
        ),
        child: Center(child: _LiveWavesIcon(color: color, size: 30)),
      ),
    );
  }
}

class _LiveWavesIcon extends StatelessWidget {
  const _LiveWavesIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LiveWavesPainter(color: color)),
    );
  }
}

class _LiveWavesPainter extends CustomPainter {
  const _LiveWavesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ponto central
    canvas.drawCircle(center, 2.6, fill);

    // ondas internas e externas
    final innerRect = Rect.fromCircle(
      center: center,
      radius: size.width * 0.23,
    );
    final outerRect = Rect.fromCircle(
      center: center,
      radius: size.width * 0.36,
    );

    canvas.drawArc(innerRect, -2.3, 1.5, false, stroke);
    canvas.drawArc(innerRect, 0.8, 1.5, false, stroke);
    canvas.drawArc(outerRect, -2.3, 1.5, false, stroke);
    canvas.drawArc(outerRect, 0.8, 1.5, false, stroke);
  }

  @override
  bool shouldRepaint(covariant _LiveWavesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class DurationLabel extends StatelessWidget {
  const DurationLabel({super.key, required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatBadgeDuration(elapsed),
      style: GoogleFonts.russoOne(
        fontSize: 56,
        letterSpacing: 1,
        color: _uiAccent,
      ),
    );
  }
}

String _formatBadgeDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final hours = d.inHours.toString().padLeft(2, '0');
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
