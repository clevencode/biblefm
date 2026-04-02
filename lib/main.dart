import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:bibliofani/app/app.dart';
import 'package:bibliofani/radio_home_impl.dart'
    if (dart.library.html) 'package:bibliofani/radio_home_html.dart'
    if (dart.library.io) 'package:bibliofani/radio_home_io.dart' as radio_home;

/// Em web release evita que o motor escreva erros na consola do browser
/// (Lighthouse / experiência do utilizador). Em debug mantém-se o comportamento normal.
void _configureSilentFlutterConsoleOnWebRelease() {
  if (!kIsWeb || !kReleaseMode) return;
  FlutterError.onError = (_) {};
  PlatformDispatcher.instance.onError = (_, _) => true;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _configureSilentFlutterConsoleOnWebRelease();
  runApp(RadioApp(home: radio_home.createRadioHome()));
}
