import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Dashed drop zone for the trainer credential. Becomes a thumbnail row
/// (thumb scales 0.92 → 1) once an image is picked.
class CredentialPicker extends StatelessWidget {
  const CredentialPicker({
    super.key,
    required this.file,
    required this.onPick,
    this.showRequired = false,
  });

  final File? file;
  final VoidCallback onPick;

  /// Paint the border in danger tone (credential missing on submit).
  final bool showRequired;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final picked = file != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TRAINER CREDENTIAL', style: AuthType.label()),
        const SizedBox(height: AuthSpace.xs),
        Semantics(
          button: true,
          label: picked
              ? 'Trainer credential selected. Tap to replace.'
              : 'Upload trainer credential image',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPick,
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: showRequired && !picked
                    ? AuthColors.danger
                    : picked
                    ? AuthColors.textMuted
                    : AuthColors.line,
              ),
              child: SizedBox(
                height: 72,
                child: AnimatedSwitcher(
                  duration: reduced ? Duration.zero : AuthMotion.base,
                  switchInCurve: AuthMotion.enter,
                  switchOutCurve: AuthMotion.exit,
                  child: picked ? _picked(reduced) : _empty(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.symmetric(horizontal: AuthSpace.s),
      child: Row(
        children: [
          const Icon(Icons.add, size: 20, color: AuthColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add a photo of your certification',
              style: AuthType.body(color: AuthColors.textPrimary, size: 14),
            ),
          ),
          Text('JPG · PNG', style: AuthType.mono(color: AuthColors.textFaint)),
        ],
      ),
    );
  }

  Widget _picked(bool reduced) {
    final name = file!.path.split(RegExp(r'[\\/]')).last;
    return Padding(
      key: ValueKey(file!.path),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduced ? 1 : 0.92, end: 1),
            duration: reduced ? Duration.zero : AuthMotion.base,
            curve: AuthMotion.enter,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AuthRadius.thumb),
              child: Image.file(
                file!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 48,
                  height: 48,
                  child: ColoredBox(color: AuthColors.surfaceHi),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuthType.body(color: AuthColors.textPrimary, size: 14),
                ),
                const SizedBox(height: 2),
                Text('Tap to replace', style: AuthType.mono()),
              ],
            ),
          ),
          const Icon(Icons.check, size: 18, color: AuthColors.accent),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      const Radius.circular(AuthRadius.field),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        dashed.addPath(metric.extractPath(d, d + _dash), Offset.zero);
        d += _dash + _gap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
