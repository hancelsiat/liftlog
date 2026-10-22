import 'package:flutter/material.dart';

import '../../utils/auth_tokens.dart';
import '../auth/bar_loader.dart';

/// `01  SECTION NAME  ───────────`
class GymSectionLabel extends StatelessWidget {
  const GymSectionLabel({super.key, required this.label, this.index});

  final String label;
  final int? index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          if (index != null) ...[
            Text(
              index!.toString().padLeft(2, '0'),
              style: AuthType.mono(color: AuthColors.accent),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuthType.label(color: AuthColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: AuthColors.line),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small mono chip: `★ TOP RATED`, `STRENGTH`, `BEGINNER` …
class GymTag extends StatelessWidget {
  const GymTag({
    super.key,
    required this.label,
    this.color = AuthColors.textMuted,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AuthRadius.thumb),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label.toUpperCase(), style: AuthType.mono(color: color)),
        ],
      ),
    );
  }
}

/// Rounded-square badge with an initial or an icon.
class GymAvatar extends StatelessWidget {
  const GymAvatar({
    super.key,
    this.text = '',
    this.size = 48,
    this.highlighted = false,
    this.icon,
  });

  final String text;
  final double size;
  final bool highlighted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AuthColors.onAccent : AuthColors.textPrimary;
    final trimmed = text.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlighted ? AuthColors.accent : AuthColors.surfaceHi,
          borderRadius: BorderRadius.circular(AuthRadius.field),
          border: Border.all(
            color: highlighted ? AuthColors.accent : AuthColors.line,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: size * 0.45, color: fg)
            : Text(
                initial,
                style: AuthType.display(size * 0.55).copyWith(color: fg),
              ),
      ),
    );
  }
}

/// Five stars in the accent colour.
class GymStars extends StatelessWidget {
  const GymStars({super.key, required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final on = i < rating;
          return Icon(
            on ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: on ? AuthColors.accent : AuthColors.textFaint,
          );
        }),
      ),
    );
  }
}

/// Centered [BarLoader] in the accent colour. Replaces spinners.
class GymLoader extends StatelessWidget {
  const GymLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading',
        child: Transform.scale(
          scale: 1.8,
          child: const BarLoader(color: AuthColors.accent),
        ),
      ),
    );
  }
}

/// Outlined icon + message, for empty lists and errors.
class GymEmptyState extends StatelessWidget {
  const GymEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.danger = false,
    this.action,
  });

  final String message;
  final IconData icon;
  final bool danger;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AuthColors.danger : AuthColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuthSpace.l,
        vertical: AuthSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AuthRadius.dialog),
              border: Border.all(color: AuthColors.line),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: AuthSpace.s),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AuthType.body(color: color),
          ),
          if (action != null) ...[const SizedBox(height: AuthSpace.m), action!],
        ],
      ),
    );
  }
}

/// Pull-to-refresh in the app colours.
class GymRefresh extends StatelessWidget {
  const GymRefresh({super.key, required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AuthColors.accent,
      backgroundColor: AuthColors.surfaceHi,
      child: child,
    );
  }
}

/// Coloured status strip (ready / locked) used on the progress screen.
class GymStatusStrip extends StatelessWidget {
  const GymStatusStrip({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.lines = const [],
  });

  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuthRadius.field),
        child: ColoredBox(
          color: color.withValues(alpha: 0.08),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 2, child: ColoredBox(color: color)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.toUpperCase(),
                                style: AuthType.label(color: color),
                              ),
                              for (final line in lines) ...[
                                const SizedBox(height: 4),
                                Text(line, style: AuthType.body(size: 13)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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
