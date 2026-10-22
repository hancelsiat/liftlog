import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';
import 'pressable_button.dart';

class AuthDialogAction {
  const AuthDialogAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
}

/// Shows an auth-styled dialog: scale 0.96 → 1 + fade in, graphite barrier.
Future<T?> showAuthDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required List<AuthDialogAction> Function(BuildContext dialogContext) actions,
  String? eyebrow,
  bool barrierDismissible = true,
}) {
  final reduced = AuthMotion.reduced(context);
  final theme = AuthTheme.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AuthColors.barrier,
    transitionDuration: reduced ? Duration.zero : AuthMotion.base,
    pageBuilder: (dialogContext, _, _) => Theme(
      data: theme,
      child: _AuthDialog(
        eyebrow: eyebrow,
        title: title,
        message: message,
        actions: actions(dialogContext),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AuthMotion.enter,
        reverseCurve: AuthMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AuthDialog extends StatelessWidget {
  const _AuthDialog({
    required this.title,
    required this.message,
    required this.actions,
    this.eyebrow,
  });

  final String? eyebrow;
  final String title;
  final String message;
  final List<AuthDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuthSpace.m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    AuthSpace.m,
                    AuthSpace.m,
                    AuthSpace.m,
                    AuthSpace.s,
                  ),
                  decoration: BoxDecoration(
                    color: AuthColors.surface,
                    borderRadius: BorderRadius.circular(AuthRadius.dialog),
                    border: Border.all(color: AuthColors.line),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (eyebrow != null) ...[
                        Text(
                          eyebrow!.toUpperCase(),
                          style: AuthType.mono(color: AuthColors.accent),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(title, style: AuthType.display(28)),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(message, style: AuthType.body()),
                        ),
                      ),
                      const SizedBox(height: AuthSpace.m),
                      _actions(),
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

  Widget _actions() {
    if (actions.length == 1) {
      final a = actions.single;
      return Padding(
        padding: const EdgeInsets.only(bottom: AuthSpace.xs),
        child: PressableButton(
          label: a.label,
          onPressed: a.onPressed,
          height: 52,
          showArrow: false,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AuthSpace.xs),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: PressableButton(
                label: actions[i].label,
                onPressed: actions[i].onPressed,
                variant: actions[i].primary
                    ? PressableVariant.primary
                    : PressableVariant.ghost,
                height: 52,
                showArrow: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
