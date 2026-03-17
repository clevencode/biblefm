import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_app/core/constants/stream_config.dart';

/// Reproduz o stream da rádio (play/pause) e notifica ouvintes.
class RadioPlayerService extends ChangeNotifier {
  RadioPlayerService() {
    _player.onPlayerStateChanged.listen(_onStateChanged);
  }

  final AudioPlayer _player = AudioPlayer();

  bool isPlaying = false;
  bool isLoading = false;
  bool isLiveMode = false;
  Duration elapsed = Duration.zero;
  Duration _elapsedCache = Duration.zero;
  Timer? _timer;
  DateTime? _sessionStartedAt;

  /// Duração usada na UI. Durante carregamento de LIVE, mantém cache para não piscar.
  Duration get displayedElapsed => isLoading ? _elapsedCache : elapsed;

  static const Duration _maxElapsed = Duration(hours: 1);

  String _liveStreamUrl() {
    final uri = Uri.parse(kRadioStreamUrl);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            't': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        )
        .toString();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (elapsed >= _maxElapsed) {
        elapsed = _maxElapsed;
        _elapsedCache = elapsed;
        _stopTimer();
        notifyListeners();
        return;
      }
      elapsed += const Duration(seconds: 1);
      _elapsedCache = elapsed;
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onStateChanged(PlayerState state) {
    isPlaying = state == PlayerState.playing;
    if (state == PlayerState.playing ||
        state == PlayerState.paused ||
        state == PlayerState.stopped) {
      isLoading = false;
    }
    if (state == PlayerState.playing) {
      // Garante uma referencia de inicio para calcular tempo real no LIVE.
      _sessionStartedAt ??= DateTime.now().subtract(elapsed);
      if (elapsed >= _maxElapsed) {
        // Começa nova sessao ao ultrapassar o limite.
        elapsed = Duration.zero;
        _elapsedCache = elapsed;
        _sessionStartedAt = DateTime.now();
      }
      _startTimer();
    } else {
      _stopTimer();
    }
    notifyListeners();
  }

  /// Entra no modo ao vivo e reinicia a contagem da sessao.
  Future<void> goLive() async {
    if (isLoading) return;

    // Mantem valor atual na UI durante reconexao.
    _elapsedCache = elapsed;
    isLiveMode = true;

    // Ao voltar para LIVE, avanca para o tempo real decorrido da sessao.
    if (_sessionStartedAt != null) {
      final realElapsed = DateTime.now().difference(_sessionStartedAt!);
      elapsed = realElapsed > _maxElapsed ? _maxElapsed : realElapsed;
    }

    isLoading = true;
    notifyListeners();

    try {
      // Forca reconexao no stream atual para voltar ao "live edge".
      await _player.stop();
      await _player.play(UrlSource(_liveStreamUrl()));
    } catch (_) {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (isLoading) return;

    if (isPlaying) {
      isLiveMode = false;
      await _player.pause();
      _stopTimer();
      notifyListeners();
      return;
    }

    // Retoma/reinicia a reproducao sem resetar a contagem.
    isLiveMode = false;
    isLoading = true;
    notifyListeners();

    try {
      await _player.play(UrlSource(kRadioStreamUrl));
    } catch (_) {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _player.dispose();
    super.dispose();
  }
}
