import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';
import 'gym_pressable.dart';

/// Square accent check box for multi-select lists. [partial] draws a dash
/// (used by "select all" when only some rows are selected).
class GymCheckbox extends StatelessWidget {
  const GymCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.partial = false,
    this.semanticLabel,
  });

  final bool value;
  final bool partial;

  /// Null disables the box.
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final enabled = onChanged != null;
    final on = value || partial;

    return Semantics(
      checked: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : AuthMotion.fast,
              curve: AuthMotion.standard,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: on ? AuthColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(AuthRadius.thumb),
                border: Border.all(
                  color: on
                      ? AuthColors.accent
                      : enabled
                      ? AuthColors.textMuted
                      : AuthColors.line,
                  width: 1.5,
                ),
              ),
              child: on
                  ? Icon(
                      value ? Icons.check : Icons.remove,
                      size: 18,
                      color: AuthColors.onAccent,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar shown while a list is in multi-select mode: a "select all"
/// box, the selected count, an exit button and a row of bulk [actions]
/// (usually [GymSmallButton]s, laid out with equal widths).
///
/// While [busyLabel] is set (e.g. "Deleting 2/5…") every control is locked.
class GymSelectionBar extends StatelessWidget {
  const GymSelectionBar({
    super.key,
    required this.selectedCount,
    required this.selectableCount,
    required this.onSelectAll,
    required this.onClear,
    required this.onClose,
    required this.actions,
    this.busyLabel,
  });

  final int selectedCount;

  /// How many rows can be selected (for the "select all" box state).
  final int selectableCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final List<Widget> actions;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final busy = busyLabel != null;
    final all = selectableCount > 0 && selectedCount >= selectableCount;
    final some = selectedCount > 0 && !all;

    return Container(
      // The 44px check box has its own 10px inset around the 24px box,
      // so the left padding is trimmed to line it up with the cards.
      padding: const EdgeInsets.fromLTRB(
        AuthSpace.s - 10,
        6,
        AuthSpace.s,
        AuthSpace.s,
      ),
      decoration: const BoxDecoration(
        color: AuthColors.bg,
        border: Border(top: BorderSide(color: AuthColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GymCheckbox(
                value: all,
                partial: some,
                semanticLabel: all ? 'Clear selection' : 'Select all',
                onChanged: busy || selectableCount == 0
                    ? null
                    : (_) => all ? onClear() : onSelectAll(),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  busy
                      ? busyLabel!.toUpperCase()
                      : '$selectedCount OF $selectableCount SELECTED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuthType.mono(
                    color: selectedCount > 0 || busy
                        ? AuthColors.accent
                        : AuthColors.textMuted,
                  ),
                ),
              ),
              GymIconButton(
                icon: Icons.close,
                tooltip: 'Exit selection',
                onTap: busy ? null : onClose,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: IgnorePointer(
              ignoring: busy,
              child: AnimatedOpacity(
                duration: AuthMotion.fast,
                opacity: busy ? 0.4 : 1,
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
