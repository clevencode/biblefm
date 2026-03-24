import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ícone estilo emissão: ponto central e ondas `(( • ))` — mobile-first, escala com [size].
class BroadcastSignalIcon extends StatelessWidget {
  const BroadcastSignalIcon({
    super.key,
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BroadcastSignalPainter(color: color),
    );
  }
}

class _BroadcastSignalPainter extends CustomPainter {
  _BroadcastSignalPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.09)
      ..strokeCap = StrokeCap.round;

    final dotR = r * 0.12;
    canvas.drawCircle(c, dotR, Paint()..color = color);

    const sweep = math.pi * 0.48;
    for (var i = 1; i <= 3; i++) {
      final arcR = dotR + r * 0.15 * i;
      final rect = Rect.fromCircle(center: c, radius: arcR);
      // Esquerda e direita do ponto (estilo (( • ))).
      canvas.drawArc(rect, math.pi - sweep / 2, sweep, false, stroke);
      canvas.drawArc(rect, -sweep / 2, sweep, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BroadcastSignalPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
