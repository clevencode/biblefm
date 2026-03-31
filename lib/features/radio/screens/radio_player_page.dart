import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';
import 'package:meu_app/features/radio/widgets/web_native_audio.dart';

/// Bible FM — leitor **apenas Web** (`<audio controls>` + botão directo).
class RadioPlayerPage extends StatelessWidget {
  const RadioPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const webCapsuleH = 52.0;
    const webPadH = 8.0;
    const webPadV = 5.0;
    const webLiveDiameter = 42.0;
    const webAudioH = 40.0;
    final innerH = webCapsuleH - 2 * webPadV;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: kBibleFmSemanticsPlayerPage,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: kBibleFmWebFrBackgroundGestureA11y,
              onTap: bibleFmWebBackgroundTapPlayPause,
              onLongPress: bibleFmWebBackgroundLongPressGoLive,
              child: Material(
                type: MaterialType.transparency,
                child: Ink(
                  decoration: BoxDecoration(
                    color: brightness == Brightness.dark
                        ? scheme.surface
                        : null,
                    gradient: brightness == Brightness.dark
                        ? null
                        : AppTheme.notionLightBackgroundGradient,
                  ),
                  child: InkWell(
                    onTap: bibleFmWebBackgroundTapPlayPause,
                    onLongPress: bibleFmWebBackgroundLongPressGoLive,
                    splashFactory:
                        InkSparkle.constantTurbulenceSeedSplashFactory,
                    // Efeito granulado sem véu de cor opaco: só faíscas sobre o fundo.
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    // Sem véu de cor ao pairar: o fundo visual permanece idêntico.
                    hoverColor: Colors.transparent,
                    mouseCursor: SystemMouseCursors.click,
                    canRequestFocus: false,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _WebRealtimeFeedbackLine(),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.transportCapsuleTrack(brightness),
                            borderRadius: BorderRadius.circular(
                              webCapsuleH / 2,
                            ),
                            border: Border.all(
                              color: AppTheme.transportLiveBorder(brightness)
                                  .withValues(
                                    alpha: brightness == Brightness.dark
                                        ? 0.35
                                        : 0.5,
                                  ),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              webPadH,
                              webPadV,
                              webPadH,
                              webPadV,
                            ),
                            child: SizedBox(
                              height: innerH,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const _WebLiveStreamButton(
                                    diameter: webLiveDiameter,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: WebNativeAudioControls(
                                      streamUrl: kBibleFmLiveStreamUrl,
                                      controlsHeight: webAudioH,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const _WebSleepTimerButton(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _webPlaybackFeedbackMessage({
  required bool reloading,
  required bool playing,
  required bool buffering,
  required bool liveEdge,
  required bool sessionStarted,
}) {
  if (reloading) return kBibleFmWebFrFeedbackReloading;
  if (playing && buffering) return kBibleFmWebFrFeedbackBuffering;
  if (playing && liveEdge) return kBibleFmWebFrFeedbackLive;
  if (playing) return kBibleFmWebFrFeedbackListening;
  if (sessionStarted) return kBibleFmWebFrFeedbackPaused;
  return kBibleFmWebFrFeedbackReady;
}

Color _webPlaybackFeedbackColor(
  BuildContext context, {
  required bool playing,
  required bool liveEdge,
  required bool reloading,
  required bool buffering,
  required bool sessionStarted,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (playing && liveEdge) {
    return scheme.primary;
  }
  if (reloading || (playing && buffering)) {
    return scheme.onSurfaceVariant;
  }
  if (playing) return scheme.onSurface;
  if (sessionStarted) {
    return scheme.onSurface.withValues(alpha: 0.88);
  }
  return scheme.onSurfaceVariant;
}

class _WebRealtimeFeedbackLine extends StatelessWidget {
  const _WebRealtimeFeedbackLine();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        bibleFmWebPlaybackActive,
        bibleFmWebLiveReloading,
        bibleFmWebLiveEdgeActive,
        bibleFmWebBuffering,
        bibleFmWebSessionEverStarted,
      ]),
      builder: (context, _) {
        final playing = bibleFmWebPlaybackActive.value;
        final reloading = bibleFmWebLiveReloading.value;
        final liveEdge = bibleFmWebLiveEdgeActive.value;
        final buffering = bibleFmWebBuffering.value;
        final sessionStarted = bibleFmWebSessionEverStarted.value;
        final msg = _webPlaybackFeedbackMessage(
          reloading: reloading,
          playing: playing,
          buffering: buffering,
          liveEdge: liveEdge,
          sessionStarted: sessionStarted,
        );
        final color = _webPlaybackFeedbackColor(
          context,
          playing: playing,
          liveEdge: liveEdge,
          reloading: reloading,
          buffering: buffering,
          sessionStarted: sessionStarted,
        );
        final showOnAirDot = playing && liveEdge && !reloading;
        final onAirColor = Theme.of(context).colorScheme.error;

        return Semantics(
          liveRegion: true,
          label: msg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showOnAirDot) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onAirColor,
                    boxShadow: [
                      BoxShadow(
                        color: onAirColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) {
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [...previous, ?current],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final pull =
                        Tween<Offset>(
                          begin: const Offset(0, 0.22),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                    return SlideTransition(
                      position: pull,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Text(
                    msg,
                    key: ValueKey<String>(msg),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: color),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WebLiveStreamButton extends StatelessWidget {
  const _WebLiveStreamButton({this.diameter = 44});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconSize = (diameter * 0.44).clamp(16.0, 24.0);
    final broadcastIconColor = AppTheme.liveStreamBroadcastIconColor(
      brightness,
    );
    final spinnerColor = broadcastIconColor;
    return ListenableBuilder(
      listenable: Listenable.merge([
        bibleFmWebPlaybackActive,
        bibleFmWebLiveReloading,
        bibleFmWebLiveEdgeActive,
      ]),
      builder: (context, _) {
        final playing = bibleFmWebPlaybackActive.value;
        final reloading = bibleFmWebLiveReloading.value;
        final atLiveEdge = bibleFmWebLiveEdgeActive.value;
        final isLive = playing && atLiveEdge;
        final isListening = playing && !atLiveEdge;
        final isPaused = !playing && !reloading;
        final canTap = !reloading && !isLive;
        final discFill =
            isLive || reloading
                ? AppTheme.liveStreamDiscFill(brightness)
                : isListening
                ? AppTheme.liveStreamDiscFill(brightness).withValues(alpha: 0.5)
                : Colors.transparent;
        final ringColor =
            isPaused
                ? AppTheme.liveStreamDiscRing(
                  brightness,
                ).withValues(alpha: brightness == Brightness.dark ? 0.95 : 1.0)
                : AppTheme.liveStreamDiscRing(brightness);
        final ringWidth = isPaused ? 1.8 : 1.0;

        String semanticsLabel;
        String tooltipMsg;
        if (reloading) {
          semanticsLabel = kBibleFmWebFrLiveA11yReloading;
          tooltipMsg = kBibleFmWebFrLiveTooltipReloading;
        } else if (playing && atLiveEdge) {
          semanticsLabel = kBibleFmWebFrLiveA11yActive;
          tooltipMsg = kBibleFmWebFrLiveTooltipActive;
        } else if (canTap) {
          semanticsLabel = kBibleFmWebFrLiveA11yGoLive;
          tooltipMsg = kBibleFmWebFrLiveTooltipGoLive;
        } else {
          semanticsLabel = kBibleFmWebFrLiveA11yPauseToEnable;
          tooltipMsg = kBibleFmWebFrLiveTooltipPauseToEnable;
        }

        final disc = InkWell(
          onTap: canTap
              ? () =>
                    unawaited(bibleFmWebReloadLiveStream(kBibleFmLiveStreamUrl))
              : null,
          customBorder: const CircleBorder(),
          hoverColor: canTap
              ? AppTheme.liveStreamButtonHover(brightness)
              : Colors.transparent,
          splashColor: canTap
              ? AppTheme.liveStreamButtonSplash(brightness)
              : Colors.transparent,
          highlightColor: canTap ? null : Colors.transparent,
          child: Ink(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: discFill,
              border: Border.all(
                color: ringColor,
                width: ringWidth,
              ),
            ),
            child: Center(
              child: reloading
                  ? SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                        color: spinnerColor,
                        backgroundColor: spinnerColor.withValues(alpha: 0.2),
                      ),
                    )
                  : BroadcastSignalIcon(
                      color: broadcastIconColor,
                      size: iconSize,
                    ),
            ),
          ),
        );

        return Semantics(
          button: true,
          selected: isLive,
          enabled: canTap,
          label: semanticsLabel,
          child: Tooltip(
            message: tooltipMsg,
            waitDuration: const Duration(milliseconds: 320),
            child: MouseRegion(
              cursor: canTap
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Material(color: Colors.transparent, child: disc),
            ),
          ),
        );
      },
    );
  }
}

class _WebSleepTimerButton extends StatefulWidget {
  const _WebSleepTimerButton();

  @override
  State<_WebSleepTimerButton> createState() => _WebSleepTimerButtonState();
}

class _WebSleepTimerButtonState extends State<_WebSleepTimerButton> {
  Timer? _ticker;
  DateTime? _endAt;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int? get _remainingSec {
    final end = _endAt;
    if (end == null) return null;
    final diff = end.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _cancelSleepTimer() {
    _ticker?.cancel();
    _ticker = null;
    if (mounted) {
      setState(() {
        _endAt = null;
      });
    } else {
      _endAt = null;
    }
  }

  void _onTick() {
    final remaining = _remainingSec;
    if (remaining == null) return;
    if (remaining == 0) {
      _cancelSleepTimer();
      bibleFmWebPausePlayback();
      return;
    }
    if (mounted) setState(() {});
  }

  void _startSleepTimer(int minutes) {
    _ticker?.cancel();
    _endAt = DateTime.now().add(Duration(minutes: minutes));
    setState(() {});
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  String _labelFromRemaining() {
    final remaining = _remainingSec;
    if (remaining == null) return '';
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<int?> _pickCustomMinutes() async {
    final controller = TextEditingController(text: '90');
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Minuteur personnalisé'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutes',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                final raw = int.tryParse(controller.text.trim());
                if (raw == null || raw <= 0) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pop(raw);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSelected(int value) async {
    if (value == 0) {
      _cancelSleepTimer();
      return;
    }
    if (value == -1) {
      final custom = await _pickCustomMinutes();
      if (custom == null || custom <= 0) return;
      _startSleepTimer(custom);
      return;
    }
    _startSleepTimer(value);
  }

  @override
  Widget build(BuildContext context) {
    final hasTimer = _endAt != null;
    final brightness = Theme.of(context).brightness;
    final fg = Theme.of(context).colorScheme.onSurfaceVariant;
    final ring = AppTheme.transportLiveBorder(brightness).withValues(
      alpha: hasTimer ? 0.65 : 0.45,
    );

    return Semantics(
      button: true,
      label: kBibleFmWebFrSleepA11y,
      child: Tooltip(
        message: hasTimer ? _labelFromRemaining() : kBibleFmWebFrSleepTooltip,
        waitDuration: const Duration(milliseconds: 280),
        child: PopupMenuButton<int>(
          tooltip: kBibleFmWebFrSleepTooltip,
          onSelected: (value) {
            // Ignoramos o Future; o menu fecha de qualquer forma.
            _handleSelected(value);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 15, child: Text('15 min')),
            PopupMenuItem(value: 30, child: Text('30 min')),
            PopupMenuItem(value: 45, child: Text('45 min')),
            PopupMenuItem(value: 60, child: Text('60 min')),
            PopupMenuItem(value: -1, child: Text('Personnalisé…')),
            PopupMenuDivider(),
            PopupMenuItem(value: 0, child: Text(kBibleFmWebFrSleepOff)),
          ],
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ring, width: 1),
              color: hasTimer ? fg.withValues(alpha: 0.1) : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bedtime_outlined, size: 17, color: fg),
                if (hasTimer) ...[
                  const SizedBox(width: 4),
                  Text(
                    _labelFromRemaining(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Fundo visual da página agora é desenhado directamente via [Ink] no `Stack`,
// alinhado com os gradientes e superfícies em [AppTheme].
