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
  ProcessingState _cachedProcessingState = ProcessingState.idle;
  bool _cachedPlaying = false;

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
        !_isRecovering) {
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

    ref.listen<BufferingProfile>(bufferingProfileProvider, (_, next) {
      setBufferingProfile(next);
    });

    _playerStateSub = _player.playerStateStream.listen((playerState) {
      final processing = playerState.processingState;
      final playing = playerState.playing;

      _cachedProcessingState = processing;
      _cachedPlaying = playing;

      final lifecycle = _computedLifecycle;

      Object? errorMessageUpdate = _noStateChange;
      if (lifecycle == RadioPlaybackLifecycle.error &&
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

    unawaited(_bindAudioSessionEvents());
    unawaited(_bootstrapAutoPlay());
    return state;
  }

  Future<void> _bindAudioSessionEvents() async {
    final session = await AudioSession.instance;

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.pause) {
          if (_player.playing) {
            _resumeAfterInterruption = true;
            unawaited(_player.pause());
            state = state.copyWith(
              lifecycle: RadioPlaybackLifecycle.paused,
              errorMessage: null,
            );
          }
          return;
        }
        if (event.type == AudioInterruptionType.duck) {
          unawaited(_player.setVolume(0.5));
        }
        return;
      }

      if (event.type == AudioInterruptionType.duck) {
        unawaited(_player.setVolume(1.0));
        return;
      }

      if (_resumeAfterInterruption && !_player.playing) {
        _resumeAfterInterruption = false;
        state = state.copyWith(
          lifecycle: RadioPlaybackLifecycle.preparing,
          errorMessage: null,
        );
        unawaited(_playWithRetry(maxAttempts: 3));
      }
    });

    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
      if (!_player.playing) return;
      unawaited(_player.pause());
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
    if (!_allowActionNow()) return;
    if (state.isBuffering) return;

    if (_player.playing) {
      await _player.pause();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.paused,
        isLiveMode: false,
        isLiveIntent: false,
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
  }

  /// Orchestrates an atomic "LIVE" transition.
  ///
  /// Responsibilities:
  /// - Debounce + anti-buffering guards
  /// - Prepare UI/state immediately
  /// - Execute stop -> configure -> play in a safe sequence
  /// - Confirm or fail, without duplicating lifecycle logic
  Future<void> goLive() async {
    if (!_allowActionNow()) return;
    if (state.isBuffering) return;
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
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.idle,
        elapsed: Duration.zero,
        errorMessage: null,
        isLiveMode: false,
      );
    } catch (e, st) {
      debugPrint('Falha ao parar audio no encerramento: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _playWithRetry({int? maxAttempts}) async {
    _hasPlaybackAttempted = true;
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

  Future<void> _recoverFromStall({String reason = 'unknown'}) async {
    if (_isSwitchingSource || _isRecovering) return;
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
      await _configureSource(forceRefresh: true);
      await _playWithRetry();
    } catch (e, st) {
      debugPrint('Falha na recuperacao de stall: $e');
      debugPrint(st.toString());
      _handlePlaybackError(e);
    } finally {
      _isRecovering = false;
      _isSwitchingSource = false;
      _stallDetector?.updateRecovering(isRecovering: false);
    }
  }

  void _handlePlaybackError(Object error) {
    if (_isRecovering || _isSwitchingSource) return;
    state = state.copyWith(
      lifecycle: RadioPlaybackLifecycle.reconnecting,
      errorMessage: 'Échec du flux. Tentative de reconnexion...',
    );
    unawaited(_recoverFromStall(reason: 'central_error_handler'));
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

final bufferingProfileProvider =
    StateProvider<BufferingProfile>((ref) => BufferingProfile.stable);

