import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:meu_app/features/radio/services/radio_player_controller.dart';

/// Watches playback progress and notifies when a stall is detected.
class StallDetector {
  StallDetector({
    required this.player,
    required this.getLifecycle,
    required this.getStallThreshold,
    required this.getWatchdogTick,
    required this.getStallSignalsBeforeRecover,
    required this.onStallDetected,
  });

  final AudioPlayer player;
  final RadioPlaybackLifecycle Function() getLifecycle;
  final Duration Function() getStallThreshold;
  final Duration Function() getWatchdogTick;
  final int Function() getStallSignalsBeforeRecover;
  final Future<void> Function() onStallDetected;

  Timer? _timer;
  Duration _lastPosition = Duration.zero;
  DateTime? _lastProgressAt;
  Duration _lastBufferedPosition = Duration.zero;
  DateTime? _lastBufferedProgressAt;
  int _stallSignals = 0;
  bool _isSwitchingSource = false;
  bool _isRecovering = false;

  void updateSwitching({required bool isSwitching}) {
    _isSwitchingSource = isSwitching;
  }

  void updateRecovering({required bool isRecovering}) {
    _isRecovering = isRecovering;
  }

  void onPositionUpdate(Duration position) {
    if (position < _lastPosition) {
      _lastPosition = position;
      _lastProgressAt = DateTime.now();
    } else if (position > _lastPosition) {
      _lastProgressAt = DateTime.now();
      _lastPosition = position;
    }
  }

  void onBufferedPositionUpdate(Duration buffered) {
    if (buffered < _lastBufferedPosition) {
      _lastBufferedPosition = buffered;
      _lastBufferedProgressAt = DateTime.now();
    } else if (buffered > _lastBufferedPosition) {
      _lastBufferedPosition = buffered;
      _lastBufferedProgressAt = DateTime.now();
    }
  }

  void syncWatchdog() {
    final lifecycle = getLifecycle();
    final watching = lifecycle == RadioPlaybackLifecycle.preparing ||
        lifecycle == RadioPlaybackLifecycle.buffering ||
        lifecycle == RadioPlaybackLifecycle.reconnecting ||
        lifecycle == RadioPlaybackLifecycle.playing;

    if (!watching) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _lastProgressAt ??= DateTime.now();
    _lastBufferedProgressAt ??= DateTime.now();
    _timer ??= Timer.periodic(getWatchdogTick(), (_) async {
      if (_isSwitchingSource || _isRecovering) return;
      final lifecycleNow = getLifecycle();

      final now = DateTime.now();
      final elapsedSinceProgress = now.difference(_lastProgressAt!);
      final elapsedSinceBufferedProgress =
          now.difference(_lastBufferedProgressAt!);
      final threshold = getStallThreshold();

      final isStalledWhilePlaying =
          lifecycleNow == RadioPlaybackLifecycle.playing &&
              player.playing &&
              player.processingState == ProcessingState.ready &&
              elapsedSinceProgress >= threshold &&
              elapsedSinceBufferedProgress >= threshold;

      final isStalledWhileBuffering =
          (lifecycleNow == RadioPlaybackLifecycle.preparing ||
                  lifecycleNow == RadioPlaybackLifecycle.buffering ||
                  lifecycleNow == RadioPlaybackLifecycle.reconnecting) &&
              elapsedSinceProgress >= threshold &&
              elapsedSinceBufferedProgress >= threshold;

      if (isStalledWhilePlaying || isStalledWhileBuffering) {
        _stallSignals++;
      } else {
        _stallSignals = 0;
      }

      if (_stallSignals >= getStallSignalsBeforeRecover()) {
        _stallSignals = 0;
        await onStallDetected();
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

