import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/core/network/network_connectivity_provider.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/screens/player_ui_models.dart';

/// Estado da UI do leitor + reprodução real ([AudioPlayer] + stream).
@immutable
class RadioPlayerUiState {
  const RadioPlayerUiState({
    required this.lifecycle,
    required this.elapsed,
    required this.isLiveMode,
    required this.livePulseActive,
    required this.liveSyncEligible,
    this.errorMessage,
  });

  factory RadioPlayerUiState.initial() => const RadioPlayerUiState(
        lifecycle: UiPlaybackLifecycle.idle,
        elapsed: Duration.zero,
        isLiveMode: false,
        livePulseActive: false,
        liveSyncEligible: true,
        errorMessage: null,
      );

  final UiPlaybackLifecycle lifecycle;
  final Duration elapsed;
  final bool isLiveMode;
  final bool livePulseActive;
  /// Após uma pausa, permite alinhar o contador ao direct; consome-se ao tocar em live até nova pausa.
  final bool liveSyncEligible;
  final String? errorMessage;

  bool get isPlaying => lifecycle == UiPlaybackLifecycle.playing;

  /// Direct: só o botão «live» activa [isLiveMode]; play/pause fica em écoute.
  /// - [paused]: permite tocar em «live» para entrar em direct.
  /// - [playing] sem live: permite passar a modo live.
  /// - [playing] com live a tocar: não (já em direct).
  bool get canTapLive {
    if (isBufferingUiLifecycle(lifecycle)) return false;
    if (lifecycle == UiPlaybackLifecycle.idle) return false;
    if (lifecycle == UiPlaybackLifecycle.paused) return true;
    return !isLiveMode;
  }

  /// «En direct»: a tocar, sem buffer, com modo live.
  bool get isEnDirect =>
      isPlaying && !isBufferingUiLifecycle(lifecycle) && isLiveMode;

  /// O contador só avança em reprodução efectiva (não em buffering).
  bool get shouldRunElapsedTicker =>
      isPlaying && !isBufferingUiLifecycle(lifecycle);

  RadioPlayerUiState copyWith({
    UiPlaybackLifecycle? lifecycle,
    Duration? elapsed,
    bool? isLiveMode,
    bool? livePulseActive,
    bool? liveSyncEligible,
    Object? errorMessage = _sentinel,
  }) {
    return RadioPlayerUiState(
      lifecycle: lifecycle ?? this.lifecycle,
      elapsed: elapsed ?? this.elapsed,
      isLiveMode: isLiveMode ?? this.isLiveMode,
      livePulseActive: livePulseActive ?? this.livePulseActive,
      liveSyncEligible: liveSyncEligible ?? this.liveSyncEligible,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _sentinel = Object();
}

final radioPlayerUiProvider =
    StateNotifierProvider<RadioPlayerUiNotifier, RadioPlayerUiState>((ref) {
  final notifier = RadioPlayerUiNotifier(ref);
  // Pausa/para o áudio quando a rede cai, mesmo fora da [RadioPlayerPage]
  // (ex.: segundo plano). Ignora o primeiro evento ([previous] null).
  ref.listen<RadioNetworkLink>(networkLinkProvider, (previous, next) {
    if (previous == null) return;
    if (next != RadioNetworkLink.offline) return;
    if (previous == RadioNetworkLink.offline) return;
    unawaited(notifier.pauseDueToNetworkLoss());
  });
  return notifier;
});

/// Regras de negócio da UI + `just_audio` / notificação em segundo plano.
///
/// **Responsabilidades (botões / entradas públicas):**
/// - [transportTap] — só o controlo **play/pause** e anular carregamento em buffer;
///   não activa «en direct».
/// - [liveTap] — só o botão **live**: modo direct, contador de *catch-up* e nova
///   ligação ao fluxo (borda ao vivo).
/// - [retryAfterError], [pauseDueToNetworkLoss], [onConnectivityRestored] —
///   reacções de sistema / rede, não são botões de transporte.
class RadioPlayerUiNotifier extends StateNotifier<RadioPlayerUiState> {
  RadioPlayerUiNotifier(this._ref) : super(RadioPlayerUiState.initial()) {
    _player = AudioPlayer();
    _playerStateSub = _player.playerStateStream.listen(
      _onPlayerState,
      onError: _onPlayerStateError,
    );
  }

  final Ref _ref;
  bool get _isOffline => _ref.read(networkOfflineProvider);

  void _onPlayerStateError(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('RadioPlayerUiNotifier playerStateStream: $error\n$stack');
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'radio_player_ui_provider',
        context: ErrorDescription('playerStateStream'),
      ),
    );
  }

