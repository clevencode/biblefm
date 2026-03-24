import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/features/radio/services/radio_bridge_providers.dart';
import 'package:meu_app/features/radio/services/radio_player_controller.dart';
import 'package:meu_app/features/radio/utils/radio_ui_invocation.dart';
import 'package:meu_app/features/radio/widgets/live_mode_button.dart';
import 'package:meu_app/features/radio/widgets/play_button.dart';

/// Barra inferior: **play** circular à esquerda, **live** em pílula à direita.
class RadioTransportControls extends ConsumerWidget {
  const RadioTransportControls({
    super.key,
    required this.scale,
    required this.playVisualSize,
    required this.isDark,
    required this.narrowMobile,
  });

  final double scale;
  final double playVisualSize;
  final bool isDark;
  final bool narrowMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycle = ref.watch(radioLifecycleProvider);
    final isPlaying = ref.watch(radioIsPlayingProvider);
    final isLiveMode = ref.watch(radioIsLiveProvider);
    final liveTransitionBusy = ref.watch(radioLiveTransitionBusyProvider);
    final notifier = ref.read(radioPlayerControllerProvider.notifier);

    final isBuffering = _isBufferingLifecycle(lifecycle);

    void scheduleGoLive() {
      scheduleRadioPlayerAction(
        () => notifier.goLive(),
        debugLabel: 'goLive',
      );
    }

    void scheduleCentralPlayback() {
      scheduleRadioPlayerAction(
        () => notifier.centralPlaybackControl(),
        debugLabel: 'centralPlaybackControl',
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PlayButton(
          isPlaying: isPlaying,
          isLoading: isBuffering,
          onTap: scheduleCentralPlayback,
          size: playVisualSize,
          layoutScale: scale,
        ),
        LiveModeButton(
          isLiveMode: isLiveMode,
          isTransitioning: liveTransitionBusy,
          onPressed: scheduleGoLive,
          scale: scale,
          size: playVisualSize,
          isDark: isDark,
          pillShaped: true,
          narrowMobile: narrowMobile,
        ),
      ],
    );
  }
}

bool _isBufferingLifecycle(RadioPlaybackLifecycle lifecycle) {
  return lifecycle == RadioPlaybackLifecycle.preparing ||
      lifecycle == RadioPlaybackLifecycle.buffering ||
      lifecycle == RadioPlaybackLifecycle.reconnecting;
}
