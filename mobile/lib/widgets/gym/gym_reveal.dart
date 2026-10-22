import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Fade + 12px rise that plays once, when the widget first mounts.
///
/// The screen entrance timeline ([EntranceRise]) only covers what exists on
/// the first frame. Content that arrives later from the API (lists, charts)
/// uses this instead, so it still lands with the same stagger and curve.
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  /// Only the first screenful is staggered; later items rise with no delay
  /// so scrolling never waits on an animation.
  static const int maxStaggered = 8;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AuthMotion.slow,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: AuthMotion.standard),
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AuthMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    final i = widget.index;
    final delayMs = i < StaggeredReveal.maxStaggered
        ? i * AuthMotion.riseStaggerMs
        : 0;
    if (delayMs == 0) {
      _controller.forward();
    } else {
      _delay = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = AuthMotion.enter.transform(_controller.value);
          return Transform.translate(
            offset: Offset(0, AuthMotion.riseDistance * (1 - t)),
            child: child,
          );
        },
      ),
    );
  }
}

/// Horizontal meter that fills from the left once on mount
/// (approval rating, etc.). [value] is 0–1.
class GymMeter extends StatelessWidget {
  const GymMeter({super.key, required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final target = value.clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: AuthColors.line,
          borderRadius: BorderRadius.circular(2),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? target : 0, end: target),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 700),
          curve: AuthMotion.enter,
          builder: (context, v, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color ?? AuthColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clips its child to a left→right window that opens once on mount.
/// Used to "draw" charts in.
class WipeReveal extends StatelessWidget {
  const WipeReveal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 900),
      curve: AuthMotion.enter,
      child: child,
      builder: (context, t, child) =>
          ClipRect(clipper: _WipeClipper(t), child: child),
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.t);

  final double t;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(-8, -8, (size.width + 16) * t, size.height + 16);

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.t != t;
}
