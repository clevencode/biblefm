import 'dart:math';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/core/audio/audio_runtime_config.dart';
import 'package:meu_app/core/constants/stream_config.dart';

/// Handles endpoint selection, penalties and audio source configuration.
class AudioSourceManager {
  AudioSourceManager()
      : _streamPool =
            kRadioStreamCandidateUrls.map(Uri.parse).toList(growable: false);

  final List<Uri> _streamPool;
  final Map<String, int> _endpointPenalty = <String, int>{};
  Uri? _activeStreamUri;
  int _endpointCursor = 0;

  Uri? get activeStreamUri => _activeStreamUri;

  /// Selects the healthiest endpoint based on penalties.
  Uri selectEndpoint({required bool forceRotate}) {
    if (_streamPool.length == 1) {
      final single = _streamPool.first;
      _activeStreamUri = single;
      return single;
    }

    final candidates = forceRotate && _activeStreamUri != null
        ? _streamPool.where((uri) => uri != _activeStreamUri).toList()
        : _streamPool;

    final minPenalty = candidates
        .map((uri) => _endpointPenalty[uri.toString()] ?? 0)
        .reduce(min);

    final healthiest = candidates
        .where((uri) => (_endpointPenalty[uri.toString()] ?? 0) == minPenalty)
        .toList(growable: false);

    final chosen = healthiest[_endpointCursor % healthiest.length];
    _endpointCursor++;
    _activeStreamUri = chosen;
    return chosen;
  }

  /// Registers a failure for the current endpoint.
  void registerEndpointFailure([Uri? uri]) {
    final target = uri ?? _activeStreamUri;
    if (target == null) return;
    final key = target.toString();
    _endpointPenalty[key] = (_endpointPenalty[key] ?? 0) + 1;
  }

  /// Registers a success for the current endpoint, reducing penalty.
  void registerEndpointSuccess([Uri? uri]) {
    final target = uri ?? _activeStreamUri;
    if (target == null) return;
    final key = target.toString();
    final current = _endpointPenalty[key] ?? 0;
    if (current <= 1) {
      _endpointPenalty.remove(key);
    } else {
      _endpointPenalty[key] = current - 1;
    }
  }

  /// Configures the [AudioPlayer] with a fresh source, selecting endpoint.
  Future<void> configureSource(AudioPlayer player,
      {bool forceRefresh = false}) async {
    final selectedBaseUri = selectEndpoint(forceRotate: forceRefresh);
    final liveUri = selectedBaseUri.replace(queryParameters: {
      ...selectedBaseUri.queryParameters,
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    });

    final source = AudioRuntimeConfig.backgroundEnabled
        ? AudioSource.uri(
            liveUri,
            tag: const MediaItem(
              id: 'biblefm-live',
              title: 'Bible FM',
              artist: 'En direct • Radio biblique',
              album: 'Bible FM • En direct',
              extras: {
                'isLive': true,
                'station': 'Bible FM',
                'tagline': 'Écoutez où que vous soyez',
              },
            ),
          )
        : AudioSource.uri(liveUri);

    await player.setAudioSource(
      source,
      preload: true,
    );
  }
}

