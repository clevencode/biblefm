import 'package:flutter/material.dart';

/// Sem elemento HTML fora da web.
Future<void> bibleFmWebReloadLiveStream(String baseUrl) async {}

/// Fora da web: sem-op.
void bibleFmWebBackgroundTapPlayPause() {}

/// Fora da web: sem-op.
void bibleFmWebPausePlayback() {}

/// Fora da web: sem-op.
void bibleFmWebSetSleepConfiguratorOpen(bool open) {}

/// Fora da web: sem-op.
void bibleFmWebAttachScrollBridge(
  ScrollController? vertical,
  ScrollController? horizontal,
) {}

/// Fora da web: sem-op.
void bibleFmWebDetachScrollBridge() {}

/// Fora da web: sem-op.
void bibleFmWebBackgroundLongPressGoLive() {}

/// Fora de `dart:html` mantém-se em false (testes / análise VM).
final bibleFmWebPlaybackActive = ValueNotifier<bool>(false);

/// Fora da web não actualiza.
final bibleFmWebLiveReloading = ValueNotifier<bool>(false);

/// Fora da web não actualiza.
final bibleFmWebLiveEdgeActive = ValueNotifier<bool>(false);

/// Fora da web não actualiza.
final bibleFmWebBuffering = ValueNotifier<bool>(false);

/// Fora da web não actualiza.
final bibleFmWebSessionEverStarted = ValueNotifier<bool>(false);

/// Secondes derrière le bord «live» du tampon (mode écoute) ; null si N/A.
final bibleFmWebBufferBehindLiveSec = ValueNotifier<double?>(null);

/// Largeur du tampon navigateur (fin − début) en secondes ; null si N/A.
final bibleFmWebBufferWindowSec = ValueNotifier<double?>(null);

/// Implementação vazia (não web). Ver `web_native_audio_web.dart`.
class WebNativeAudioControls extends StatelessWidget {
  const WebNativeAudioControls({
    super.key,
    required this.streamUrl,
    this.controlsHeight = 44,
  });

  final String streamUrl;
  final double controlsHeight;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
