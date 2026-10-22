import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';

/// 48px search box in the auth field style: search icon, text, and a clear
/// button once something is typed. Reports every change via [onChanged].
class GymSearchField extends StatefulWidget {
  const GymSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final bool enabled;

  @override
  State<GymSearchField> createState() => _GymSearchFieldState();
}

class _GymSearchFieldState extends State<GymSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
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
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AuthMotion.reduced(context);
    final hasText = _controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: reduced ? Duration.zero : AuthMotion.fast,
      curve: AuthMotion.standard,
      height: AuthSpace.tapTarget,
      decoration: BoxDecoration(
        color: _focused ? AuthColors.surfaceHi : AuthColors.surface,
        borderRadius: BorderRadius.circular(AuthRadius.field),
        border: Border.all(
          color: _focused
              ? AuthColors.accent.withValues(alpha: 0.6)
              : AuthColors.line,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            size: 20,
            color: _focused ? AuthColors.textPrimary : AuthColors.textMuted,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onChanged: (value) {
                widget.onChanged(value);
                setState(() {}); // show / hide the clear button
              },
              onTapOutside: (_) => _focus.unfocus(),
              style: AuthType.input(),
              cursorWidth: 2,
              cursorHeight: 20,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: widget.hint,
                hintStyle: AuthType.input(color: AuthColors.textFaint),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          if (hasText)
            Semantics(
              button: true,
              label: 'Clear search',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.enabled ? _clear : null,
                child: const SizedBox(
                  width: AuthSpace.tapTarget,
                  height: AuthSpace.tapTarget,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AuthColors.textMuted,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// True when every whitespace-separated word of [query] appears
/// (case-insensitively) in at least one of [fields].
bool matchesSearch(String query, Iterable<String?> fields) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return true;
  final haystack = fields
      .whereType<String>()
      .map((f) => f.toLowerCase())
      .join('\n');
  return words.every(haystack.contains);
}
