import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';
import '../../utils/gym_theme.dart';
import '../auth/grain_background.dart';
import '../auth/staggered_entrance.dart';
import 'gym_pressable.dart';

/// Shared frame for the in-app screens, matching the auth screens:
/// grain backdrop → top bar (back, eyebrow, display title, actions) →
/// optional [bottom] (tabs) → [body] → optional pinned [bottomBar].
///
/// Owns one entrance timeline exposed through [EntranceScope], so any
/// [EntranceRise] / [EntranceFade] in [body] joins the same choreography
/// as login and signup.
class GymScaffold extends StatefulWidget {
  const GymScaffold({
    super.key,
    required this.title,
    required this.body,
    this.eyebrow,
    this.actions = const [],
    this.leading,
    this.showBack = true,
    this.bottom,
    this.bottomBar,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  /// Replaces the back button (e.g. the logo on the dashboard).
  final Widget? leading;
  final bool showBack;
  final Widget? bottom;
  final Widget body;
  final Widget? bottomBar;

  static const double side = AuthSpace.s;

  @override
  State<GymScaffold> createState() => _GymScaffoldState();
}

class _GymScaffoldState extends State<GymScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: AuthMotion.entranceTotalMs),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AuthMotion.reduced(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = widget.showBack && Navigator.of(context).canPop();
    final leading =
        widget.leading ??
        (canPop
            ? GymIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              )
            : null);

    return Theme(
      data: GymTheme.of(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AuthColors.bg,
        ),
        child: GrainBackground(
          child: EntranceScope(
            animation: _entrance,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                bottom: widget.bottomBar == null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      leading: leading,
                      eyebrow: widget.eyebrow,
                      title: widget.title,
                      actions: widget.actions,
                    ),
                    if (widget.bottom != null)
                      EntranceFade(
                        startMs: AuthMotion.riseStartMs,
                        durationMs: 200,
                        child: widget.bottom!,
                      ),
                    Expanded(child: widget.body),
                  ],
                ),
              ),
              bottomNavigationBar: widget.bottomBar == null
                  ? null
                  : SafeArea(
                      top: false,
                      child: EntranceRise(index: 4, child: widget.bottomBar!),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.leading,
    required this.eyebrow,
    required this.title,
    required this.actions,
  });

  final Widget? leading;
  final String? eyebrow;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        AuthSpace.xs,
        GymScaffold.side,
        AuthSpace.s,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (leading != null) ...[
            EntranceFade(child: leading!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null)
                  EntranceFade(
                    child: Text(
                      eyebrow!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuthType.mono(),
                    ),
                  ),
                _RevealTitle(title: title),
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: 8),
            EntranceFade(child: action),
          ],
        ],
      ),
    );
  }
}

/// Single-line display title that rises out of a mask like the auth
/// headline, but ellipsizes long names (trainers, chat partners).
class _RevealTitle extends StatelessWidget {
  const _RevealTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final animation = EntranceScope.of(context);
    const total = AuthMotion.entranceTotalMs;
    const window = Interval(
      AuthMotion.headlineStartMs / total,
      (AuthMotion.headlineStartMs + 420) / total,
      curve: AuthMotion.enter,
    );

    return Semantics(
      header: true,
      label: title,
      child: ExcludeSemantics(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: animation,
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuthType.display(34),
            ),
            builder: (context, child) => FractionalTranslation(
              translation: Offset(0, 1 - window.transform(animation.value)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action pinned to the bottom of a screen.
class GymBottomBar extends StatelessWidget {
  const GymBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        12,
        GymScaffold.side,
        AuthSpace.s,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AuthColors.line)),
      ),
      child: child,
    );
  }
}

/// Underline tabs in the auth label style; sits in [GymScaffold.bottom].
class GymTabBar extends StatelessWidget implements PreferredSizeWidget {
  const GymTabBar({super.key, required this.controller, required this.tabs});

  final TabController controller;
  final List<String> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorWeight: 2,
      splashFactory: NoSplash.splashFactory,
      tabs: [for (final t in tabs) Tab(text: t.toUpperCase())],
    );
  }
}
