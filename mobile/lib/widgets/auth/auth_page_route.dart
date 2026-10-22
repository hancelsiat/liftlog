import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Shared-axis (horizontal) route between the two auth screens.
///
/// Incoming page: +24px → 0 with fade in. Outgoing page: 0 → −24px with
/// fade out. [reverse] flips the axis (used when going "back" to login).
/// The barbell Hero flies across on top of this.
///
/// Only animates the outgoing page when the next route is also an
/// [AuthPageRoute], so the dashboard fade route is left untouched.
class AuthPageRoute<T> extends PageRoute<T> {
  AuthPageRoute({required this.builder, this.reverse = false, super.settings});

  final WidgetBuilder builder;
  final bool reverse;

  static const double _distance = 24;

  @override
  Duration get transitionDuration => AuthMotion.route;

  @override
  Duration get reverseTransitionDuration => AuthMotion.route;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is AuthPageRoute;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      previousRoute is AuthPageRoute;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

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

    final dir = reverse ? -1.0 : 1.0;

    // Incoming: fade in over the back 2/3 so the outgoing page has cleared.
    final inFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: AuthMotion.standard),
      reverseCurve: const Interval(0.3, 1, curve: AuthMotion.exit),
    );
    final inSlide = CurvedAnimation(
      parent: animation,
      curve: AuthMotion.enter,
      reverseCurve: AuthMotion.exit,
    );

    // Outgoing: fade out over the first 1/3.
    final outFade = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0, 0.3, curve: AuthMotion.exit),
    );
    final outSlide = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AuthMotion.enter,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final dx =
            dir * _distance * (1 - inSlide.value) -
            dir * _distance * outSlide.value;
        final opacity = inFade.value * (1 - outFade.value);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(dx, 0), child: child),
        );
      },
    );
  }
}
