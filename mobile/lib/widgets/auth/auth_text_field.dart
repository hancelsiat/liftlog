import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/auth_tokens.dart';

/// Flat 52px field with an uppercase label above it.
///
/// Focus: fill lifts to surfaceHi and an accent underline draws left → right.
/// Error: underline turns danger, message opens below with AnimatedSize.
/// Participates in the surrounding [Form] like a TextFormField.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscurable = false,
    this.autofillHints,
    this.onSubmitted,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscurable;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final FocusNode _focus = FocusNode();
  bool _obscure = true;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final fast = reduced ? Duration.zero : AuthMotion.fast;
    final base = reduced ? Duration.zero : AuthMotion.base;

    return FormField<String>(
      // Validate the live controller text, exactly like
      // TextFormField(controller: ...) did before.
      validator: (_) => widget.validator?.call(widget.controller.text),
      builder: (field) {
        final hasError = field.hasError;
        final labelColor = hasError
            ? AuthColors.danger
            : _focused
            ? AuthColors.textPrimary
            : AuthColors.textMuted;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: fast,
              style: AuthType.label(color: labelColor),
              child: Text(widget.label.toUpperCase()),
            ),
            const SizedBox(height: AuthSpace.xs),
            AnimatedContainer(
              duration: fast,
              curve: AuthMotion.standard,
              height: AuthSpace.fieldHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _focused ? AuthColors.surfaceHi : AuthColors.surface,
                borderRadius: BorderRadius.circular(AuthRadius.field),
                border: Border.all(
                  color: hasError
                      ? AuthColors.danger.withValues(alpha: 0.55)
                      : AuthColors.line,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(child: _input(field)),
                        if (widget.obscurable)
                          _EyeToggle(
                            obscured: _obscure,
                            active: _focused,
                            duration: fast,
                            onTap: () => setState(() => _obscure = !_obscure),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: _Underline(
                      visible: _focused || hasError,
                      color: hasError ? AuthColors.danger : AuthColors.accent,
                      duration: base,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: base,
              curve: AuthMotion.enter,
              alignment: Alignment.topLeft,
              child: hasError
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(field.errorText!, style: AuthType.error()),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }

  Widget _input(FormFieldState<String> field) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscurable && _obscure,
      enableSuggestions: !widget.obscurable,
      autocorrect: false,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      onSubmitted: widget.onSubmitted,
      onChanged: (value) {
        field.didChange(value);
        // Once an error is showing, re-check live so it clears the moment
        // the input becomes valid.
        if (field.hasError) field.validate();
      },
      style: AuthType.input(),
      cursorWidth: 2,
      cursorHeight: 20,
      textAlignVertical: TextAlignVertical.center,
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.symmetric(horizontal: AuthSpace.s),
      ),
    );
  }
}

/// 2px bar that draws in from the left edge.
class _Underline extends StatelessWidget {
  const _Underline({
    required this.visible,
    required this.color,
    required this.duration,
  });

  final bool visible;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: duration,
      curve: visible ? AuthMotion.enter : AuthMotion.exit,
      builder: (context, value, _) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

/// Show/hide password. Icon swaps with a short rotate + fade.
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({
    required this.obscured,
    required this.active,
    required this.duration,
    required this.onTap,
  });

  final bool obscured;
  final bool active;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscured ? 'Show password' : 'Hide password',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: AuthSpace.tapTarget,
          height: AuthSpace.fieldHeight,
          child: Center(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: AuthMotion.standard,
              switchOutCurve: AuthMotion.exit,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: RotationTransition(
                  turns: Tween(begin: -0.125, end: 0.0).animate(animation),
                  child: child,
                ),
              ),
              child: Icon(
                obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                key: ValueKey(obscured),
                size: 20,
                color: active ? AuthColors.textPrimary : AuthColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