  /// Passo de «rattrapage» vers le direct (UI). Plusieurs taps après pause
  /// rapprochent le compteur du bord live sans le ramener à zéro d’un coup.
  static const Duration _liveCatchUpChunk = Duration(seconds: 30);

  /// Plancher après un tap live : ne pas effacer le contador (≠ 0).
  static const Duration _minElapsedAfterLiveTap = Duration(seconds: 1);

  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSub;

  Timer? _elapsedTicker;
  bool _sourceLoaded = false;
  /// Evita que o stream reconcile `idle` antes de `setAudioSource` avançar (race com «preparing»).
  bool _deferPlayerIdle = false;
  /// Evita toques repetidos em «live» durante uma nova ligação ao fluxo.
  bool _liveReloadInFlight = false;

  /// Avança o contador em direcção ao instante mais recente, em [chunk]s,
  /// sem [Duration.zero] imposto por um único toque.
  Duration _elapsedAfterLiveTap(Duration current, {required bool consumeSync}) {
    if (!consumeSync) return current;
    if (current <= Duration.zero) {
      return _minElapsedAfterLiveTap;
    }
    final reduced = current - _liveCatchUpChunk;
    if (reduced < _minElapsedAfterLiveTap) {
      return _minElapsedAfterLiveTap;
    }
    return reduced;
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    unawaited(_playerStateSub?.cancel() ?? Future<void>.value());
    unawaited(_player.dispose());
    super.dispose();
  }

  void _emit(RadioPlayerUiState next) {
    state = next;
    _syncElapsedTicker();
  }

  /// Apresentação **écoute** (sem «en direct»): só altera flags de UI do modo live.
  /// O [AudioPlayer] é tratado à parte pelo chamador ([transportTap], rede, etc.).
  RadioPlayerUiState _ecouteLivePresentation(RadioPlayerUiState s) {
    return s.copyWith(
      isLiveMode: false,
      livePulseActive: false,
      liveSyncEligible: true,
    );
  }

  void _onPlayerState(PlayerState playerState) {
    if (_deferPlayerIdle &&
        playerState.processingState == ProcessingState.idle) {
      return;
    }
    if (playerState.processingState != ProcessingState.idle) {
      _deferPlayerIdle = false;
    }
    final ps = playerState.processingState;
    final playing = playerState.playing;

    final UiPlaybackLifecycle nextLifecycle;
    switch (ps) {
      case ProcessingState.idle:
        nextLifecycle = UiPlaybackLifecycle.idle;
        break;
      case ProcessingState.loading:
        nextLifecycle = UiPlaybackLifecycle.preparing;
        break;
      case ProcessingState.buffering:
        nextLifecycle = UiPlaybackLifecycle.buffering;
        break;
      case ProcessingState.ready:
        nextLifecycle =
            playing ? UiPlaybackLifecycle.playing : UiPlaybackLifecycle.paused;
        break;
      case ProcessingState.completed:
        nextLifecycle = UiPlaybackLifecycle.idle;
        break;
    }

    if (nextLifecycle != state.lifecycle) {
      state = state.copyWith(lifecycle: nextLifecycle);
      _syncElapsedTicker();
    }
  }

