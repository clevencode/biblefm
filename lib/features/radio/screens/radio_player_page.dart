import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_app/core/strings/bible_fm_strings.dart';
import 'package:meu_app/core/theme/app_theme.dart';
import 'package:meu_app/features/radio/radio_stream_config.dart';
import 'package:meu_app/features/radio/widgets/broadcast_signal_icon.dart';
import 'package:meu_app/features/radio/widgets/web_native_audio.dart';

/// Ancora visual: barra do temporizador alinha logo abaixo desta cápsula.
final GlobalKey _kWebTransportCapsule = GlobalKey(debugLabel: 'webTransportCapsule');

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
                          key: _kWebTransportCapsule,
                          decoration: BoxDecoration(
                            color: AppTheme.transportCapsuleTrack(brightness),
                            borderRadius: BorderRadius.circular(
                              webCapsuleH / 2,
                            ),
                            border: Border.all(
                              color: AppTheme.transportCapsuleOutline(brightness),
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
        final canTap = !reloading && !isLive;
        final discFill =
            isLive || reloading
                ? AppTheme.liveStreamDiscFill(brightness)
                : isListening
                ? AppTheme.liveStreamDiscFill(brightness).withValues(alpha: 0.5)
                : Colors.transparent;
        final ringColor = AppTheme.transportLiveBorder(brightness).withValues(
          alpha: playing || reloading ? 0.65 : 0.45,
        );

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
                width: 1,
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
    if (!mounted) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    final remaining = _remainingSec;
    if (remaining == null) return;
    if (remaining == 0) {
      _cancelSleepTimer();
      bibleFmWebPausePlayback();
      return;
    }
    setState(() {});
  }

  void _startSleepTimer(int minutes) {
    if (minutes <= 0) return;
    _ticker?.cancel();
    _endAt = DateTime.now().add(Duration(minutes: minutes));
    if (!mounted) return;
    setState(() {});
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  String _labelFromRemaining() {
    final remaining = _remainingSec;
    if (remaining == null) return '';
    final hours = remaining ~/ 3600;
    final mins = (remaining % 3600) ~/ 60;
    final secs = remaining % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> _openSleepConfigurator() async {
    final hasTimer = _endAt != null;
    final hoursController = TextEditingController();
    final minutesController = TextEditingController();
    final minutesFocus = FocusNode();

    int totalMinutesFromFields() {
      final h = int.tryParse(hoursController.text.trim()) ?? 0;
      final m = int.tryParse(minutesController.text.trim()) ?? 0;
      return h * 60 + m;
    }

    bool canApply() => totalMinutesFromFields() > 0;

    try {
      const gapBelowTransport = 12.0;
      const minScreenPad = 16.0;
      const sleepBarHeight = 72.0;

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final brightness = Theme.of(dialogContext).brightness;
          final screenSize = MediaQuery.sizeOf(dialogContext);
          final screenW = screenSize.width;
          final targetW = (screenW - 48).clamp(280.0, 560.0).toDouble();

          final capsuleBox =
              _kWebTransportCapsule.currentContext?.findRenderObject()
                  as RenderBox?;
          double top;
          double left;
          if (capsuleBox != null && capsuleBox.hasSize && capsuleBox.attached) {
            final origin = capsuleBox.localToGlobal(Offset.zero);
            top = origin.dy + capsuleBox.size.height + gapBelowTransport;
            left = origin.dx + (capsuleBox.size.width - targetW) / 2;
            left = left.clamp(minScreenPad, screenW - targetW - minScreenPad);
            final maxTop = (screenSize.height -
                    sleepBarHeight -
                    minScreenPad)
                .clamp(minScreenPad, double.infinity)
                .toDouble();
            top = top.clamp(minScreenPad, maxTop);
          } else {
            top = screenSize.height * 0.42;
            left = (screenW - targetW) / 2;
          }

          void applyAndClose() {
            if (hasTimer || !canApply()) return;
            _startSleepTimer(totalMinutesFromFields());
            Navigator.of(dialogContext).pop();
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: top,
                left: left,
                width: targetW,
                height: sleepBarHeight,
                child: Material(
                  type: MaterialType.transparency,
                  child: StatefulBuilder(
                    builder: (context, setLocalState) {
                      final valid = canApply();
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.transportCapsuleTrack(brightness),
                          borderRadius:
                              BorderRadius.circular(sleepBarHeight / 2),
                          border: Border.all(
                            color:
                                AppTheme.transportCapsuleOutline(brightness),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _SleepHmUnderlineFields(
                                  brightness: brightness,
                                  hoursController: hoursController,
                                  minutesController: minutesController,
                                  minutesFocus: minutesFocus,
                                  onChanged: () => setLocalState(() {}),
                                  onHoursSubmitted: () =>
                                      minutesFocus.requestFocus(),
                                  onMinutesSubmitted: applyAndClose,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _SleepActionButton(
                                cancelMode: false,
                                enabled: valid,
                                onTap: () {
                                  if (hasTimer || !canApply()) return;
                                  _startSleepTimer(totalMinutesFromFields());
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      hoursController.dispose();
      minutesController.dispose();
      minutesFocus.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTimer = _endAt != null;
    final brightness = Theme.of(context).brightness;
    final ring = AppTheme.transportLiveBorder(brightness).withValues(
      alpha: hasTimer ? 0.65 : 0.45,
    );

    return Semantics(
      button: true,
      label: kBibleFmWebFrSleepA11y,
      child: Tooltip(
        message: hasTimer ? _labelFromRemaining() : kBibleFmWebFrSleepTooltip,
        waitDuration: const Duration(milliseconds: 280),
        child: InkWell(
          onTap: () => unawaited(_openSleepConfigurator()),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ring, width: 1),
              color: hasTimer
                  ? AppTheme.liveStreamDiscFill(brightness)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 17, color: Colors.black),
                if (hasTimer) ...[
                  const SizedBox(width: 4),
                  Text(
                    _labelFromRemaining(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cancelSleepTimer,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Colors.black,
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

/// Saisie H:M minimaliste — chiffres + « : », trait de base, légendes H / M.
class _SleepHmUnderlineFields extends StatelessWidget {
  const _SleepHmUnderlineFields({
    required this.brightness,
    required this.hoursController,
    required this.minutesController,
    required this.minutesFocus,
    required this.onChanged,
    required this.onHoursSubmitted,
    required this.onMinutesSubmitted,
  });

  final Brightness brightness;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final FocusNode minutesFocus;
  final VoidCallback onChanged;
  final VoidCallback onHoursSubmitted;
  final VoidCallback onMinutesSubmitted;

  static const double _colonTrack = 14;

  @override
  Widget build(BuildContext context) {
    final onChrome = AppTheme.transportChromeOnInner(brightness);
    final digitStyle = TextStyle(
      color: onChrome,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      height: 1.05,
    );
    final labelStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
              color: onChrome.withValues(
                alpha: brightness == Brightness.light ? 0.72 : 0.78,
              ),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            );

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: onChrome.withValues(alpha: 0.32),
            fontWeight: FontWeight.w500,
            fontSize: 22,
          ),
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(bottom: 8, top: 2),
        );

    return Semantics(
      label: kBibleFmWebFrSleepInputHint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: hoursController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: digitStyle,
                  cursorColor: onChrome,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: deco('0'),
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onHoursSubmitted(),
                ),
              ),
              SizedBox(
                width: _colonTrack,
                child: Center(child: Text(':', style: digitStyle)),
              ),
              Expanded(
                child: TextField(
                  controller: minutesController,
                  focusNode: minutesFocus,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  style: digitStyle,
                  cursorColor: onChrome,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: deco('0'),
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onMinutesSubmitted(),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: onChrome.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Center(child: Text('H', style: labelStyle)),
              ),
              const SizedBox(width: _colonTrack),
              Expanded(
                child: Center(child: Text('M', style: labelStyle)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepActionButton extends StatelessWidget {
  const _SleepActionButton({
    required this.cancelMode,
    this.enabled = true,
    required this.onTap,
  });

  final bool cancelMode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final onChrome = AppTheme.transportChromeOnInner(brightness);
    final rim = AppTheme.transportChromeTimelineTrack(brightness);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: brightness == Brightness.light && enabled
              ? AppTheme.transportChromeInnerFill(brightness)
              : null,
          border: Border.all(
            color: rim.withValues(alpha: enabled ? 0.76 : 0.32),
            width: 1,
          ),
        ),
        child: Icon(
          cancelMode ? Icons.close_rounded : Icons.check_circle,
          size: 26,
          color: enabled ? onChrome : onChrome.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

// Fundo visual da página agora é desenhado directamente via [Ink] no `Stack`,
// alinhado com os gradientes e superfícies em [AppTheme].
