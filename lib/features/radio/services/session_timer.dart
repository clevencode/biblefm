import 'dart:async';

import 'package:meu_app/features/radio/services/radio_player_controller.dart';

/// Tracks a continuous listening session time, independent of stream resets.
class SessionTimer {
  SessionTimer({
    required this.shouldRunForLifecycle,
    required this.onTick,
  });

  final bool Function(RadioPlaybackLifecycle lifecycle) shouldRunForLifecycle;
  final void Function(Duration elapsed) onTick;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _lastTickAt;

  Duration get elapsed => _elapsed;

  void sync(RadioPlaybackLifecycle lifecycle) {
    final shouldRun = shouldRunForLifecycle(lifecycle);

    if (!shouldRun) {
      _ticker?.cancel();
      _ticker = null;
      _lastTickAt = null;
      return;
    }

    _lastTickAt ??= DateTime.now();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final last = _lastTickAt ?? now;
      final diff = now.difference(last);
      _lastTickAt = now;
      _elapsed += diff;
      onTick(_elapsed);
    });
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _lastTickAt = null;
    _elapsed = Duration.zero;
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }
}

