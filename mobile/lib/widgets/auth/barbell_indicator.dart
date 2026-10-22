import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';
import 'staggered_entrance.dart';

enum BarbellPhase { idle, working, lockout }

/// The form's progress, drawn as a barbell.
///
/// * One plate pair springs on for every valid field ([plates]).
/// * [BarbellPhase.working]: slow reps (6px, 900ms loop) while a request runs.
/// * [BarbellPhase.lockout]: bar lifts 4px and holds. Used on success.
/// * Bump [failTrigger] to play the failed rep: a dip plus a damped shake.
class BarbellIndicator extends StatefulWidget {
  const BarbellIndicator({
    super.key,
    required this.plates,
    required this.maxPlates,
    this.phase = BarbellPhase.idle,
    this.failTrigger = 0,
  });

  static const String heroTag = 'auth-barbell';
  static const Size size = Size(184, 40);

  final int plates;
  final int maxPlates;
  final BarbellPhase phase;
  final int failTrigger;

  @override
  State<BarbellIndicator> createState() => _BarbellIndicatorState();
}

class _BarbellIndicatorState extends State<BarbellIndicator>
    with TickerProviderStateMixin {
  static const int _slots = 3;

  late final List<AnimationController> _plates = List.generate(
    _slots,
    (i) => AnimationController.unbounded(
      vsync: this,
      value: i < widget.plates ? 1 : 0,
    ),
  );
  late final AnimationController _rep = AnimationController(
    vsync: this,
    duration: AuthMotion.repHalf,
  );
  late final AnimationController _lockout = AnimationController(
    vsync: this,
    duration: AuthMotion.base,
    value: widget.phase == BarbellPhase.lockout ? 1 : 0,
  );
  late final AnimationController _fail = AnimationController(
    vsync: this,
    duration: AuthMotion.barbellFail,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRep();
  }

  @override
  void didUpdateWidget(BarbellIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduced = AuthMotion.reduced(context);

    if (widget.plates != oldWidget.plates) {
      for (var i = 0; i < _slots; i++) {
        final target = i < widget.plates ? 1.0 : 0.0;
        final c = _plates[i];
        if ((c.value - target).abs() < 0.001 && !c.isAnimating) continue;
        if (reduced) {
          c.value = target;
        } else {
          c.animateWith(
            SpringSimulation(AuthMotion.spring, c.value, target, c.velocity),
          );
        }
      }
      if (widget.plates > oldWidget.plates) HapticFeedback.selectionClick();
    }

    if (widget.phase != oldWidget.phase) {
      _syncRep();
      if (widget.phase == BarbellPhase.lockout) {
        reduced ? _lockout.value = 1 : _lockout.forward();
      } else {
        reduced ? _lockout.value = 0 : _lockout.reverse();
      }
    }

    if (widget.failTrigger != oldWidget.failTrigger &&
        widget.failTrigger > 0 &&
        !reduced) {
      _fail.forward(from: 0);
    }
  }

  void _syncRep() {
    final working = widget.phase == BarbellPhase.working;
    if (working && !AuthMotion.reduced(context)) {
      if (!_rep.isAnimating) _rep.repeat(reverse: true);
    } else if (_rep.isAnimating || _rep.value != 0) {
      _rep.animateBack(0, duration: AuthMotion.fast);
    }
  }

  @override
  void dispose() {
    for (final c in _plates) {
      c.dispose();
    }
    _rep.dispose();
    _lockout.dispose();
    _fail.dispose();
    super.dispose();
  }

  Offset _offset() {
    final rep = AuthMotion.repDepth * Curves.easeInOut.transform(_rep.value);
    final lift =
        -AuthMotion.lockoutLift * AuthMotion.enter.transform(_lockout.value);

    var dx = 0.0;
    var dip = 0.0;
    final f = _fail.value;
    if (f > 0 && f < 1) {
      dip = 7 * math.sin(math.pi * f) * (1 - f);
      dx =
          AuthMotion.shakeAmplitude *
          (1 - f) *
          math.sin(f * AuthMotion.shakeOscillations * 2 * math.pi);
    }
    return Offset(dx, rep + lift + dip);
  }

  @override
  Widget build(BuildContext context) {
    final entrance = EntranceScope.of(context);
    const total = AuthMotion.entranceTotalMs;
    final window = Interval(
      AuthMotion.barbellStartMs / total,
      (AuthMotion.barbellStartMs + AuthMotion.barbellMs) / total,
      curve: AuthMotion.enter,
    );

    final label = widget.phase == BarbellPhase.lockout
        ? 'Ready'
        : '${widget.plates} of ${widget.maxPlates} fields complete';

    // The entrance fade lives OUTSIDE the Hero: when the barbell flies in
    // from the other auth screen it must arrive fully visible, and the
    // entrance window (60–320ms) is already over when the flight lands.
    final bar = Hero(
      tag: BarbellIndicator.heroTag,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_rep, _lockout, _fail, ..._plates]),
          builder: (context, _) => Transform.translate(
            offset: _offset(),
            child: CustomPaint(
              size: BarbellIndicator.size,
              painter: _BarbellPainter(
                plates: [for (final c in _plates) c.value],
                maxPlates: widget.maxPlates,
                lockout: _lockout.value,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: entrance,
          child: bar,
          builder: (context, child) {
            final t = window.transform(entrance.value);
            return Opacity(
              opacity: t,
              child: Transform.scale(
                scaleX: 0.9 + 0.1 * t,
                alignment: Alignment.centerLeft,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarbellPainter extends CustomPainter {
  _BarbellPainter({
    required this.plates,
    required this.maxPlates,
    required this.lockout,
  });

  /// Spring value per slot (0 = off, 1 = loaded; may overshoot slightly).
  final List<double> plates;
  final int maxPlates;
  final double lockout;

  static const double _sleeve = 48;
  static const double _plateWidth = 7;
  static const double _plateGap = 2;
  static const List<double> _plateHeights = [36, 30, 24];

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final barColor = Color.lerp(
      AuthColors.textMuted,
      AuthColors.accent,
      lockout.clamp(0.0, 1.0),
    )!;

    // Shaft and sleeves.
    final shaft = Paint()..color = AuthColors.line;
    canvas.drawRect(
      Rect.fromLTRB(_sleeve, cy - 1.5, size.width - _sleeve, cy + 1.5),
      shaft,
    );

    final sleeve = Paint()..color = barColor;
    canvas.drawRect(Rect.fromLTRB(0, cy - 2.5, _sleeve, cy + 2.5), sleeve);
    canvas.drawRect(
      Rect.fromLTRB(size.width - _sleeve, cy - 2.5, size.width, cy + 2.5),
      sleeve,
    );

    // Collars.
    final collar = Paint()..color = barColor;
    for (final x in [_sleeve, size.width - _sleeve]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, cy), width: 4, height: 12),
          const Radius.circular(1),
        ),
        collar,
      );
    }

    final ghost = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AuthColors.line;
    final plate = Paint()..color = AuthColors.textPrimary;

    final slots = math.min(maxPlates, plates.length);
    for (var i = 0; i < slots; i++) {
      final dist = 2 + i * (_plateWidth + _plateGap) + _plateWidth / 2;
      final h = _plateHeights[i];
      final v = plates[i];

      for (final side in [-1.0, 1.0]) {
        final cx = side < 0 ? _sleeve - dist : size.width - _sleeve + dist;
        final slot = Rect.fromCenter(
          center: Offset(cx, cy),
          width: _plateWidth,
          height: h,
        );
        if (v < 0.98) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              slot.deflate(0.5),
              const Radius.circular(1.5),
            ),
            ghost,
          );
        }
        if (v > 0.01) {
          // Plate slides in from the sleeve end while growing to full height.
          final slide = (1 - v) * 10 * side;
          final rect = Rect.fromCenter(
            center: Offset(cx + slide, cy),
            width: _plateWidth,
            height: math.max(0, h * (0.6 + 0.4 * v)),
          );
          plate.color = AuthColors.textPrimary.withValues(
            alpha: v.clamp(0.0, 1.0),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
            plate,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BarbellPainter oldDelegate) =>
      oldDelegate.lockout != lockout ||
      oldDelegate.maxPlates != maxPlates ||
      !_listEquals(oldDelegate.plates, plates);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
