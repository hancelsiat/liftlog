import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';

class RoleSegment<T> {
  const RoleSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Two-up segmented control. The accent pill rides between segments on a
/// spring (it keeps its velocity if the user taps back mid-travel).
class RoleSegmentedControl<T> extends StatefulWidget {
  const RoleSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<RoleSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  State<RoleSegmentedControl<T>> createState() =>
      _RoleSegmentedControlState<T>();
}

class _RoleSegmentedControlState<T> extends State<RoleSegmentedControl<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: _indexOf(widget.selected).toDouble(),
  );

  int _indexOf(T value) {
    final i = widget.segments.indexWhere((s) => s.value == value);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(RoleSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      final target = _indexOf(widget.selected).toDouble();
      if (AuthMotion.reduced(context)) {
        _position.value = target;
      } else {
        _position.animateWith(
          SpringSimulation(
            AuthMotion.spring,
            _position.value,
            target,
            _position.velocity,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.segments.length;

    return Container(
      height: AuthSpace.segmentHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AuthRadius.field),
        border: Border.all(color: AuthColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / count;
          return Stack(
            children: [
              AnimatedBuilder(
                animation: _position,
                builder: (context, _) => Positioned(
                  left: _position.value * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AuthColors.accent,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AuthRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(child: _segment(widget.segments[i], i)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(RoleSegment<T> segment, int index) {
    final selected = segment.value == widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: segment.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onChanged(segment.value);
              },
        child: Center(
          // Label colour follows the pill's actual position, so the text
          // flips exactly as the pill passes under it.
          child: AnimatedBuilder(
            animation: _position,
            builder: (context, _) {
              final cover = (1 - (_position.value - index).abs()).clamp(
                0.0,
                1.0,
              );
              return Text(
                segment.label.toUpperCase(),
                style: AuthType.button(
                  color: Color.lerp(
                    AuthColors.textMuted,
                    AuthColors.onAccent,
                    cover,
                  )!,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Helper line under the role control. Cross-fades with a 4px slide when the
/// text changes.
class RoleHelperLine extends StatelessWidget {
  const RoleHelperLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : AuthMotion.base,
      switchInCurve: AuthMotion.enter,
      switchOutCurve: AuthMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: SizedBox(
        key: ValueKey(text),
        width: double.infinity,
        child: Text(text, style: AuthType.body(size: 13)),
      ),
    );
  }
}
