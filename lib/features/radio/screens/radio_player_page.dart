import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_app/core/theme/app_spacing.dart';
import 'package:meu_app/core/theme/app_theme_mode_toggle.dart';
import 'package:meu_app/features/radio/services/radio_bridge_providers.dart';
import 'package:meu_app/features/radio/services/radio_player_controller.dart';
import 'package:meu_app/features/radio/utils/radio_ui_invocation.dart';
import 'package:meu_app/features/radio/widgets/live_pulsing_indicator.dart';
import 'package:meu_app/features/radio/widgets/radio_transport_controls.dart';

/// Bible FM: layout **mobile-first** — base para telemóvel, depois tablet/paisagem.
/// Título no topo, cartão centralizado, barra com play e live (pílula).
class RadioPlayerPage extends ConsumerWidget {
  const RadioPlayerPage({super.key});

  static const Color _timerGreenLight = Color(0xFF1A3D2E);
  static const Color _chipGreyLight = Color(0xFFE8E8E8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg =
        isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final chipGrey = isDark ? const Color(0xFF2C2C2C) : _chipGreyLight;
    // Bandeja do contador: cinza mais claro que a pílula (contraste intencional).
    final timerTrayColor =
        isDark ? const Color(0xFF252525) : const Color(0xFFEEEEEE);
    final titleColor = isDark ? scheme.onSurface : Colors.black;
    final timerColor = isDark ? scheme.primary : _timerGreenLight;

    final lifecycle = ref.watch(radioLifecycleProvider);
    final elapsed = ref.watch(radioElapsedProvider);
    final errorMessage = ref.watch(radioErrorProvider);
    final isLiveMode = ref.watch(radioIsLiveProvider);
    final isPlaying = ref.watch(radioIsPlayingProvider);
    final notifier = ref.read(radioPlayerControllerProvider.notifier);

    final showStreamLoading = _isBufferingLifecycle(lifecycle);

    return Semantics(
      container: true,
      label: 'Bible FM, lecteur radio',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _PageBackground(color: pageBg, isDark: isDark),
            SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                // Mobile-first: base mobile, depois overrides para tablet/landscape.
                final isCompact = AppLayoutBreakpoints.isCompactHeight(h);
                final isNarrow = AppLayoutBreakpoints.isNarrow(w);

                final scale = AppSpacing.mobileLayoutScale(
                  constraints.biggest.shortestSide,
                );
                final sidePadding = AppSpacing.g(
                  AppSpacing.marginContentHorizontalSteps(narrow: isNarrow),
                  scale,
                );
                final transportSidePadding = AppSpacing.g(
                  AppSpacing.marginTransportHorizontalSteps(narrow: isNarrow),
                  scale,
                );
                final panelPaddingH = AppSpacing.g(
                  AppSpacing.marginPanelInnerHorizontalSteps(narrow: isNarrow),
                  scale,
                );
                final panelWidth = AppLayoutBreakpoints.maxPanelWidth(w, h, scale);

                final playButtonSize = AppSpacing.g(
                  AppSpacing.playControlDiameterSteps(
                    narrow: isNarrow,
                    compactHeight: isCompact,
                  ),
                  scale,
                );
                final bottomInset = MediaQuery.paddingOf(context).bottom;
                final playVisualSize = playButtonSize.clamp(
                  AppSpacing.g(AppSpacing.playControlDiameterMinSteps, scale),
                  AppSpacing.g(AppSpacing.playControlDiameterMaxSteps, scale),
                );
                final postButtonGap = AppSpacing.g(
                  AppSpacing.transportStackGapSteps(
                    compactHeight: isCompact,
                  ),
                  scale,
                );
                final overlayContentHeight =
                    playVisualSize + postButtonGap;
                final barReserve = overlayContentHeight +
                    bottomInset +
                    AppSpacing.g(
                      AppSpacing.transportBottomMarginSteps,
                      scale,
                    );

                return Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    if (showStreamLoading)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            color: scheme.primary,
                            backgroundColor:
                                scheme.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              sidePadding,
                              AppSpacing.g(
                                AppSpacing.sectionVerticalPaddingSteps,
                                scale,
                              ),
                              sidePadding,
                              AppSpacing.g(
                                AppSpacing.sectionVerticalPaddingSteps,
                                scale,
                              ),
                            ),
                            child: _BibleFmHeader(
                              scale: scale,
                              titleColor: titleColor,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: barReserve),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: sidePadding,
                                  vertical: AppSpacing.g(
                                    AppSpacing.sectionVerticalPaddingSteps,
                                    scale,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _MainPlayerCard(
                                        width: w.clamp(
                                          AppSpacing.panelWidthCompact,
                                          panelWidth,
                                        ),
                                        panelPaddingH: panelPaddingH,
                                        cardColor: cardColor,
                                        isDark: isDark,
                                        scale: scale,
                                        isCompactHeight: isCompact,
                                        narrowMobile: isNarrow,
                                        isPlaying: isPlaying,
                                        isBuffering:
                                            _isBufferingLifecycle(lifecycle),
                                        isLiveMode: isLiveMode,
                                        chipGrey: chipGrey,
                                        timerTrayColor: timerTrayColor,
                                        titleColor: titleColor,
                                        timerColor: timerColor,
                                        elapsed: elapsed,
                                      ),
                                      if (errorMessage != null) ...[
                                        SizedBox(
                                            height: AppSpacing.g(3, scale)),
                                        _ErrorBanner(
                                          message: errorMessage,
                                          scale: scale,
                                          onRetry: () =>
                                              scheduleRadioPlayerAction(
                                            () =>
                                                notifier.togglePlayPause(),
                                            debugLabel: 'retryAfterError',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: transportSidePadding,
                      right: transportSidePadding,
                      bottom: bottomInset +
                          AppSpacing.g(
                            AppSpacing.transportBottomMarginSteps,
                            scale,
                          ),
                      child: Material(
                        color: Colors.transparent,
                        // Por último no Stack: toques na barra têm prioridade.
                        child: RadioTransportControls(
                          scale: scale,
                          playVisualSize: playVisualSize,
                          isDark: isDark,
                          narrowMobile: isNarrow,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _PageBackground extends StatelessWidget {
  const _PageBackground({required this.color, required this.isDark});

  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Mobile-first (referência): fundo claro sólido; gradiente só em dark.
    if (!isDark) {
      return DecoratedBox(decoration: BoxDecoration(color: color));
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            const Color(0xFF0A0A0A),
          ],
        ),
      ),
    );
  }
}

bool _isBufferingLifecycle(RadioPlaybackLifecycle lifecycle) {
  return lifecycle == RadioPlaybackLifecycle.preparing ||
      lifecycle == RadioPlaybackLifecycle.buffering ||
      lifecycle == RadioPlaybackLifecycle.reconnecting;
}

class _BibleFmHeader extends StatelessWidget {
  const _BibleFmHeader({
    required this.scale,
    required this.titleColor,
  });

  final double scale;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final titleFont = AppSpacing.responsiveBrandTitleFontSize(w, scale);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.gHalf(scale)),
      child: Row(
        children: [
          Text(
            'BIBLE FM',
            style: GoogleFonts.russoOne(
              color: titleColor,
              fontSize: titleFont,
              letterSpacing: AppSpacing.gHalf(scale) * 0.3,
            ),
          ),
          const Spacer(),
          AppThemeModeToggle(layoutScale: scale),
        ],
      ),
    );
  }
}

class _DigitalTimer extends StatelessWidget {
  const _DigitalTimer({
    required this.elapsed,
    required this.scale,
    required this.timerTrayColor,
    required this.timerColor,
    required this.captionColor,
    required this.isPlaying,
    required this.isBuffering,
  });

