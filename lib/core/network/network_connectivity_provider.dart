import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` quando não há interface com rede (Wi‑Fi, dados móveis, etc.).
/// Não garante acesso à Internet (ex.: portal cativo); o fluxo de áudio trata falhas à parte.
final networkOfflineProvider =
    StateNotifierProvider<NetworkConnectivityNotifier, bool>((ref) {
  return NetworkConnectivityNotifier();
});

class NetworkConnectivityNotifier extends StateNotifier<bool> {
  NetworkConnectivityNotifier() : super(false) {
    _connectivity = Connectivity();
    initialConnectivityFuture = _bootstrap();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _apply,
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('networkOfflineProvider stream: $e\n$st');
        }
      },
    );
  }

  late final Connectivity _connectivity;
  late final Future<void> initialConnectivityFuture;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Primeira leitura da plataforma; útil antes do arranque automático do leitor.
  Future<void> _bootstrap() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      // Mantém o último estado se a verificação inicial falhar.
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);
    if (state != offline) {
      state = offline;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
