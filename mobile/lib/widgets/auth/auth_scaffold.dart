import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';
import 'grain_background.dart';
import 'staggered_entrance.dart';

/// Shared frame for both auth screens:
/// grain backdrop → top bar → scrollable body (header pinned to the top,
/// form pushed to the bottom) → footer pinned above the safe area.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.entrance,
    required this.step,
    required this.header,
    required this.form,
    required this.footer,
  });

  final Animation<double> entrance;
  final String step;
  final Widget header;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AuthTheme.of(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AuthColors.bg,
        ),
        child: GrainBackground(
          child: EntranceScope(
            animation: entrance,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    EntranceFade(child: _TopBar(step: step)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuthSpace.side,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AuthSpace.xs,
                                        bottom: AuthSpace.m,
                                      ),
                                      child: header,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AuthSpace.s,
                                      ),
                                      child: form,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),
                    ),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step});

  final String step;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AuthSpace.tapTarget,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuthSpace.side),
        child: Row(
          children: [
            Text(
              'LIFTLOG',
              style: AuthType.mono(
                color: AuthColors.textPrimary,
              ).copyWith(letterSpacing: 2.4, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(step.toUpperCase(), style: AuthType.mono()),
          ],
        ),
      ),
    );
  }
}

/// "Question? Action" line pinned to the bottom of the screen.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$prompt $action',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: AuthSpace.tapTarget,
          margin: const EdgeInsets.only(bottom: AuthSpace.xs),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AuthColors.line)),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$prompt  ', style: AuthType.body(size: 14)),
                TextSpan(
                  text: action,
                  style:
                      AuthType.body(
                        color: AuthColors.textPrimary,
                        size: 14,
                        weight: FontWeight.w600,
                      ).copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: AuthColors.accent,
                        decorationThickness: 2,
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
