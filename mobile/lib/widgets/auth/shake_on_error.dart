import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Horizontal damped shake (±6px → 0, 3 oscillations, 360ms).
///
/// Declarative: bump [trigger] to play it again.
class ShakeOnError extends StatefulWidget {
  const ShakeOnError({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AuthMotion.shake,
  );

  @override
  void didUpdateWidget(ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        widget.trigger > 0 &&
        !AuthMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final dx = (t == 0 || t == 1)
            ? 0.0
            : AuthMotion.shakeAmplitude *
                  (1 - t) *
                  math.sin(t * AuthMotion.shakeOscillations * 2 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
