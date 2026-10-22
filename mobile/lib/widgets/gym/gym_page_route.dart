import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Forward navigation between app screens: the new page slides up 24px
/// and fades in over the outgoing one, which dims slightly and drifts up.
/// The page's own entrance (title reveal + stagger) plays on top of this.
///
/// Uses a fade only under reduced motion.
class GymPageRoute<T> extends PageRoute<T> {
  GymPageRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => AuthMotion.route;

  @override
  Duration get reverseTransitionDuration => AuthMotion.base;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AuthMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final enter = CurvedAnimation(
      parent: animation,
      curve: AuthMotion.enter,
      reverseCurve: AuthMotion.exit,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: AuthMotion.standard),
      reverseCurve: const Interval(0, 0.8, curve: AuthMotion.exit),
    );
    final under = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AuthMotion.enter,
      reverseCurve: AuthMotion.exit,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final dy = 24 * (1 - enter.value) - 8 * under.value;
        final dim = 1 - 0.4 * under.value;
        return Opacity(
          opacity: (fade.value * dim).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}