  /// Mantém o [Timer.periodic] alinhado com [RadioPlayerUiState.shouldRunElapsedTicker].
  void _syncElapsedTicker() {
    if (state.shouldRunElapsedTicker) {
      _startElapsedTicker();
    } else {
      _stopElapsedTicker();
    }
  }

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (!s.shouldRunElapsedTicker) return;
      state = s.copyWith(elapsed: s.elapsed + const Duration(seconds: 1));
    });
  }

  void _stopElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
  }

  /// Só [liveTap]: contador + `isLiveMode`; limpa erro obsoleto (escopo do botão live).
  void _activateLiveModeUi({required bool consumeLiveSync}) {
    final nextElapsed = _elapsedAfterLiveTap(
      state.elapsed,
      consumeSync: consumeLiveSync,
    );
    _emit(
      state.copyWith(
        isLiveMode: true,
        errorMessage: null,
        elapsed: nextElapsed,
        liveSyncEligible: false,
      ),
    );
  }

  /// Nova ligação HTTP ao mesmo endpoint (query única) para saltar o buffer acumulado
  /// e ouvir o instante actual do Icecast — boa prática em streams sem seek.
  AudioSource _liveSource({bool bustCache = false}) {
    var uri = Uri.parse(kBibleFmLiveStreamUrl);
    if (bustCache) {
      final q = Map<String, String>.from(uri.queryParameters);
      q['_'] = DateTime.now().millisecondsSinceEpoch.toString();
      uri = uri.replace(queryParameters: q);
    }
    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: kBibleFmMediaItemId,
        title: kBibleFmNotificationTitle,
        displayTitle: kBibleFmNotificationTitle,
        artist: kBibleFmNotificationArtist,
        displayDescription: kBibleFmNotificationDescription,
        genre: kBibleFmMediaGenre,
        isLive: true,
      ),
    );
  }

  Future<void> _ensureSourceLoaded() async {
    if (_sourceLoaded) return;
    try {
      await _player.setAudioSource(_liveSource(bustCache: false));
      _sourceLoaded = true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('RadioPlayerUiNotifier: setAudioSource failed: $e\n$stack');
      }
      rethrow;
    }
  }

  static String _loadErrorMessage(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset')) {
      return 'Sem ligação ao servidor. Verifique a rede.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Tempo esgotado. Tente novamente.';
    }
    if (lower.contains('certificate') || lower.contains('handshake')) {
      return 'Erro de segurança na ligação (TLS). Tente mais tarde.';
    }
    if (raw.length > 160) {
      return '${raw.substring(0, 157)}…';
    }
    return raw;
  }

  /// Chamado quando a interface de rede volta (ex.: Wi‑Fi/dados). Limpa erro
  /// «pendente» em idle para o utilizador voltar a iniciar sem passo extra.
  void onConnectivityRestored() {
    if (state.lifecycle != UiPlaybackLifecycle.idle) return;
    if (state.errorMessage == null) return;
    _emit(state.copyWith(errorMessage: null));
  }

  /// Transição **online → offline**: para de consumir rede e bateria de forma
  /// previsível. Não reutiliza [transportTap] (evita misturar com dismiss de erro).
  ///
  /// - A tocar: [pause] (o utilizador retoma quando quiser, com rede).
  /// - A preparar / em buffer: [stop] → [idle] (não deixa loading preso offline).
  /// - [idle] / [paused]: sem efeito.
  Future<void> pauseDueToNetworkLoss() async {
    switch (state.lifecycle) {
      case UiPlaybackLifecycle.idle:
      case UiPlaybackLifecycle.paused:
        return;
      case UiPlaybackLifecycle.preparing:
      case UiPlaybackLifecycle.buffering:
        _deferPlayerIdle = false;
        try {
          await _player.stop();
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('pauseDueToNetworkLoss stop: $e\n$stack');
          }
        }
        _emit(
          _ecouteLivePresentation(state).copyWith(
            lifecycle: UiPlaybackLifecycle.idle,
            errorMessage: null,
          ),
        );
        return;
      case UiPlaybackLifecycle.playing:
        try {
          await _player.pause();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('pauseDueToNetworkLoss pause: $e\n$stack');
        }
        _emit(_ecouteLivePresentation(state));
        return;
    }
  }

  /// Arranque da app: inicia a reprodução em **écoute** (sem «en direct» até tocar em live).
  Future<void> autoStartLivePlayback() async {
    if (state.lifecycle != UiPlaybackLifecycle.idle) return;
    if (state.errorMessage != null) {
      _emit(state.copyWith(errorMessage: null));
    }
    try {
      await transportTap();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('autoStartLivePlayback: $e\n$stack');
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'radio_player_ui_provider',
          context: ErrorDescription('autoStartLivePlayback'),
        ),
      );
    }
  }

  /// Botão **play/pause** (e cancelar buffer): transporte de leitura apenas.
  Future<void> transportTap() async {
    if (state.errorMessage != null) {
      _emit(state.copyWith(errorMessage: null));
      return;
    }

    if (_isOffline) {
      switch (state.lifecycle) {
        case UiPlaybackLifecycle.idle:
        case UiPlaybackLifecycle.paused:
          return;
        case UiPlaybackLifecycle.playing:
        case UiPlaybackLifecycle.preparing:
        case UiPlaybackLifecycle.buffering:
          break;
      }
    }

    switch (state.lifecycle) {
      case UiPlaybackLifecycle.preparing:
      case UiPlaybackLifecycle.buffering:
        _deferPlayerIdle = false;
        try {
          await _player.stop();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('stop during buffer: $e\n$stack');
        }
        _emit(
          _ecouteLivePresentation(state).copyWith(
            lifecycle: UiPlaybackLifecycle.idle,
            errorMessage: null,
          ),
        );
        return;

      case UiPlaybackLifecycle.playing:
        try {
          await _player.pause();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('pause: $e\n$stack');
        }
        _emit(_ecouteLivePresentation(state));
        return;

      case UiPlaybackLifecycle.paused:
        try {
          await _player.play();
        } catch (e, stack) {
          if (kDebugMode) debugPrint('play: $e\n$stack');
        }
        _emit(_ecouteLivePresentation(state));
        return;

      case UiPlaybackLifecycle.idle:
        _deferPlayerIdle = true;
        _emit(
          state.copyWith(
            lifecycle: UiPlaybackLifecycle.preparing,
            elapsed: Duration.zero,
            liveSyncEligible: true,
            isLiveMode: false,
            livePulseActive: false,
            errorMessage: null,
          ),
        );
        try {
          await _ensureSourceLoaded();
          await _player.play();
        } catch (e, stack) {
          if (kDebugMode) {
            debugPrint('Radio start failed: $e\n$stack');
          }
          _deferPlayerIdle = false;
          _sourceLoaded = false;
          _emit(
            state.copyWith(
              lifecycle: UiPlaybackLifecycle.idle,
              errorMessage: _loadErrorMessage(e),
            ),
          );
        }
        return;
    }
  }

  /// Botão **live** apenas: activa modo direct na UI, alinha contador e religa o fluxo.
  void liveTap() {
    if (_isOffline) return;
    if (!state.canTapLive) return;
    if (_liveReloadInFlight) return;
    _liveReloadInFlight = true;
    _activateLiveModeUi(consumeLiveSync: state.liveSyncEligible);
    unawaited(_reloadLiveStreamToCurrentEdge());
  }

  /// Só para [liveTap]: [stop] + nova fonte (cache-bust) + [play] — borda ao vivo.
  Future<void> _reloadLiveStreamToCurrentEdge() async {
    _deferPlayerIdle = true;
    try {
      try {
        await _player.stop();
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('reloadLive stop: $e\n$stack');
        }
      }
      await _player.setAudioSource(_liveSource(bustCache: true));
      _sourceLoaded = true;
      await _player.play();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('reloadLiveStreamToCurrentEdge: $e\n$stack');
      }
      _deferPlayerIdle = false;
      _sourceLoaded = false;
      _emit(
        state.copyWith(
          lifecycle: UiPlaybackLifecycle.idle,
          isLiveMode: false,
          livePulseActive: false,
          liveSyncEligible: true,
          errorMessage: _loadErrorMessage(e),
        ),
      );
    } finally {
      _liveReloadInFlight = false;
    }
  }

  void resetElapsed() {
    _emit(state.copyWith(elapsed: Duration.zero));
  }

  void retryAfterError() {
    unawaited(_retryAfterErrorAsync());
  }

  Future<void> _retryAfterErrorAsync() async {
    try {
      await _player.stop();
    } catch (_) {}
    _deferPlayerIdle = false;
    _sourceLoaded = false;
    _emit(
      state.copyWith(
        errorMessage: null,
        lifecycle: UiPlaybackLifecycle.idle,
        livePulseActive: false,
        liveSyncEligible: true,
        isLiveMode: false,
      ),
    );
  }

  void toggleLivePulse() {
    if (!state.isEnDirect) return;
    _emit(state.copyWith(livePulseActive: !state.livePulseActive));
  }
}
