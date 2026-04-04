import 'package:flutter/widgets.dart';

/// Stubs para VM/testes; na Web usa-se `web_native_audio_web.dart`.
Future<void> bibleFmWebReloadLiveStream(String baseUrl) async {}

void bibleFmWebBackgroundTapPlayPause() {}

void bibleFmWebPausePlayback() {}

void bibleFmWebSetSleepConfiguratorOpen(bool open) {}

void bibleFmWebAttachScrollBridge(
  ScrollController? vertical,
  ScrollController? horizontal,
) {}

void bibleFmWebDetachScrollBridge() {}

void bibleFmWebBackgroundLongPressGoLive() {}

void bibleFmWebSeekRelativeSeconds(double deltaSec) {}

final bibleFmWebPlaybackActive = ValueNotifier<bool>(false);
final bibleFmWebLiveReloading = ValueNotifier<bool>(false);
final bibleFmWebLiveEdgeActive = ValueNotifier<bool>(false);
final bibleFmWebBuffering = ValueNotifier<bool>(false);
final bibleFmWebSessionEverStarted = ValueNotifier<bool>(false);
final bibleFmWebLiveMovedWhilePausedSec = ValueNotifier<double?>(null);

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
