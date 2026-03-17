import 'package:flutter/material.dart';

const Color _playAccent = Color(0xFF00260F);

/// Botao principal de reproducao sem container.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  @override
  Widget build(BuildContext context) {
    // Trocamos entre play e pause sem animacoes de pulso.
    final iconData =
        widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;

    return Semantics(
      button: true,
      label: widget.isLoading
          ? 'Carregando'
          : widget.isPlaying
              ? 'Pausar transmissao'
              : 'Retomar transmissao',
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onTap,
        child: SizedBox(
          width: 96,
          height: 96,
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _playAccent,
                    ),
                  )
                : Icon(
                    iconData,
                    size: 72,
                    color: _playAccent,
                  ),
          ),
        ),
      ),
    );
  }
}
