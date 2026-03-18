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

class RadioPlayerState {
  const RadioPlayerState({
    required this.lifecycle,
    required this.elapsed,
    required this.errorMessage,
    required this.isLiveMode,
  });

  final RadioPlaybackLifecycle lifecycle;
  final Duration elapsed;
  final String? errorMessage;
  final bool isLiveMode;

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
  }) {
    return RadioPlayerState(
      lifecycle: lifecycle ?? this.lifecycle,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: identical(errorMessage, _noStateChange)
          ? this.errorMessage
          : errorMessage as String?,
      isLiveMode: isLiveMode ?? this.isLiveMode,
    );
  }

  static const initial = RadioPlayerState(
    lifecycle: RadioPlaybackLifecycle.idle,
    elapsed: Duration.zero,
    errorMessage: null,
    isLiveMode: false,
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

      RadioPlaybackLifecycle lifecycle;
      if (_isSwitchingSource) {
        lifecycle = RadioPlaybackLifecycle.reconnecting;
      } else if (processing == ProcessingState.loading) {
        lifecycle = RadioPlaybackLifecycle.preparing;
      } else if (processing == ProcessingState.buffering) {
        lifecycle = RadioPlaybackLifecycle.buffering;
      } else if (playing && processing == ProcessingState.ready) {
        lifecycle = RadioPlaybackLifecycle.playing;
      } else if (!playing && processing == ProcessingState.ready) {
        lifecycle = RadioPlaybackLifecycle.paused;
      } else {
        lifecycle = RadioPlaybackLifecycle.idle;
      }

      Object? errorMessageUpdate = _noStateChange;
      if (processing == ProcessingState.idle &&
          _hasPlaybackAttempted &&
          !_isSwitchingSource &&
          !_isRecovering) {
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
      );
      return;
    }

    try {
      _resetRecoveryWindow();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.preparing,
        errorMessage: null,
        isLiveMode: false,
      );
      await _configureSource();
      await _playWithRetry();
    } catch (_) {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Erreur lors de la préparation du flux',
        isLiveMode: false,
      );
    }
  }

  Future<void> goLive() async {
    if (!_allowActionNow()) return;
    if (state.isBuffering) return;
    try {
      _sessionTimer?.reset();
      _resetRecoveryWindow();
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.reconnecting,
        errorMessage: null,
        isLiveMode: true,
        elapsed: Duration.zero,
      );
      _isSwitchingSource = true;
      await _player.stop();
      await _configureSource(forceRefresh: true);
      _isSwitchingSource = false;
      await _playWithRetry();
    } catch (_) {
      state = state.copyWith(
        lifecycle: RadioPlaybackLifecycle.error,
        errorMessage: 'Erreur lors de la reconnexion en direct',
        isLiveMode: false,
      );
    } finally {
      _isSwitchingSource = false;
    }
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

    try {
      await _retryPolicy.execute(
        () async {
          await _player.play();
          _audioSourceManager.registerEndpointSuccess(
            _audioSourceManager.activeStreamUri,
          );
          _recoveriesInWindow = 0;
          state = state.copyWith(lifecycle: RadioPlaybackLifecycle.playing);
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

