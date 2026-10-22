import 'package:flutter/material.dart';
import '../widgets/gym/gym.dart';

class CredentialViewerScreen extends StatelessWidget {
  final String imageUrl;

  /// Name the trainer typed at sign-up. Shown above the photo so the admin
  /// can check it matches the name on the credential. Empty for trainers
  /// who registered before the field existed.
  final String fullName;

  final String username;

  const CredentialViewerScreen({
    super.key,
    required this.imageUrl,
    this.fullName = '',
    this.username = '',
  });

  @override
  Widget build(BuildContext context) {
    final hasName = fullName.trim().isNotEmpty;
    return GymScaffold(
      eyebrow: 'Admin / Review',
      title: 'Trainer Credential',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          GymScaffold.side,
          AuthSpace.xs,
          GymScaffold.side,
          AuthSpace.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EntranceRise(
              index: 0,
              child: _NameToMatch(
                fullName: fullName.trim(),
                username: username,
                hasName: hasName,
              ),
            ),
            const SizedBox(height: AuthSpace.s),
            Expanded(child: _buildImage()),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return EntranceRise(
      index: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuthRadius.dialog),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            border: Border.all(color: AuthColors.line),
            borderRadius: BorderRadius.circular(AuthRadius.dialog),
          ),
          child: InteractiveViewer(
            panEnabled: false, // Set to true to allow panning
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.network(
                imageUrl,
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) return child;
                      final total = loadingProgress.expectedTotalBytes;
                      return Padding(
                        padding: const EdgeInsets.all(AuthSpace.l),
                        child: total != null
                            ? SizedBox(
                                width: 160,
                                child: GymMeter(
                                  value:
                                      loadingProgress.cumulativeBytesLoaded /
                                      total,
                                ),
                              )
                            : const GymLoader(),
                      );
                    },
                errorBuilder:
                    (
                      BuildContext context,
                      Object exception,
                      StackTrace? stackTrace,
                    ) {
                      return const GymEmptyState(
                        icon: Icons.broken_image_outlined,
                        danger: true,
                        message: 'Could not load credential image.',
                      );
                    },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The declared name, labelled so the admin knows what to compare.
class _NameToMatch extends StatelessWidget {
  const _NameToMatch({
    required this.fullName,
    required this.username,
    required this.hasName,
  });

  final String fullName;
  final String username;
  final bool hasName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        border: Border.all(color: hasName ? AuthColors.line : GymColors.warn),
        borderRadius: BorderRadius.circular(AuthRadius.dialog),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NAME GIVEN AT SIGN-UP', style: AuthType.label()),
            const SizedBox(height: 6),
            SelectableText(
              hasName ? fullName : 'Not provided',
              style: AuthType.display(
                24,
              ).copyWith(height: 1.1, color: hasName ? null : GymColors.warn),
            ),
            if (username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('@$username', style: AuthType.mono()),
            ],
            const SizedBox(height: 8),
            Text(
              hasName
                  ? 'Check that this name matches the name on the credential below.'
                  : 'This trainer signed up before full names were required. '
                        'Check the credential carefully before approving.',
              style: AuthType.body(size: 13, color: AuthColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
