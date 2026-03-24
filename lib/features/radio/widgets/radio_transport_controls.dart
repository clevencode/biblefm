import 'package:flutter/material.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';
import 'package:meu_app/features/radio/widgets/live_mode_button.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

/// Barra inferior: **play** circular à esquerda, **live** em pílula à direita.
class RadioTransportControls extends StatelessWidget {
  const RadioTransportControls({
    super.key,
    required this.scale,
    required this.playVisualSize,
    required this.narrowMobile,
    required this.isOffline,
    required this.playbackLifecycle,
    required this.isPlaying,
    required this.isPaused,
    required this.isBuffering,
    required this.isPreparing,
    required this.isLiveMode,
    required this.onTransportTap,
    required this.onLiveTap,
  });

  final double scale;
  final double playVisualSize;
  final bool narrowMobile;
  /// Sem interface de rede: limita play (exceto pausa / cancelar buffer) e direct.
  final bool isOffline;
  /// Ordem dos estados: idle → preparar → buffer → play/pause; direct só após fluxo.
  final UiPlaybackLifecycle playbackLifecycle;
  final bool isPlaying;
  final bool isPaused;
  final bool isBuffering;
  /// Só [preparing] (antes de [buffering]) — texto distinto no botão play.
  final bool isPreparing;
  final bool isLiveMode;
  /// Botão play/pause — só transporte ([RadioPlayerUiNotifier.transportTap]).
  final VoidCallback onTransportTap;
  /// Botão live — só modo direct ([RadioPlayerUiNotifier.liveTap]); null se indisponível.
  final VoidCallback? onLiveTap;

  @override
  Widget build(BuildContext context) {
    final playEnabled =
        !isOffline || isPlaying || isBuffering;

    return Semantics(
      container: true,
      label: isOffline
          ? 'Contrôles de lecture (hors ligne : pause ou annuler le chargement uniquement)'
          : 'Ordre : lecture ou pause, puis direct à droite une fois le flux prêt',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayButton(
            isPlaying: isPlaying,
            isLoading: isBuffering,
            isPreparing: isPreparing,
            onTap: onTransportTap,
            size: playVisualSize,
            layoutScale: scale,
            enabled: playEnabled,
            isOffline: isOffline,
          ),
          LiveModeButton(
            playbackLifecycle: playbackLifecycle,
            isLiveMode: isLiveMode,
            isPaused: isPaused,
            isOffline: isOffline,
            onPressed: onLiveTap,
            scale: scale,
            size: playVisualSize,
            narrowMobile: narrowMobile,
          ),
        ],
      ),
    );
  }
}
