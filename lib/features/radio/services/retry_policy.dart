import 'dart:math';
import 'package:flutter/foundation.dart';

/// Encapsulates retry behaviour with exponential backoff and jitter.
class RetryPolicy {
  RetryPolicy({
    required this.maxAttempts,
    this.minBackoffMs = 180,
    this.maxBackoffMs = 2000,
  }) : _random = Random();

  final int maxAttempts;
  final int minBackoffMs;
  final int maxBackoffMs;
  final Random _random;

  /// Executes [action] with retry, calling [onFailure] after each failure.
  Future<void> execute(
    Future<void> Function() action, {
    Future<void> Function(int attempt, Object error, StackTrace st)?
        onFailure,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await action();
        return;
      } catch (e, st) {
        if (onFailure != null) {
          try {
            await onFailure(attempt, e, st);
          } catch (onFailureError, onFailureSt) {
            // Falha secundária no handler de onFailure não deve quebrar o loop
            // de retry; mantemos o erro original como contexto.
            debugPrint(
              'RetryPolicy.onFailure falhou (tentativa=$attempt): $onFailureError',
            );
            debugPrint(onFailureSt.toString());
          }
        }
        if (attempt == maxAttempts) {
          rethrow;
        }
        final exponential = minBackoffMs * (1 << (attempt - 1));
        final baseMs =
            exponential.clamp(minBackoffMs, maxBackoffMs).toInt();
        final jitterMs = _random.nextInt(minBackoffMs);
        await Future<void>.delayed(
          Duration(milliseconds: baseMs + jitterMs),
        );
      }
    }
  }
}

