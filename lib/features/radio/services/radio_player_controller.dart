import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:meu_app/features/radio/services/audio_source_manager.dart';
import 'package:meu_app/features/radio/services/retry_policy.dart';
import 'package:meu_app/features/radio/services/session_timer.dart';
import 'package:meu_app/features/radio/services/stall_detector.dart';

const _noStateChange = Object();

enum RadioPlaybackLifecycle {
  idle,
  preparing,
  buffering,
  playing,
  paused,
  reconnecting,
  error,
}

enum BufferingProfile {
  stable,
  ultra,
}

enum LiveTransitionStatus {
  idle,
  started,
  confirmed,
  failed,
}

enum _PendingPlayerAction {
  togglePlayPause,
  goLive,
  /// Controlo central da UI: fila e política próprias (ver [_runCentralPlaybackControlAction]).
  centralPlayback,
}

class RadioPlayerState {
  const RadioPlayerState({
    required this.lifecycle,
    required this.elapsed,
    required this.errorMessage,
    required this.isLiveMode,
    required this.isLiveIntent,
    required this.liveTransitionStatus,
  });

  final RadioPlaybackLifecycle lifecycle;
  final Duration elapsed;
  final String? errorMessage;
  final bool isLiveMode;
  final bool isLiveIntent;
  final LiveTransitionStatus liveTransitionStatus;

  bool get isPlaying => lifecycle == RadioPlaybackLifecycle.playing;
  bool get isBuffering =>
      lifecycle == RadioPlaybackLifecycle.preparing ||
      lifecycle == RadioPlaybackLifecycle.buffering ||
      lifecycle == RadioPlaybackLifecycle.reconnecting;

  RadioPlayerState copyWith({
    RadioPlaybackLifecycle? lifecycle,
    Duration? elapsed,
    Object? errorMessage = _noStateChange,
    bool? isLiveMode,
    bool? isLiveIntent,
    LiveTransitionStatus? liveTransitionStatus,
  }) {
    return RadioPlayerState(
      lifecycle: lifecycle ?? this.lifecycle,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: identical(errorMessage, _noStateChange)
          ? this.errorMessage
          : errorMessage as String?,
      isLiveMode: isLiveMode ?? this.isLiveMode,
      isLiveIntent: isLiveIntent ?? this.isLiveIntent,
      liveTransitionStatus:
          liveTransitionStatus ?? this.liveTransitionStatus,
    );
  }

  static const initial = RadioPlayerState(
    lifecycle: RadioPlaybackLifecycle.idle,
    elapsed: Duration.zero,
    errorMessage: null,
    isLiveMode: false,
    isLiveIntent: false,
    liveTransitionStatus: LiveTransitionStatus.idle,
  );
}

class RadioPlayerController extends Notifier<RadioPlayerState> {
  static const Duration _minActionInterval = Duration(milliseconds: 450);
  static const Duration _minCentralActionInterval = Duration(milliseconds: 300);
  static const Duration _recoveryWindow = Duration(minutes: 1);
  static final AudioPlayer _sharedPlayer = AudioPlayer(
    handleInterruptions: false,
  );

  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<Duration>? _bufferedPositionSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();
  StreamSubscription<Object>? _errorSub;
  bool _sourceConfigured = false;
  bool _hasPlaybackAttempted = false;
  bool _isSwitchingSource = false;
  Future<void>? _sourceLock;
  late final AudioSourceManager _audioSourceManager;
  late RetryPolicy _retryPolicy;
  StallDetector? _stallDetector;
  SessionTimer? _sessionTimer;
  bool _isRecovering = false;
  bool _resumeAfterInterruption = false;
  DateTime? _lastRecoveryAt;
  BufferingProfile _bufferingProfile = BufferingProfile.stable;
  DateTime _recoveryWindowStart = DateTime.now();
  int _recoveriesInWindow = 0;
  DateTime? _lastActionAt;
  DateTime? _lastCentralActionAt;
  ProcessingState _cachedProcessingState = ProcessingState.idle;
  bool _cachedPlaying = false;
  bool _isOperationInFlight = false;
  bool _didRegisterOnDispose = false;
  _PendingPlayerAction? _pendingAction;
  bool _drainInProgress = false;
  bool _cancelRecoveryRequested = false;

