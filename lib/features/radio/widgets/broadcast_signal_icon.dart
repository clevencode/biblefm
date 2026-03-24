import 'package:flutter/material.dart';

/// Ícone de **emissão / rádio** para a pílula «live»: traçado vectorial
/// [Icons.podcasts_rounded] — linhas suaves, nítido em qualquer escala (estilo
/// próximo dos símbolos SF «ondas + centro» sem o ruído de um CustomPaint denso).
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
    return Semantics(
      excludeSemantics: true,
      child: Icon(
        Icons.podcasts_rounded,
        size: size,
        color: color,
      ),
    );
  }
}
