import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// Inline server error. Opens/closes with AnimatedSize + fade so the layout
/// below never jumps.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final duration = reduced ? Duration.zero : AuthMotion.base;
    final text = message;

    return AnimatedSize(
      duration: duration,
      curve: AuthMotion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AuthMotion.standard,
        switchOutCurve: AuthMotion.exit,
        child: text == null
            ? const SizedBox(key: ValueKey('none'), width: double.infinity)
            : Padding(
                key: ValueKey(text),
                padding: const EdgeInsets.only(top: AuthSpace.s),
                child: Semantics(
                  liveRegion: true,
                  // A left-only Border can't be combined with borderRadius
                  // (Flutter asserts), so the accent edge is a clipped child.
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AuthRadius.field),
                    child: ColoredBox(
                      color: AuthColors.danger.withValues(alpha: 0.08),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(
                              width: 2,
                              child: ColoredBox(color: AuthColors.danger),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  14,
                                  12,
                                ),
                                child: Text(text, style: AuthType.error()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
