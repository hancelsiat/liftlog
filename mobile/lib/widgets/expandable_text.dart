import 'package:flutter/material.dart';
import '../utils/auth_tokens.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;

  const ExpandableText({super.key, required this.text, this.trimLines = 3});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final textSpan = TextSpan(
          text: widget.text,
          style: const TextStyle(
            color: AuthColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: widget.trimLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        if (textPainter.didExceedMaxLines) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                maxLines: _isExpanded ? null : widget.trimLines,
                overflow: _isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AuthColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (!_isExpanded) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _toggleExpanded,
                  child: const Text(
                    'See More...',
                    style: TextStyle(
                      color: AuthColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _toggleExpanded,
                  child: const Text(
                    'See Less',
                    style: TextStyle(
                      color: AuthColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          );
        } else {
          return Text(
            widget.text,
            style: const TextStyle(
              color: AuthColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          );
        }
      },
    );
  }
}
