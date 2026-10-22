import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Provides the screen's single entrance timeline (0 → 1 over
/// [AuthMotion.entranceTotalMs]). Every entrance widget below reads its own
/// window of that timeline, so the choreography stays in one place and each
/// element still gets its own start, duration and curve.
class EntranceScope extends InheritedWidget {
  const EntranceScope({
    super.key,
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EntranceScope>()?.animation ??
      kAlwaysCompleteAnimation;

  @override
  bool updateShouldNotify(EntranceScope oldWidget) =>
      oldWidget.animation != animation;
}

Interval _window(int startMs, int durationMs, Curve curve) {
  const total = AuthMotion.entranceTotalMs;
  final begin = (startMs / total).clamp(0.0, 1.0);
  final end = ((startMs + durationMs) / total).clamp(begin, 1.0);
  return Interval(begin, end, curve: curve);
}

/// Plain opacity window. Used for the top bar.
class EntranceFade extends StatelessWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.startMs = 0,
    this.durationMs = AuthMotion.topBarMs,
    this.curve = AuthMotion.standard,
  });

  final Widget child;
  final int startMs;
  final int durationMs;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final animation = EntranceScope.of(context);
    return FadeTransition(
      opacity: animation.drive(
        CurveTween(curve: _window(startMs, durationMs, curve)),
      ),
      child: child,
    );
  }
}

/// translateY 12px → 0 with opacity. Opacity resolves faster than the
/// travel, so the element is readable before it fully lands.
class EntranceRise extends StatelessWidget {
  const EntranceRise({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = EntranceScope.of(context);
    final start = AuthMotion.riseStartMs + index * AuthMotion.riseStaggerMs;
    final travel = _window(start, 260, AuthMotion.enter);
    final fade = _window(start, 180, AuthMotion.standard);

    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: fade)),
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = travel.transform(animation.value);
          return Transform.translate(
            offset: Offset(0, AuthMotion.riseDistance * (1 - t)),
            child: child,
          );
        },
      ),
    );
  }
}

/// Display headline whose lines rise from behind a ClipRect mask.
class HeadlineReveal extends StatelessWidget {
  const HeadlineReveal({
    super.key,
    required this.lines,
    required this.fontSize,
    required this.semanticsLabel,
  });

  final List<String> lines;
  final double fontSize;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final animation = EntranceScope.of(context);
    final style = AuthType.display(fontSize);

    return Semantics(
      header: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines.length; i++)
              ClipRect(
                child: AnimatedBuilder(
                  animation: animation,
                  child: Text(
                    lines[i],
                    style: style,
                    maxLines: 1,
                    softWrap: false,
                    textHeightBehavior: const TextHeightBehavior(
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                  builder: (context, child) {
                    final window = _window(
                      AuthMotion.headlineStartMs +
                          i * AuthMotion.headlineStaggerMs,
                      AuthMotion.slow.inMilliseconds,
                      AuthMotion.enter,
                    );
                    final t = window.transform(animation.value);
                    return FractionalTranslation(
                      translation: Offset(0, 1 - t),
                      child: child,
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
