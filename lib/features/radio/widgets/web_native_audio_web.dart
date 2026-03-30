// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

html.AudioElement? _webBibleFmAudio;

/// `true` enquanto o `<audio>` está a reproduzir (para opacidade do botão «live» na web).
final bibleFmWebPlaybackActive = ValueNotifier<bool>(false);

DateTime? _webPlayingSince;
Duration _webElapsedPriorSegments = Duration.zero;
/// Início da pausa actual (relógio de parede) — salto TuneIn ao tocar em live.
DateTime? _webPausedSince;
Timer? _webSessionTickTimer;

/// Expõe o tempo de sessão no **próprio** `currentTime` do `<audio controls>` (reutilização; sem segundo contador).
void _syncNativeAudioElapsedDisplay() {
  final a = _webBibleFmAudio;
  if (a == null) return;
  final sessionSec = _webSessionTotalElapsed().inMicroseconds / 1e6;
  if (!sessionSec.isFinite || sessionSec < 0) return;

  if (a.paused) {
    try {
      if ((a.currentTime - sessionSec).abs() > 0.04) {
        a.currentTime = sessionSec;
      }
    } catch (_) {}
    return;
  }

  final drift = (sessionSec - a.currentTime).abs();
  if (drift <= 1.15) return;
  try {
    a.currentTime = sessionSec;
  } catch (_) {}
}

void _syncWebPlaybackNotifierFrom(html.AudioElement a) {
  bibleFmWebPlaybackActive.value = !a.paused;
}

void _webFoldPlayingSegment() {
  final start = _webPlayingSince;
  if (start != null) {
    _webElapsedPriorSegments += DateTime.now().difference(start);
    _webPlayingSince = null;
  }
}

Duration _webSessionTotalElapsed() {
  var t = _webElapsedPriorSegments;
  final start = _webPlayingSince;
  if (start != null) {
    t += DateTime.now().difference(start);
  }
  return t;
}

void _webStartSessionTick() {
  _webSessionTickTimer?.cancel();
  _webSessionTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    _syncNativeAudioElapsedDisplay();
  });
}

void _webStopSessionTick() {
  _webSessionTickTimer?.cancel();
  _webSessionTickTimer = null;
  _syncNativeAudioElapsedDisplay();
}

void _onWebAudioPlay(html.AudioElement a) {
  _webPlayingSince ??= DateTime.now();
  _webPausedSince = null;
  _syncWebPlaybackNotifierFrom(a);
  _webStartSessionTick();
  _syncNativeAudioElapsedDisplay();
}

void _onWebAudioPauseOrEnd(html.AudioElement a) {
  _webFoldPlayingSegment();
  _webPausedSince = DateTime.now();
  _webStopSessionTick();
  _syncWebPlaybackNotifierFrom(a);
}

/// Soma de uma vez o tempo em pausa ao contador (estilo TuneIn), sem contar em tempo real durante a pausa.
void _webApplyLiveElapsedJumpFromPausedWallClock() {
  final mark = _webPausedSince;
  if (mark == null) return;
  _webElapsedPriorSegments += DateTime.now().difference(mark);
  _webPausedSince = null;
  _syncNativeAudioElapsedDisplay();
}

/// Religa o fluxo ao instante actual e **inicia reprodução** (toque no live = gesto).
Future<void> bibleFmWebReloadLiveStream(String baseUrl) async {
  final el = _webBibleFmAudio;
  if (el == null) return;
  _webApplyLiveElapsedJumpFromPausedWallClock();
  var uri = Uri.parse(baseUrl);
  final q = Map<String, String>.from(uri.queryParameters);
  q['_'] = DateTime.now().millisecondsSinceEpoch.toString();
  uri = uri.replace(queryParameters: q);
  el.src = uri.toString();
  el.load();
  try {
    await el.play();
    _syncNativeAudioElapsedDisplay();
  } catch (_) {
    _syncWebPlaybackNotifierFrom(el);
  }
}

/// Controlo nativo do browser (`<audio controls>` — p.ex. barra do Chrome).
class WebNativeAudioControls extends StatefulWidget {
  const WebNativeAudioControls({
    super.key,
    required this.streamUrl,
    this.controlsHeight = 44,
  });

  final String streamUrl;
  final double controlsHeight;

  @override
  State<WebNativeAudioControls> createState() => _WebNativeAudioControlsState();
}

class _WebNativeAudioControlsState extends State<WebNativeAudioControls> {
  static const String _viewType = 'bible-fm-chrome-audio';
  static bool _factoryRegistered = false;

  @override
  void initState() {
    super.initState();
    _registerFactoryOnce();
  }

  void _registerFactoryOnce() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;
    final url = widget.streamUrl;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final a = html.AudioElement()
        ..controls = true
        ..preload = 'none'
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.maxHeight = '100%'
        ..style.display = 'block';
      final wrap = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.boxSizing = 'border-box'
        ..append(a);
      _webBibleFmAudio = a;
      a.onPlay.listen((_) => _onWebAudioPlay(a));
      a.onPause.listen((_) => _onWebAudioPauseOrEnd(a));
      a.onEnded.listen((_) => _onWebAudioPauseOrEnd(a));
      a.onLoadedData.listen((_) => _syncNativeAudioElapsedDisplay());
      a.onLoadedMetadata.listen((_) => _syncNativeAudioElapsedDisplay());
      _syncWebPlaybackNotifierFrom(a);
      _syncNativeAudioElapsedDisplay();
      return wrap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : 520.0;
        final h = widget.controlsHeight;
        return SizedBox(
          width: w,
          height: h,
          child: const HtmlElementView(viewType: _viewType),
        );
      },
    );
  }
}
