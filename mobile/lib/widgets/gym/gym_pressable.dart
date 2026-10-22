import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';

/// Spring-driven press scale shared by the tappable app surfaces.
mixin _SpringPress<T extends StatefulWidget> on State<T>, TickerProvider {
  // Created on first use. Surfaces without onTap may never touch it, and
  // creating it inside dispose() would look up TickerMode on a deactivated
  // element, so dispose() only cleans up a controller that exists.
  AnimationController? _scale;

  AnimationController get scale =>
      _scale ??= AnimationController.unbounded(vsync: this, value: 1);

  void springTo(double target) {
    if (AuthMotion.reduced(context)) {
      scale.value = target;
      return;
    }
    scale.animateWith(
      SpringSimulation(AuthMotion.spring, scale.value, target, scale.velocity),
    );
  }

  @override
  void dispose() {
    _scale?.dispose();
    super.dispose();
  }
}

/// Flat graphite panel with a hairline border. When [onTap] is set it
/// springs to 0.98 and lifts its fill while pressed.
class PressableSurface extends StatefulWidget {
  const PressableSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AuthSpace.s),
    this.highlighted = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Accent border, e.g. for a top-rated trainer.
  final bool highlighted;
  final String? semanticLabel;

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface>
    with SingleTickerProviderStateMixin, _SpringPress {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    springTo(value ? 0.98 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);

    final surface = AnimatedContainer(
      duration: reduced ? Duration.zero : AuthMotion.fast,
      curve: AuthMotion.standard,
      padding: widget.padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _pressed ? AuthColors.surfaceHi : AuthColors.surface,
        borderRadius: BorderRadius.circular(AuthRadius.dialog),
        border: Border.all(
          color: widget.highlighted
              ? AuthColors.accent.withValues(alpha: 0.6)
              : AuthColors.line,
        ),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return surface;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap!();
        },
        child: ScaleTransition(scale: scale, child: surface),
      ),
    );
  }
}

/// Compact 40px button for use inside cards. Label uses the 12px tracked
/// label style so two of them fit side by side on a 360px screen.
class GymSmallButton extends StatefulWidget {
  const GymSmallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;

  @override
  State<GymSmallButton> createState() => _GymSmallButtonState();
}

class _GymSmallButtonState extends State<GymSmallButton>
    with SingleTickerProviderStateMixin, _SpringPress {
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final fg = widget.primary ? AuthColors.onAccent : AuthColors.textPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => springTo(AuthMotion.pressedScale) : null,
        onTapUp: enabled ? (_) => springTo(1) : null,
        onTapCancel: enabled ? () => springTo(1) : null,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        child: ScaleTransition(
          scale: scale,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.primary ? AuthColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AuthRadius.pill),
              border: Border.all(
                color: widget.primary ? AuthColors.accent : AuthColors.line,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuthType.label(
                      color: fg,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px square icon button with a hairline border.
class GymIconButton extends StatefulWidget {
  const GymIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  /// Solid accent fill (chat send button).
  final bool filled;

  @override
  State<GymIconButton> createState() => _GymIconButtonState();
}

class _GymIconButtonState extends State<GymIconButton>
    with SingleTickerProviderStateMixin, _SpringPress {
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final Color fg;
    final Color border;
    final Color fill;
    if (widget.filled) {
      fill = enabled ? AuthColors.accent : AuthColors.surfaceHi;
      fg = enabled ? AuthColors.onAccent : AuthColors.textFaint;
      border = enabled ? AuthColors.accent : AuthColors.line;
    } else if (widget.danger) {
      fill = AuthColors.danger.withValues(alpha: 0.08);
      fg = AuthColors.danger;
      border = AuthColors.danger.withValues(alpha: 0.35);
    } else {
      fill = Colors.transparent;
      fg = enabled ? AuthColors.textPrimary : AuthColors.textFaint;
      border = AuthColors.line;
    }

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => springTo(0.9) : null,
          onTapUp: enabled ? (_) => springTo(1) : null,
          onTapCancel: enabled ? () => springTo(1) : null,
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onTap!();
                }
              : null,
          child: ScaleTransition(
            scale: scale,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AuthRadius.field),
                border: Border.all(color: border),
              ),
              child: Icon(widget.icon, size: 20, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
