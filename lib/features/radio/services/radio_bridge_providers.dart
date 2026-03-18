import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/features/radio/services/radio_player_controller.dart';

/// Bridge providers that expose granular slices of the radio state.
/// This keeps widgets lightweight and focused on exactly what they need.

final radioLifecycleProvider = Provider<RadioPlaybackLifecycle>((ref) {
  return ref
      .watch(radioPlayerControllerProvider.select((s) => s.lifecycle));
});

final radioElapsedProvider = Provider<Duration>((ref) {
  return ref.watch(radioPlayerControllerProvider.select((s) => s.elapsed));
});

final radioErrorProvider = Provider<String?>((ref) {
  return ref
      .watch(radioPlayerControllerProvider.select((s) => s.errorMessage));
});

final radioIsLiveProvider = Provider<bool>((ref) {
  return ref.watch(radioPlayerControllerProvider.select((s) => s.isLiveMode));
});

final radioIsPlayingProvider = Provider<bool>((ref) {
  return ref.watch(radioPlayerControllerProvider.select((s) => s.isPlaying));
});