  Duration get _stallThreshold => _bufferingProfile == BufferingProfile.stable
      ? const Duration(seconds: 12)
      : const Duration(seconds: 6);

  Duration get _watchdogTick => _bufferingProfile == BufferingProfile.stable
      ? const Duration(seconds: 4)
      : const Duration(seconds: 2);

  Duration get _recoveryCooldown => _bufferingProfile == BufferingProfile.stable
      ? const Duration(seconds: 4)
      : const Duration(seconds: 2);

  int get _stallSignalsBeforeRecover =>
      _bufferingProfile == BufferingProfile.stable ? 2 : 1;

  int get _maxRecoveriesPerWindow =>
      _bufferingProfile == BufferingProfile.stable ? 3 : 5;

  int get _retryAttempts => _bufferingProfile == BufferingProfile.stable ? 5 : 4;

  /// Single source of truth for the lifecycle exposed to the UI.
  ///
  /// This method centralizes lifecycle decisions and prevents duplicated
  /// mappings scattered across streams and callbacks.
  RadioPlaybackLifecycle get _computedLifecycle {
    // Highest priority: user explicitly asked for live transition.
    if (state.isLiveIntent &&
        (_isSwitchingSource || state.liveTransitionStatus == LiveTransitionStatus.started)) {
      return RadioPlaybackLifecycle.reconnecting;
    }

    if (_isRecovering) {
      return RadioPlaybackLifecycle.reconnecting;
    }

    final processing = _cachedProcessingState;
    final playing = _cachedPlaying;

    if (processing == ProcessingState.loading) {
      return RadioPlaybackLifecycle.preparing;
    }

    if (processing == ProcessingState.buffering) {
      return RadioPlaybackLifecycle.buffering;
    }

    // "Real playing" happens only when the player reports ready+playing.
    if (playing && processing == ProcessingState.ready) {
      return RadioPlaybackLifecycle.playing;
    }

    if (!playing && processing == ProcessingState.ready) {
      return RadioPlaybackLifecycle.paused;
    }

    // Idle state can be "error" when we know we attempted playback.
    if (processing == ProcessingState.idle &&
        _hasPlaybackAttempted &&
        !_isSwitchingSource &&
        !_isRecovering &&
        !_isOperationInFlight) {
      return RadioPlaybackLifecycle.error;
    }

    return RadioPlaybackLifecycle.idle;
  }

