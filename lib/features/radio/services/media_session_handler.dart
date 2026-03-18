import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Small helper responsible for updating MediaItem / notification metadata.
class MediaSessionHandler {
  const MediaSessionHandler(this.player);

  final AudioPlayer player;

  /// Updates the current [MediaItem] with a fresh "live" flag if supported.
  Future<void> updateLiveMetadata({required bool isLive}) async {
    final sequence = player.sequence;
    if (sequence == null || sequence.isEmpty) return;
    final current = sequence.first.tag;
    if (current is! MediaItem) return;

    final extras = Map<String, Object?>.from(current.extras ?? const {});
    extras['isLive'] = isLive;

    final updated = current.copyWith(extras: extras);
    await player.setAudioSource(
      AudioSource.uri(
        Uri.parse(updated.id),
        tag: updated,
      ),
      preload: true,
    );
  }
}

