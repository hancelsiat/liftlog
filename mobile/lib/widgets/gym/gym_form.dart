import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';
import '../../utils/gym_theme.dart';
import '../auth/pressable_button.dart';

/// [showDialog] for form dialogs (radios, text input) that cannot use
/// `showAuthDialog`. Dialog routes sit above the screen's [GymScaffold]
/// theme, so the [GymTheme] is applied here explicitly.
Future<T?> showGymDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final theme = GymTheme.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: AuthColors.barrier,
    builder: (dialogContext) =>
        Theme(data: theme, child: builder(dialogContext)),
  );
}

/// Uppercase label above any input, matching [AuthTextField]'s label.
/// Use for multi-line [TextFormField]s, dropdowns and read-only values.
class GymLabeledField extends StatelessWidget {
  const GymLabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AuthType.label()),
        const SizedBox(height: AuthSpace.xs),
        child,
      ],
    );
  }
}

/// Selectable mono chip (exercise type, role filter …).
class GymChoiceChip extends StatelessWidget {
  const GymChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final enabled = onTap != null;
    final fg = selected
        ? AuthColors.onAccent
        : enabled
        ? AuthColors.textPrimary
        : AuthColors.textFaint;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : AuthMotion.fast,
          curve: AuthMotion.standard,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AuthColors.accent : AuthColors.surface,
            borderRadius: BorderRadius.circular(AuthRadius.pill),
            border: Border.all(
              color: selected ? AuthColors.accent : AuthColors.line,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: AuthType.label(
              color: fg,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Accent-coloured [Switch] for use on dark surfaces.
class GymSwitch extends StatelessWidget {
  const GymSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AuthColors.onAccent,
      activeTrackColor: AuthColors.accent,
      inactiveThumbColor: AuthColors.textMuted,
      inactiveTrackColor: AuthColors.surfaceHi,
      trackOutlineColor: const WidgetStatePropertyAll(AuthColors.line),
    );
  }
}

/// Frame for form dialogs, matching `showAuthDialog`: eyebrow, display
/// title, scrollable [child], then a ghost + primary action row.
class GymFormDialog extends StatelessWidget {
  const GymFormDialog({
    super.key,
    required this.title,
    required this.child,
    required this.confirmLabel,
    required this.onConfirm,
    this.eyebrow,
    this.cancelLabel = 'Cancel',
    this.loading = false,
  });

  final String? eyebrow;
  final String title;
  final Widget child;
  final String confirmLabel;

  /// Null disables the primary button.
  final VoidCallback? onConfirm;
  final String cancelLabel;

  /// Shows a loader on the primary button and locks Cancel.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AuthSpace.m,
        vertical: AuthSpace.l,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuthSpace.m,
            AuthSpace.m,
            AuthSpace.m,
            AuthSpace.s,
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
              const SizedBox(height: AuthSpace.s),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: AuthSpace.m),
              Padding(
                padding: const EdgeInsets.only(bottom: AuthSpace.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: PressableButton(
                        label: cancelLabel,
                        variant: PressableVariant.ghost,
                        height: 52,
                        showArrow: false,
                        onPressed: loading
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PressableButton(
                        label: confirmLabel,
                        height: 52,
                        showArrow: false,
                        loading: loading,
                        onPressed: onConfirm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-choice list in the app style (hairline rows, accent dot).
/// Replaces `RadioGroup` + `RadioListTile` in the gym screens.
class GymRadioList<T> extends StatelessWidget {
  const GymRadioList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelOf,
  });

  final List<T> options;
  final T selected;

  /// Null disables every row.
  final ValueChanged<T>? onChanged;
  final String Function(T value)? labelOf;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final enabled = onChanged != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: option == selected,
            enabled: enabled,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onChanged!(option);
                    }
                  : null,
              child: AnimatedContainer(
                duration: reduced ? Duration.zero : AuthMotion.fast,
                curve: AuthMotion.standard,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: option == selected
                      ? AuthColors.surfaceHi
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AuthRadius.field),
                  border: Border.all(
                    color: option == selected
                        ? AuthColors.accent.withValues(alpha: 0.6)
                        : AuthColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    _RadioDot(on: option == selected, enabled: enabled),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        labelOf?.call(option) ?? option.toString(),
                        style: AuthType.body(
                          size: 14,
                          color: enabled
                              ? AuthColors.textPrimary
                              : AuthColors.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.on, required this.enabled});

  final bool on;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AuthColors.textFaint
        : on
        ? AuthColors.accent
        : AuthColors.textMuted;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: on
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
