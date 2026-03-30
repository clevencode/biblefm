import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:meu_app/app/app.dart';
import 'package:meu_app/app/opening_splash_gate.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/screens/radio_player_page.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart'
    show
        kAndroidMediaSeekSkipInterval,
        kAndroidRadioNotificationChannelDescription,
        kAndroidRadioNotificationChannelId,
        kAndroidRadioNotificationChannelName,
        kAndroidMediaNotificationIcon;

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Mantém a splash nativa (mesmo fundo/logo) até o Flutter poder pintar o ecrã
  // equivalente — evita flash branco e duplo salto visual. Web: sem splash nativa / ecrã extra.
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Web: só [just_audio] no cliente — sem AudioService / sessão / arranque bloqueante.
  if (!kIsWeb) {
    await _bootstrapAudio();
  }

  final home = kIsWeb
      ? const RadioPlayerPage()
      : OpeningSplashGate(
          initFuture: Future<void>.delayed(const Duration(milliseconds: 280)),
        );

  runApp(
    ProviderScope(
      child: RadioApp(home: home),
    ),
  );
}

/// Sessão de áudio + notificação em segundo plano. Erros são registados; `runApp` corre na mesma.
///
/// **Ordem de arranque (como na 5.0):** este método é aguardado em `main()` antes de `runApp`,
/// para o `AudioService` estar pronto antes de qualquer widget — evita notificação vazia ou
/// 1.º `play` contra um handler ainda a inicializar.
///
/// **Interrupções:** [AudioSessionConfiguration.music]; o leitor escuta
/// [AudioSession.interruptionEventStream].
///
/// **Android:** `foregroundServiceType="mediaPlayback"`, permissão de notificações (API 33+)
/// pedida antes do play no leitor, e `androidStopForegroundOnPause: true` como no
/// just_audio_background 0.0.1-beta.17 (paridade com a 5.0).
Future<void> _bootstrapAudio() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'main',
        context: ErrorDescription('Falha ao configurar AudioSession'),
      ),
    );
  }

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: kAndroidRadioNotificationChannelId,
      androidNotificationChannelName: kAndroidRadioNotificationChannelName,
      androidNotificationChannelDescription:
          kAndroidRadioNotificationChannelDescription,
      notificationColor: AppTheme.mediaNotificationBackground,
      androidNotificationIcon: kAndroidMediaNotificationIcon,
      // Leitura activa: o SO trata como sessão contínua (menos swipe acidental).
      androidNotificationOngoing: true,
      androidResumeOnClick: true,
      androidNotificationClickStartsActivity: true,
      // Igual à 5.0 (pub.dev): comportamento conhecido no telemóvel real.
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: false,
      preloadArtwork: false,
      // O stream é em directo (sem seek na UI); intervalos mínimos para a API audio_service.
      fastForwardInterval: kAndroidMediaSeekSkipInterval,
      rewindInterval: kAndroidMediaSeekSkipInterval,
    );
  } catch (e, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'main',
        context: ErrorDescription('Falha ao inicializar JustAudioBackground'),
      ),
    );
  }
}