  @override
  RadioPlayerState build() {
    state = RadioPlayerState.initial;
    _player = _sharedPlayer;
    _audioSourceManager = AudioSourceManager();
    _retryPolicy = RetryPolicy(maxAttempts: _retryAttempts);
    _sessionTimer = SessionTimer(
      shouldRunForLifecycle: (lifecycle) =>
          lifecycle == RadioPlaybackLifecycle.playing,
      onTick: (elapsed) {
        state = state.copyWith(elapsed: elapsed);
      },
    );
    _stallDetector = StallDetector(
      player: _player,
      getLifecycle: () => state.lifecycle,
      getStallThreshold: () => _stallThreshold,
      getWatchdogTick: () => _watchdogTick,
      getStallSignalsBeforeRecover: () => _stallSignalsBeforeRecover,
      onStallDetected: () => _recoverFromStall(reason: 'watchdog'),
    );

    _playerStateSub = _player.playerStateStream.listen((playerState) {
      final processing = playerState.processingState;
      final playing = playerState.playing;

      _cachedProcessingState = processing;
      _cachedPlaying = playing;

      final lifecycle = _computedLifecycle;
      // Ajusta o comportamento do StallDetector conforme a fase atual.
      // Em transições/instabilidade usamos "ultra" (limiares mais baixos).
      final shouldUseUltra = lifecycle == RadioPlaybackLifecycle.preparing ||
          lifecycle == RadioPlaybackLifecycle.buffering ||
          lifecycle == RadioPlaybackLifecycle.reconnecting;
      setBufferingProfile(shouldUseUltra ? BufferingProfile.ultra : BufferingProfile.stable);

      Object? errorMessageUpdate = _noStateChange;
      if (lifecycle == RadioPlaybackLifecycle.error &&
          !_isOperationInFlight &&
          !(state.liveTransitionStatus == LiveTransitionStatus.failed &&
              state.isLiveMode == false)) {
        errorMessageUpdate = 'Échec du chargement du flux';
      } else if (lifecycle == RadioPlaybackLifecycle.playing ||
          lifecycle == RadioPlaybackLifecycle.paused) {
        errorMessageUpdate = null;
      }

      state = state.copyWith(
        lifecycle: lifecycle,
        errorMessage: errorMessageUpdate,
      );

      _stallDetector?.syncWatchdog();
      _sessionTimer?.sync(lifecycle);
    });

    _eventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace st) {
        debugPrint('Erro no playbackEventStream: $error');
        debugPrint(st.toString());
        _errorController.add(error);
      },
    );

    _errorSub = _errorController.stream.listen((error) {
      _handlePlaybackError(error);
    });

    _positionSub = _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 300),
          maxPeriod: const Duration(milliseconds: 900),
        )
        .listen((position) {
      _stallDetector?.onPositionUpdate(position);
    });

    _bufferedPositionSub =
        _player.bufferedPositionStream.listen((buffered) {
      _stallDetector?.onBufferedPositionUpdate(buffered);
    });

    unawaited(
      _bindAudioSessionEvents().catchError((Object e, StackTrace st) {
        debugPrint('bindAudioSessionEvents falhou: $e');
        debugPrint(st.toString());
      }),
    );
    unawaited(_bootstrapAutoPlay());

    // `Notifier` não necessariamente expõe `dispose()` nesta versão.
    // Usamos o ciclo de vida do provider para fazer cleanup determinístico.
    if (!_didRegisterOnDispose) {
      _didRegisterOnDispose = true;
      ref.onDispose(disposeController);
    }
    return state;
  }

  Future<void> _bindAudioSessionEvents() async {
    final session = await AudioSession.instance;

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.pause) {
          if (_player.playing) {
            _resumeAfterInterruption = true;
            unawaited(
              _player.pause().catchError((Object e, StackTrace st) {
                debugPrint('pause após interrupção falhou: $e');
                debugPrint(st.toString());
              }),
            );
            state = state.copyWith(
              lifecycle: RadioPlaybackLifecycle.paused,
              errorMessage: null,
            );
          }
          return;
        }
        if (event.type == AudioInterruptionType.duck) {
          unawaited(
            _player.setVolume(0.5).catchError((Object e, StackTrace st) {
              debugPrint('setVolume(0.5) falhou: $e');
              debugPrint(st.toString());
            }),
          );
        }
        return;
      }

      if (event.type == AudioInterruptionType.duck) {
        unawaited(
          _player.setVolume(1.0).catchError((Object e, StackTrace st) {
            debugPrint('setVolume(1.0) falhou: $e');
            debugPrint(st.toString());
          }),
        );
        return;
      }

      if (_resumeAfterInterruption && !_player.playing) {
        _resumeAfterInterruption = false;
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.preparing,
          errorMessage: null,
        );
        unawaited(
          _playWithRetry(maxAttempts: 3).catchError((Object e, StackTrace st) {
            debugPrint('Reprise après interruption impossible: $e');
            debugPrint(st.toString());
            state = state.copyWith(
              lifecycle: RadioPlaybackLifecycle.error,
              errorMessage:
                  'Impossible de reprendre après interruption. Réessayez.',
            );
          }),
        );
      }
    });

    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
      if (!_player.playing) return;
      unawaited(
        _player.pause().catchError((Object e, StackTrace st) {
          debugPrint('pause ao trocar saída falhou: $e');
          debugPrint(st.toString());
        }),
      );
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.paused,
        errorMessage: 'Audio mis en pause après changement de sortie.',
      );
    });
  }

  void setBufferingProfile(BufferingProfile profile) {
    if (_bufferingProfile == profile) return;
    _bufferingProfile = profile;
    _stallDetector?.dispose();
    _stallDetector = StallDetector(
      player: _player,
      getLifecycle: () => state.lifecycle,
      getStallThreshold: () => _stallThreshold,
      getWatchdogTick: () => _watchdogTick,
      getStallSignalsBeforeRecover: () => _stallSignalsBeforeRecover,
      onStallDetected: () => _recoverFromStall(reason: 'watchdog'),
    );
    _lastRecoveryAt = null;
    _resetRecoveryWindow();
    _stallDetector?.syncWatchdog();
  }

  Future<void> _bootstrapAutoPlay() async {
    try {
      state = state.copyWith(isLiveMode: false);
      await _configureSource(forceRefresh: true);
      await _playWithRetry();
    } catch (e, st) {
      debugPrint('Falha ao iniciar reproducao automatica: $e');
      debugPrint(st.toString());
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Impossible de démarrer l\'audio automatiquement',
      );
    }
  }

  Future<void> _configureSource({bool forceRefresh = false}) async {
    if (_sourceConfigured && !forceRefresh) return;
    if (_sourceLock != null) return _sourceLock!;

    final completer = Completer<void>();
    _sourceLock = completer.future;
    try {
      _isSwitchingSource = true;
      await _audioSourceManager.configureSource(
        _player,
        forceRefresh: forceRefresh,
      );
      _sourceConfigured = true;
      completer.complete();
    } catch (e, st) {
      _audioSourceManager.registerEndpointFailure(
        _audioSourceManager.activeStreamUri,
      );
      _sourceConfigured = false;
      debugPrint('Falha ao configurar source: $e');
      debugPrint(st.toString());
      _errorController.add(e);
      completer.completeError(e, st);
      rethrow;
    } finally {
      _isSwitchingSource = false;
      _sourceLock = null;
    }
  }

  Future<void> togglePlayPause() async {
    _requestPlayerAction(_PendingPlayerAction.togglePlayPause);
  }

  /// Ação do botão central: não reutiliza [togglePlayPause]; usa fila própria,
  /// debounce mais curto e, ao iniciar áudio, força refresh da source.
  Future<void> centralPlaybackControl() async {
    _requestPlayerAction(_PendingPlayerAction.centralPlayback);
  }

  Future<void> _runTogglePlayPauseAction() async {
    _isOperationInFlight = true;
    try {
      if (_player.playing) {
        await _player.pause();
        // Evita que o `_computedLifecycle` entre em `error` por causa de flags
        // internas deixadas de operações anteriores (ex.: idle+attempt).
        _hasPlaybackAttempted = false;
        _isRecovering = false;
        _isSwitchingSource = false;
        _cachedProcessingState = ProcessingState.idle;
        _cachedPlaying = false;
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.paused,
          isLiveMode: false,
          isLiveIntent: false,
          errorMessage: null,
          liveTransitionStatus: LiveTransitionStatus.idle,
        );
        return;
      }

      try {
        _resetRecoveryWindow();
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.preparing,
          errorMessage: null,
          isLiveMode: false,
          isLiveIntent: false,
          liveTransitionStatus: LiveTransitionStatus.idle,
        );
        await _configureSource();
        await _playWithRetry();
      } catch (_) {
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.error,
          errorMessage: 'Erreur lors de la préparation du flux',
          isLiveMode: false,
          isLiveIntent: false,
          liveTransitionStatus: LiveTransitionStatus.failed,
        );
      }
    } finally {
      _isOperationInFlight = false;
      unawaited(_drainPendingActions());
    }
  }

  Future<void> _runCentralPlaybackControlAction() async {
    // Debounce em [_drainPendingActions] (antes de limpar [_pendingAction]).
    _isOperationInFlight = true;
    try {
      // Alinhar com o estado da app (não só com o ExoPlayer): em buffering a UI
      // pode ainda não marcar "playing", mas o fluxo está ativo e deve parar.
      // Não usar só _sourceConfigured: com lifecycle idle poderia bloquear o arranque.
      final streamActive = state.lifecycle != RadioPlaybackLifecycle.idle ||
          _player.playing ||
          _player.processingState != ProcessingState.idle;

      if (streamActive) {
        // Parar totalmente e desconectar do link do stream.
        _stallDetector?.updateSwitching(isSwitching: true);
        _sessionTimer?.reset();
        try {
          await _player.stop();
        } catch (e, st) {
          debugPrint('central stop: $e');
          debugPrint(st.toString());
        }
        _hasPlaybackAttempted = false;
        _isRecovering = false;
        _isSwitchingSource = false;
        _sourceConfigured = false;
        _cachedProcessingState = ProcessingState.idle;
        _cachedPlaying = false;
        _stallDetector?.updateSwitching(isSwitching: false);
        _stallDetector?.syncWatchdog();
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.idle,
          elapsed: Duration.zero,
          isLiveMode: false,
          isLiveIntent: false,
          errorMessage: null,
          liveTransitionStatus: LiveTransitionStatus.idle,
        );
        return;
      }

      try {
        _resetRecoveryWindow();
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.preparing,
          errorMessage: null,
          isLiveMode: false,
          isLiveIntent: false,
          liveTransitionStatus: LiveTransitionStatus.idle,
        );
        // Política específica do controlo central: sempre refrescar o endpoint
        // ao iniciar (o toggle da barra pode reutilizar source já configurada).
        await _configureSource(forceRefresh: true);
        await _playWithRetry();
      } catch (_) {
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.error,
          errorMessage:
              'Erreur via le contrôle central. Réessayez ou utilisez la barre.',
          isLiveMode: false,
          isLiveIntent: false,
          liveTransitionStatus: LiveTransitionStatus.failed,
        );
      }
    } finally {
      _isOperationInFlight = false;
      unawaited(_drainPendingActions());
    }
  }

  /// Orchestrates an atomic "LIVE" transition.
  ///
  /// Responsibilities:
  /// - Debounce + anti-buffering guards
  /// - Prepare UI/state immediately
  /// - Execute stop -> configure -> play in a safe sequence
  /// - Confirm or fail, without duplicating lifecycle logic
  Future<void> goLive() async {
    _requestPlayerAction(_PendingPlayerAction.goLive);
  }

  Future<void> _runGoLiveAction() async {
    if (state.isLiveIntent &&
        state.liveTransitionStatus == LiveTransitionStatus.started) {
      return;
    }

    _prepareForLive();

    try {
      await _executeLiveTransition();
      await _handleLiveSuccess();
    } catch (e) {
      await _handleLiveFailure(e);
    }
  }

  void _prepareForLive() {
    // Reset counter deterministically at the moment the user intent is set.
    _sessionTimer?.reset();
    _resetRecoveryWindow();

    state = state.copyWith(
      errorMessage: null,
      isLiveMode: true,
      isLiveIntent: true,
      liveTransitionStatus: LiveTransitionStatus.started,
      elapsed: Duration.zero,
    );
  }

  Future<void> _executeLiveTransition() async {
    // Prevent the stall detector from triggering during the transition.
    _stallDetector?.updateSwitching(isSwitching: true);
    _isOperationInFlight = true;
    try {
      await _player.stop();
      await _configureSource(forceRefresh: true);

      _hasPlaybackAttempted = true;
      _retryPolicy = RetryPolicy(maxAttempts: _retryAttempts);

      await _retryPolicy.execute(
        () async {
          await _player.play();
          _audioSourceManager.registerEndpointSuccess(
            _audioSourceManager.activeStreamUri,
          );
          _recoveriesInWindow = 0;
        },
        onFailure: (attempt, error, st) async {
          debugPrint('LIVE retry $attempt failed: $error');
          debugPrint(st.toString());
          _audioSourceManager.registerEndpointFailure(
            _audioSourceManager.activeStreamUri,
          );
          _sourceConfigured = false;
          // Reconfigure to pick a healthier endpoint before retrying play.
          await _configureSource(forceRefresh: true);
        },
      );
    } finally {
      _stallDetector?.updateSwitching(isSwitching: false);
      _isOperationInFlight = false;
      unawaited(_drainPendingActions());
    }
  }

  Future<void> _handleLiveSuccess() async {
    // Confirm the user intent. From this point, _computedLifecycle can
    // reflect the real player state (playing/paused/etc).
    state = state.copyWith(
      isLiveIntent: false,
      liveTransitionStatus: LiveTransitionStatus.confirmed,
      errorMessage: null,
    );

    // Analytics hook (debug-only placeholder).
    debugPrint('LIVE confirmed');
  }

  Future<void> _handleLiveFailure(Object error) async {
    // Freeze timer and fallback to non-live UI state.
    _sessionTimer?.sync(RadioPlaybackLifecycle.paused);

    state = state.copyWith(
      errorMessage: 'Erreur lors de la reconnexion en direct',
      isLiveMode: false,
      isLiveIntent: false,
      liveTransitionStatus: LiveTransitionStatus.failed,
    );

    debugPrint('LIVE failure: $error');
  }

  Future<void> stopForAppExit() async {
    try {
      _stallDetector?.dispose();
      _sessionTimer?.reset();
      await _player.stop();
      // Garante estado interno limpo para futuras reativações do provider.
      _hasPlaybackAttempted = false;
      _isRecovering = false;
      _isSwitchingSource = false;
      _cachedProcessingState = ProcessingState.idle;
      _cachedPlaying = false;
      _lastRecoveryAt = null;
      _resetRecoveryWindow();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.idle,
        elapsed: Duration.zero,
        errorMessage: null,
        isLiveMode: false,
        isLiveIntent: false,
        liveTransitionStatus: LiveTransitionStatus.idle,
      );
    } catch (e, st) {
      debugPrint('Falha ao parar audio no encerramento: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _playWithRetry({int? maxAttempts}) async {
    _hasPlaybackAttempted = true;
    _isOperationInFlight = true;
    state = state.copyWith(errorMessage: null);
    _retryPolicy = RetryPolicy(maxAttempts: maxAttempts ?? _retryAttempts);
    final startedLiveIntent = state.isLiveIntent;

    try {
      await _retryPolicy.execute(
        () async {
          await _player.play();
          _audioSourceManager.registerEndpointSuccess(
            _audioSourceManager.activeStreamUri,
          );
          _recoveriesInWindow = 0;
          state = state.copyWith(
            lifecycle: RadioPlaybackLifecycle.playing,
            liveTransitionStatus: startedLiveIntent
                ? LiveTransitionStatus.confirmed
                : LiveTransitionStatus.idle,
          );
        },
        onFailure: (attempt, error, st) async {
          debugPrint('Tentativa $attempt de play falhou: $error');
          debugPrint(st.toString());
          _audioSourceManager.registerEndpointFailure(
            _audioSourceManager.activeStreamUri,
          );
          _sourceConfigured = false;
          try {
            await _configureSource(forceRefresh: true);
          } catch (_) {
            // Continua com backoff; o proximo ciclo tenta novamente.
          }
        },
      );
    } catch (e) {
      _isOperationInFlight = false;
      _errorController.add(e);
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage:
            'Erreur au démarrage du flux. Vérifiez votre connexion.',
        isLiveIntent: false,
        liveTransitionStatus: startedLiveIntent
            ? LiveTransitionStatus.failed
            : LiveTransitionStatus.idle,
      );
    } finally {
      _isOperationInFlight = false;
      unawaited(_drainPendingActions());
    }
  }

  bool _allowActionNow() {
    final now = DateTime.now();
    if (_lastActionAt != null &&
        now.difference(_lastActionAt!) < _minActionInterval) {
      return false;
    }
    _lastActionAt = now;
    return true;
  }

  bool _allowCentralActionNow() {
    final now = DateTime.now();
    if (_lastCentralActionAt != null &&
        now.difference(_lastCentralActionAt!) < _minCentralActionInterval) {
      return false;
    }
    _lastCentralActionAt = now;
    return true;
  }

  /// Estados em que o utilizador pode querer **parar / mudar de modo** sem esperar
  /// pelo debounce (UX: não bloquear transporte por causa de buffering/reconnexion).
  bool _loadingLifecycleAllowsImmediateTransportTap() {
    final l = state.lifecycle;
    return l == RadioPlaybackLifecycle.preparing ||
        l == RadioPlaybackLifecycle.buffering ||
        l == RadioPlaybackLifecycle.reconnecting;
  }

  Future<void> _waitUntilRecoveryFinished() async {
    while (_isRecovering) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _recoverFromStall({String reason = 'unknown'}) async {
    if (_isSwitchingSource || _isRecovering) return;
    if (_cancelRecoveryRequested) {
      _cancelRecoveryRequested = false;
      return;
    }
    final now = DateTime.now();
    if (_lastRecoveryAt != null &&
        now.difference(_lastRecoveryAt!) < _recoveryCooldown) {
      return;
    }
    if (!_consumeRecoverySlot()) {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Flux instable. Réessayez dans quelques instants.',
      );
      return;
    }
    _lastRecoveryAt = now;
    _isRecovering = true;
    _stallDetector?.updateRecovering(isRecovering: true);
    try {
      debugPrint('Iniciando recuperacao de stall ($reason)');
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.reconnecting,
        errorMessage: 'Reconnexion au flux...',
      );
      _isSwitchingSource = true;
      _audioSourceManager.registerEndpointFailure(
        _audioSourceManager.activeStreamUri,
      );
      await _player.stop();
      if (_cancelRecoveryRequested) {
        _cancelRecoveryRequested = false;
        return;
      }
      await _configureSource(forceRefresh: true);
      if (_cancelRecoveryRequested) {
        _cancelRecoveryRequested = false;
        return;
      }
      await _playWithRetry();
    } catch (e, st) {
      debugPrint('Falha na recuperacao de stall: $e');
      debugPrint(st.toString());
      _handlePlaybackError(e);
    } finally {
      _isRecovering = false;
      _isSwitchingSource = false;
      _stallDetector?.updateRecovering(isRecovering: false);
      unawaited(_drainPendingActions());
    }
  }

  void _requestPlayerAction(_PendingPlayerAction action) {
    // Última ação ganha.
    _pendingAction = action;

    // Pré-empcao simples de recovery quando o usuário interage.
    if (_isRecovering) {
      _cancelRecoveryRequested = true;
    }

    unawaited(_drainPendingActions());
  }

  /// Não incluir [_isRecovering]: a fila espera explicitamente com cancelamento
  /// (evita “congelar” toques enquanto a recuperação corre; ver [_waitUntilRecoveryFinished]).
  bool get _isBusy =>
      _sourceLock != null ||
      _isSwitchingSource ||
      _isOperationInFlight;

  Future<void> _drainPendingActions() async {
    if (_drainInProgress) return;
    _drainInProgress = true;
    try {
      while (_pendingAction != null) {
        if (_isRecovering) {
          _cancelRecoveryRequested = true;
          await _waitUntilRecoveryFinished();
        }
        if (_isBusy) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          continue;
        }

        // Debounce: barra/live aqui; controlo central antes de limpar a fila
        // (evita descartar o toque se o debounce falhar).
        if (_pendingAction == _PendingPlayerAction.centralPlayback) {
          if (_loadingLifecycleAllowsImmediateTransportTap()) {
            _lastCentralActionAt = DateTime.now();
          } else if (!_allowCentralActionNow()) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            continue;
          }
        } else {
          if (_loadingLifecycleAllowsImmediateTransportTap()) {
            _lastActionAt = DateTime.now();
          } else {
            while (!_allowActionNow()) {
              await Future<void>.delayed(const Duration(milliseconds: 40));
              if (_pendingAction == null) return;
            }
          }
        }

        final action = _pendingAction!;
        _pendingAction = null;
        if (action == _PendingPlayerAction.goLive) {
          await _runGoLiveAction();
        } else if (action == _PendingPlayerAction.centralPlayback) {
          await _runCentralPlaybackControlAction();
        } else {
          await _runTogglePlayPauseAction();
        }
      }
    } finally {
      _drainInProgress = false;
      if (_pendingAction != null) {
        unawaited(_drainPendingActions());
      }
    }
  }

  void _handlePlaybackError(Object error) {
    if (_isRecovering || _isSwitchingSource) return;
    state = state.copyWith(
      lifecycle: RadioPlaybackLifecycle.reconnecting,
      errorMessage: 'Échec du flux. Tentative de reconnexion...',
    );
    unawaited(
      _recoverFromStall(reason: 'central_error_handler')
          .catchError((Object e, StackTrace st) {
        debugPrint('Erreur non gérée dans recoverFromStall: $e');
        debugPrint(st.toString());
      }),
    );
  }

  bool _consumeRecoverySlot() {
    final now = DateTime.now();
    if (now.difference(_recoveryWindowStart) > _recoveryWindow) {
      _recoveryWindowStart = now;
      _recoveriesInWindow = 0;
    }
    if (_recoveriesInWindow >= _maxRecoveriesPerWindow) {
      return false;
    }
    _recoveriesInWindow++;
    return true;
  }

  void _resetRecoveryWindow() {
    _recoveryWindowStart = DateTime.now();
    _recoveriesInWindow = 0;
  }

  void disposeController() {
    _stallDetector?.dispose();
    _sessionTimer?.dispose();
    _positionSub?.cancel();
    _bufferedPositionSub?.cancel();
    _playerStateSub?.cancel();
    _eventSub?.cancel();
    _interruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    _errorSub?.cancel();
    _errorController.close();
  }
}

final radioPlayerControllerProvider =
    NotifierProvider<RadioPlayerController, RadioPlayerState>(
  RadioPlayerController.new,
);

