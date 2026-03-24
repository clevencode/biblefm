import 'dart:async';

import 'package:flutter/foundation.dart';

/// Agenda uma operação async do player sem bloquear o build.
///
/// O [RadioPlayerController] trata a maior parte dos erros internamente; este
/// invólucro evita que exceções inesperadas rebentem a árvore de widgets e
/// regista o problema via [FlutterError] (útil em debug e em integrações de
/// reporting).
void scheduleRadioPlayerAction(
  Future<void> Function() action, {
  String debugLabel = 'radio',
}) {
  unawaited(_runGuarded(action, debugLabel));
}

Future<void> _runGuarded(
  Future<void> Function() action,
  String debugLabel,
) async {
  try {
    await action();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'biblefm/radio',
        context: ErrorDescription('scheduleRadioPlayerAction($debugLabel)'),
      ),
    );
  }
}
