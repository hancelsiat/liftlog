import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';
import 'bar_loader.dart';

enum PressableVariant { primary, ghost }

/// Flat slab button. Springs to 0.97 on press, light haptic on tap, and
/// cross-fades its label into a [BarLoader] while [loading].
class PressableButton extends StatefulWidget {
  const PressableButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.variant = PressableVariant.primary,
    this.height = AuthSpace.buttonHeight,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final PressableVariant variant;
  final double height;
  final bool showArrow;

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _springTo(double target) {
    if (AuthMotion.reduced(context)) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(
      SpringSimulation(
        AuthMotion.spring,
        _scale.value,
        target,
        _scale.velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(PressableButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _scale.value != 1) _springTo(1);
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.variant == PressableVariant.primary;
    final reduced = AuthMotion.reduced(context);
    final disabled = widget.onPressed == null && !widget.loading;

    final Color fill;
    final Color fg;
    final Color border;
    if (primary) {
      fill = disabled ? AuthColors.surfaceHi : AuthColors.accent;
      fg = disabled ? AuthColors.textFaint : AuthColors.onAccent;
      border = disabled ? AuthColors.line : AuthColors.accent;
    } else {
      fill = Colors.transparent;
      fg = disabled ? AuthColors.textFaint : AuthColors.textPrimary;
      border = AuthColors.line;
    }

    final label = Row(
      key: const ValueKey('label'),
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label.toUpperCase(), style: AuthType.button(color: fg)),
        if (widget.showArrow) ...[
          const SizedBox(width: 10),
          Icon(Icons.arrow_forward, size: 18, color: fg),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, loading' : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _springTo(AuthMotion.pressedScale) : null,
        onTapUp: _enabled ? (_) => _springTo(1) : null,
        onTapCancel: _enabled ? () => _springTo(1) : null,
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : AuthMotion.fast,
            curve: AuthMotion.standard,
            height: widget.height,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AuthRadius.field),
              border: Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : AuthMotion.fast,
              switchInCurve: AuthMotion.standard,
              switchOutCurve: AuthMotion.exit,
              child: widget.loading
                  ? BarLoader(key: const ValueKey('loader'), color: fg)
                  : label,
            ),
          ),
        ),
      ),
    );
  }
}
