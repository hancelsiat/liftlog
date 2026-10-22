import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Three short bars pulsing in sequence. Replaces any spinner on buttons.
class BarLoader extends StatefulWidget {
  const BarLoader({super.key, this.color = AuthColors.onAccent});

  final Color color;

  @override
  State<BarLoader> createState() => _BarLoaderState();
}

class _BarLoaderState extends State<BarLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AuthMotion.loaderCycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AuthMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(17, 16),
          painter: _BarLoaderPainter(
            progress: _controller,
            color: widget.color,
            animate: !AuthMotion.reduced(context),
          ),
        ),
      ),
    );
  }
}

class _BarLoaderPainter extends CustomPainter {
  _BarLoaderPainter({
    required this.progress,
    required this.color,
    required this.animate,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final bool animate;

  static const double _barWidth = 3;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 3; i++) {
      double level = 1;
      if (animate) {
        final phase = (progress.value - i * 0.16) % 1.0;
        final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        level = Curves.easeInOut.transform(tri);
      }
      final h = size.height * (0.45 + 0.55 * level);
      final x = i * (_barWidth + _gap);
      final rect = Rect.fromLTWH(x, (size.height - h) / 2, _barWidth, h);
      paint.color = color.withValues(alpha: 0.4 + 0.6 * level);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarLoaderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.animate != animate;
}
