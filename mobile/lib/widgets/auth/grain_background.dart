import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Warm graphite base + one soft corner vignette + static film grain.
///
/// Everything here is painted once and never animates. Place it OUTSIDE the
/// Scaffold so the keyboard inset never resizes (and repaints) it.
class GrainBackground extends StatefulWidget {
  const GrainBackground({super.key, required this.child});

  final Widget child;

  @override
  State<GrainBackground> createState() => _GrainBackgroundState();
}

class _GrainBackgroundState extends State<GrainBackground> {
  // One tiny tile for the whole app lifetime, shared by every instance.
  static Future<ui.Image>? _tileFuture;
  static ui.Image? _tile;

  @override
  void initState() {
    super.initState();
    if (_tile == null) {
      _tileFuture ??= _buildTile();
      _tileFuture!.then((image) {
        _tile = image;
        if (mounted) setState(() {});
      });
    }
  }

  static Future<ui.Image> _buildTile() {
    const size = 128;
    final random = math.Random(1971);
    final pixels = Uint8List(size * size * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      final v = random.nextInt(256);
      pixels[i] = v;
      pixels[i + 1] = v;
      pixels[i + 2] = v;
      pixels[i + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _BackdropPainter(tile: _tile),
            isComplex: true,
            willChange: false,
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.tile});

  final ui.Image? tile;

  static const double _grainOpacity = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = AuthColors.bg);

    // Single soft vignette: clear centre, slightly deeper corners.
    final vignette = RadialGradient(
      radius: 1.15,
      colors: [
        AuthColors.vignette.withValues(alpha: 0),
        AuthColors.vignette.withValues(alpha: 0.55),
      ],
      stops: const [0.5, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = vignette.createShader(rect));

    final image = tile;
    if (image == null) return;

    // 2 noise pixels per logical pixel: fine grain, never blotchy.
    final matrix = Matrix4.diagonal3Values(0.5, 0.5, 1).storage;
    final grain = Paint()
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        matrix,
        filterQuality: FilterQuality.none,
      )
      ..colorFilter = ColorFilter.mode(
        Color.fromRGBO(255, 255, 255, _grainOpacity),
        BlendMode.modulate,
      );
    canvas.drawRect(rect, grain);
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => oldDelegate.tile != tile;
}
