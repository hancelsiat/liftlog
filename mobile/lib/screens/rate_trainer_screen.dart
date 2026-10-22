import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/gym/gym.dart';

class RateTrainerScreen extends StatefulWidget {
  final String trainerId;

  const RateTrainerScreen({super.key, required this.trainerId});

  @override
  State<RateTrainerScreen> createState() => _RateTrainerScreenState();
}

class _RateTrainerScreenState extends State<RateTrainerScreen> {
  static const int _maxFeedbackLength = 500;
  static const List<String> _ratingLabels = [
    'Tap a star to rate',
    'Poor',
    'Fair',
    'Good',
    'Very good',
    'Excellent',
  ];

  double _rating = 0;
  bool _submitting = false;
  final _feedbackController = TextEditingController();
  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitRating() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() => _submitting = true);
    try {
      await _apiService.submitRating(
        widget.trainerId,
        _rating.toInt(),
        _feedbackController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thank you! Your feedback has been submitted successfully.',
            ),
            backgroundColor: AuthColors.surfaceHi,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We could not submit your rating at this time. Please try again.',
            ),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stars = _rating.toInt();

    return GymScaffold(
      eyebrow: 'Member / Feedback',
      title: 'Rate Your Trainer',
      // The trainer has already been left at this point, so there is no
      // back button (same as the old screen's automaticallyImplyLeading).
      showBack: false,
      bottomBar: GymBottomBar(
        child: PressableButton(
          label: 'Submit Rating',
          loading: _submitting,
          onPressed: stars > 0 && !_submitting ? _submitRating : null,
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          GymScaffold.side,
          AuthSpace.xs,
          GymScaffold.side,
          AuthSpace.l,
        ),
        children: [
          const EntranceRise(
            index: 0,
            child: GymSectionLabel(index: 1, label: 'Your rating'),
          ),
          const SizedBox(height: AuthSpace.s),
          EntranceRise(index: 1, child: _buildRatingCard(stars)),
          const SizedBox(height: AuthSpace.l),
          const EntranceRise(
            index: 2,
            child: GymSectionLabel(index: 2, label: 'Your feedback'),
          ),
          const SizedBox(height: AuthSpace.s),
          EntranceRise(index: 3, child: _buildFeedbackField()),
          const SizedBox(height: AuthSpace.xs),
          EntranceRise(
            index: 4,
            child: Text(
              'Your rating helps other members choose the right trainer.',
              style: AuthType.body(size: 13, color: AuthColors.textFaint),
            ),
          ),
        ],
      ),
    );
  }

  /// Card with header, tappable accent stars and a live verdict label.
  Widget _buildRatingCard(int stars) {
    final reduced = AuthMotion.reduced(context);
    final rated = stars > 0;

    return PressableSurface(
      highlighted: rated,
      padding: const EdgeInsets.all(AuthSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GymAvatar(icon: Icons.star_rounded, size: 40, highlighted: rated),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAINER RATING',
                      style: AuthType.display(26).copyWith(height: 1),
                    ),
                    const SizedBox(height: 4),
                    Text('HOW WAS YOUR EXPERIENCE?', style: AuthType.mono()),
                  ],
                ),
              ),
              Text(
                '$stars/5',
                style: AuthType.mono(
                  color: rated ? AuthColors.accent : AuthColors.textFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuthSpace.m),
          Center(
            child: Semantics(
              label: 'Rating, $stars out of 5 stars',
              child: RatingBar.builder(
                initialRating: 0,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                glow: false,
                itemCount: 5,
                itemSize: 44,
                unratedColor: AuthColors.textFaint,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, _) =>
                    const Icon(Icons.star_rounded, color: AuthColors.accent),
                onRatingUpdate: (rating) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: AuthSpace.s),
          AnimatedSwitcher(
            duration: reduced ? Duration.zero : AuthMotion.fast,
            switchInCurve: AuthMotion.standard,
            switchOutCurve: AuthMotion.exit,
            child: Text(
              _ratingLabels[stars].toUpperCase(),
              key: ValueKey(stars),
              textAlign: TextAlign.center,
              style: AuthType.label(
                color: rated ? AuthColors.accent : AuthColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackField() {
    return GymLabeledField(
      label: 'Comments (optional)',
      child: TextField(
        controller: _feedbackController,
        minLines: 5,
        maxLines: 8,
        maxLength: _maxFeedbackLength,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.sentences,
        style: AuthType.input(),
        cursorColor: AuthColors.accent,
        decoration: const InputDecoration(
          hintText: 'Share your experience with this trainer',
        ),
        buildCounter:
            (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => Text('$currentLength/$maxLength', style: AuthType.mono()),
      ),
    );
  }
}