  final Duration elapsed;
  final double scale;
  final Color timerTrayColor;
  final Color timerColor;
  final Color captionColor;
  final bool isPlaying;
  final bool isBuffering;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mainFontSize =
        AppSpacing.responsiveTimerValueFontSize(width, scale);
    final unitFontSize = AppTypeScale.label * 0.92 * scale;
    final valueStyle = GoogleFonts.shareTechMono(
      fontSize: mainFontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: AppSpacing.gHalf(scale) * 0.0875,
      color: timerColor,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final colonStyle = valueStyle.copyWith(
      letterSpacing: 0,
      fontSize: mainFontSize * 0.92,
    );
    final unitStyle = GoogleFonts.dmSans(
      fontSize: unitFontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: AppSpacing.gHalf(scale) * 0.05,
      color: captionColor,
      height: 1.0,
    );
    final captionStyle = GoogleFonts.dmSans(
      fontSize: AppTypeScale.label * scale,
      fontWeight: FontWeight.w600,
      letterSpacing: AppSpacing.gHalf(scale) * 0.0875,
      color: captionColor,
      height: 1.25,
    );

    final d = elapsed.isNegative ? Duration.zero : elapsed;
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final a11y = _sessionDurationSemanticsFr(d);

    final String? footerLine;
    if (isBuffering) {
      footerLine = 'Compteur en pause pendant la connexion';
    } else if (!isPlaying) {
      footerLine = 'En pause — reprends la lecture pour faire avancer le temps';
    } else {
      footerLine = null;
    }

    final scheme = Theme.of(context).colorScheme;
    final timerVerticalSteps =
        AppLayoutBreakpoints.isNarrow(MediaQuery.sizeOf(context).width)
            ? 2
            : 3;

    return Semantics(
      label: 'Temps d\'écoute, $a11y',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: timerTrayColor,
          borderRadius: AppRadii.borderRadius(AppRadii.sm, scale),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: Padding(
          padding: AppSpacing.insetSymmetric(
            layoutScale: scale,
            horizontal: 2,
            vertical: timerVerticalSteps,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _TimerDigitColumn(
                    value: hh,
                    unit: 'h',
                    layoutScale: scale,
                    valueStyle: valueStyle,
                    unitStyle: unitStyle,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.gHalf(scale),
                    ),
                    child: Text('.', style: colonStyle),
                  ),
                  _TimerDigitColumn(
                    value: mm,
                    unit: 'min',
                    layoutScale: scale,
                    valueStyle: valueStyle,
                    unitStyle: unitStyle,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.gHalf(scale),
                    ),
                    child: Text('.', style: colonStyle),
                  ),
                  _TimerDigitColumn(
                    value: ss,
                    unit: 's',
                    layoutScale: scale,
                    valueStyle: valueStyle,
                    unitStyle: unitStyle,
                  ),
                ],
              ),
              if (footerLine != null) ...[
                SizedBox(height: AppSpacing.gHalf(scale)),
                Text(
                  footerLine,
                  textAlign: TextAlign.center,
                  style: captionStyle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerDigitColumn extends StatelessWidget {
  const _TimerDigitColumn({
    required this.value,
    required this.unit,
    required this.layoutScale,
    required this.valueStyle,
    required this.unitStyle,
  });

  final String value;
  final String unit;
  final double layoutScale;
  final TextStyle valueStyle;
  final TextStyle unitStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: valueStyle),
        SizedBox(height: AppSpacing.gHalf(layoutScale)),
        Text(unit, style: unitStyle),
      ],
    );
  }
}

