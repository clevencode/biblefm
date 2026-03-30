import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

/// Cria o [AudioPlayer] do leitor com opções adequadas a cada plataforma.
///
/// **Web (HTML5):** desliga [handleInterruptions] — o modelo de interrupções
/// móvel/audio_session não se aplica; evita trabalho desnecessário. Mantém
/// [handleAudioSessionActivation] como recomendado pelo `just_audio` para o
/// ciclo de activação junto do elemento `<audio>`.
///
/// **Nativo:** valores por omissão do construtor (interrupções + atributos Android).
AudioPlayer createRadioAudioPlayer() {
  if (kIsWeb) {
    return AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: true,
    );
  }
  return AudioPlayer();
}
