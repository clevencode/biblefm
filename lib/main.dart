import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration.music());
  } catch (e, st) {
    debugPrint('Falha ao configurar audio session: $e');
    debugPrint(st.toString());
  }

  runApp(
    const ProviderScope(
      child: RadioApp(),
    ),
  );
}