String _sessionDurationSemanticsFr(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final parts = <String>[];
  if (h > 0) {
    parts.add(h == 1 ? '1 heure' : '$h heures');
  }
  if (m > 0) {
    parts.add(m == 1 ? '1 minute' : '$m minutes');
  }
  if (s > 0 || parts.isEmpty) {
    parts.add(s == 1 ? '1 seconde' : '$s secondes');
  }
  return parts.join(', ');
}

class _MainPlayerCard extends StatelessWidget {
  const _MainPlayerCard({
    required this.width,
    required this.panelPaddingH,
    required this.cardColor,
    required this.isDark,
    required this.scale,
    required this.isCompactHeight,
    required this.narrowMobile,
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.chipGrey,
    required this.timerTrayColor,
    required this.titleColor,
    required this.timerColor,
    required this.elapsed,
  });

  final double width;
  final double panelPaddingH;
  final Color cardColor;
  final bool isDark;
  final double scale;
  final bool isCompactHeight;
  final bool narrowMobile;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLiveMode;
  final Color chipGrey;
  final Color timerTrayColor;
  final Color titleColor;
  final Color timerColor;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final isLive = isPlaying && !isBuffering && isLiveMode;
    final statusToTimerGap = AppSpacing.g(
      AppSpacing.marginPanelInnerHorizontalSteps(narrow: narrowMobile),
      scale,
    );
    const cornerPt = AppLayoutBreakpoints.playerCardCornerPt;
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: panelPaddingH,
        vertical: AppSpacing.g(isCompactHeight ? 3 : 4, scale),
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppRadii.borderRadius(cornerPt, scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.35 : 0.08,
            ),
            blurRadius: AppSpacing.g(3, scale),
            offset: Offset(0, AppSpacing.g(1, scale)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLive)
            Padding(
              padding: EdgeInsets.only(
                right: AppSpacing.gHalf(scale),
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _PlaybackStatusChip(
                      isPlaying: isPlaying,
                      isBuffering: isBuffering,
                      isLiveMode: isLiveMode,
                      scale: scale,
                      narrowMobile: narrowMobile,
                      chipGrey: chipGrey,
                      labelColor: titleColor,
                      isDark: isDark,
                    ),
                    LivePulsingIndicator(scale: scale),
                  ],
                ),
              ),
            )
          else
            Center(
              child: _PlaybackStatusChip(
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                isLiveMode: isLiveMode,
                scale: scale,
                narrowMobile: narrowMobile,
                chipGrey: chipGrey,
                labelColor: titleColor,
                isDark: isDark,
              ),
            ),
          SizedBox(height: statusToTimerGap),
          _DigitalTimer(
            elapsed: elapsed,
            scale: scale,
            timerTrayColor: timerTrayColor,
            timerColor: timerColor,
            captionColor: titleColor.withValues(alpha: 0.64),
            isPlaying: isPlaying,
            isBuffering: isBuffering,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.scale,
    required this.onRetry,
  });

  final String message;
  final double scale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: AppSpacing.insetSymmetric(
          layoutScale: scale,
          horizontal: 2,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          color: (isDark ? scheme.errorContainer : scheme.error)
              .withValues(alpha: isDark ? 0.28 : 0.1),
          borderRadius: AppRadii.borderRadius(AppRadii.sm, scale),
          border: Border.all(
            color: scheme.error.withValues(alpha: 0.65),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: scheme.error,
              size: AppSpacing.g(3, scale),
            ),
            SizedBox(width: AppSpacing.g(2, scale)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.dmSans(
                      fontSize: AppTypeScale.body * scale,
                      fontWeight: FontWeight.w700,
                      color: scheme.error,
                    ),
                  ),
                  SizedBox(height: AppSpacing.gHalf(scale)),
                  Text(
                    'Vérifiez votre connexion ou réessayez.',
                    style: GoogleFonts.dmSans(
                      fontSize: AppTypeScale.label * scale,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.g(2, scale)),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                textStyle: GoogleFonts.dmSans(
                  fontSize: AppTypeScale.label * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppSpacing.halfGrid * 0.1 * scale,
                ),
              ),
              child: const Text('RÉESSAYER'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackStatusChip extends StatelessWidget {
  const _PlaybackStatusChip({
    required this.isPlaying,
    required this.isBuffering,
    required this.isLiveMode,
    required this.scale,
    required this.narrowMobile,
    required this.chipGrey,
    required this.labelColor,
    required this.isDark,
  });

  final bool isPlaying;
  final bool isBuffering;
  final bool isLiveMode;
  final double scale;
  final bool narrowMobile;
  final Color chipGrey;
  final Color labelColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isListening = isPlaying && !isBuffering;
    final isLive = isListening && isLiveMode;
    final label = isBuffering
        ? 'Connexion'
        : isLive
            ? 'En direct'
            : isListening
                ? 'En écoute'
                : 'En pause';

    const liveGreen = Color(0xFF2E7D32);

    return Container(
      padding: AppSpacing.insetSymmetric(
        layoutScale: scale,
        horizontal: narrowMobile ? 2 : 3,
        vertical: narrowMobile ? 1 : 1,
      ),
      decoration: BoxDecoration(
        color: chipGrey,
        borderRadius: AppRadii.borderRadius(AppRadii.pill, scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isListening && !isLive) ...[
            Container(
              width: AppSpacing.gHalf(scale),
              height: AppSpacing.gHalf(scale),
              decoration: const BoxDecoration(
                color: liveGreen,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppSpacing.g(1, scale)),
          ],
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: AppTypeScale.label * scale,
              letterSpacing: AppSpacing.gHalf(scale) * 0.22,
              color: isDark
                  ? labelColor.withValues(alpha: 0.92)
                  : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
