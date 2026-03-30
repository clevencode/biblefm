import 'package:meu_app/core/strings/bible_fm_strings.dart';

/// Estados apenas para a UI (sem backend de áudio).
///
/// **Carregamento do transporte:** [preparing] (loading no player) e [buffering]
/// (a encher buffer antes de reprodução estável). Fora destes, não há load activo.
enum UiPlaybackLifecycle {
  idle,
  preparing,
  buffering,
  playing,
  paused,
}

/// `true` enquanto o transporte está a **carregar** ou a **bufferizar** o fluxo.
bool isTransportLoadingUiLifecycle(UiPlaybackLifecycle lifecycle) {
  return lifecycle == UiPlaybackLifecycle.preparing ||
      lifecycle == UiPlaybackLifecycle.buffering;
}

/// Expõe a mesma regra que [RadioPlayerUiState.canTapLive] para `select` granular.
bool radioUiCanTapLive(UiPlaybackLifecycle lifecycle, bool isLiveMode) {
  if (isTransportLoadingUiLifecycle(lifecycle)) return false;
  if (lifecycle == UiPlaybackLifecycle.idle) return true;
  if (lifecycle == UiPlaybackLifecycle.paused) return true;
  return !isLiveMode;
}

/// Expõe a mesma regra que [RadioPlayerUiState.isEnDirect] para `select` granular.
bool radioUiIsEnDirect(UiPlaybackLifecycle lifecycle, bool isLiveMode) {
  final playing = lifecycle == UiPlaybackLifecycle.playing;
  return playing && !isTransportLoadingUiLifecycle(lifecycle) && isLiveMode;
}

/// Linha de estado na notificação de média / lock screen (alinhada à UI do leitor).
String bibleFmMediaNotificationStatusLine({
  required UiPlaybackLifecycle lifecycle,
  required bool isLiveMode,
}) {
  final playing = lifecycle == UiPlaybackLifecycle.playing;
  final loading = isTransportLoadingUiLifecycle(lifecycle);
  if (playing && !loading && isLiveMode) {
    return kBibleFmMediaNotificationLineDirect;
  }
  if (playing || loading) {
    return kBibleFmMediaNotificationLineEcoute;
  }
  return kBibleFmMediaNotificationLinePause;
}

