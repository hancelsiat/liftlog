import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rating.dart';
import '../models/rating_stats.dart';
import '../services/api_service.dart';
import '../widgets/expandable_text.dart';
import '../widgets/gym/gym.dart';

/// Shows anonymous feedback for a trainer so a member can decide
/// whether to choose them. Pops with `true` if the member taps
/// "Choose this Trainer".
class TrainerFeedbackScreen extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final String? trainerBio;

  const TrainerFeedbackScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
    this.trainerBio,
  });

  @override
  State<TrainerFeedbackScreen> createState() => _TrainerFeedbackScreenState();
}

class _TrainerFeedbackScreenState extends State<TrainerFeedbackScreen> {
  final ApiService _apiService = ApiService();
  late Future<RatingStats> _ratingsFuture;

  @override
  void initState() {
    super.initState();
    _ratingsFuture = _apiService.getTrainerRating(widget.trainerId);
  }

  Future<void> _refresh() async {
    setState(() {
      _ratingsFuture = _apiService.getTrainerRating(widget.trainerId);
    });
    await _ratingsFuture;
  }

  Widget _buildHeader(RatingStats? stats) {
    final bio = widget.trainerBio?.trim() ?? '';
    return PressableSurface(
      padding: const EdgeInsets.all(AuthSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GymAvatar(text: widget.trainerName, size: 52, highlighted: true),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.trainerName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuthType.display(32),
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: AuthSpace.s),
            ExpandableText(text: bio),
          ],
          const SizedBox(height: AuthSpace.m),
          if (stats != null && stats.totalRatings > 0) ...[
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: stats.averageRating.toStringAsFixed(1),
                    caption: '/ 5 avg',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${stats.ratingPercentage.toStringAsFixed(1)}%',
                    caption: 'approval',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${stats.totalRatings}',
                    caption: 'review${stats.totalRatings == 1 ? '' : 's'}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuthSpace.s),
            GymStars(rating: stats.averageRating.round(), size: 20),
            const SizedBox(height: 12),
            GymMeter(value: stats.ratingPercentage / 100),
          ] else
            Text('No reviews yet', style: AuthType.body()),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Rating rating) {
    final feedback = (rating.feedback ?? '').trim();
    return PressableSurface(
      padding: const EdgeInsets.all(AuthSpace.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GymAvatar(icon: Icons.person_outline, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Username is intentionally hidden — feedback is anonymous
                    Expanded(
                      child: Text(
                        'Anonymous Member',
                        style: AuthType.body(
                          color: AuthColors.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GymStars(rating: rating.rating, size: 14),
                  ],
                ),
                const SizedBox(height: 8),
                ExpandableText(
                  text: feedback.isEmpty
                      ? 'No written feedback provided'
                      : feedback,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat.yMMMd()
                      .format(rating.createdAt.toLocal())
                      .toUpperCase(),
                  style: AuthType.mono(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Trainer / Anonymous reviews',
      title: 'Trainer Feedback',
      body: FutureBuilder<RatingStats>(
        future: _ratingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const GymLoader();
          }
          if (snapshot.hasError) {
            return Center(
              child: GymEmptyState(
                icon: Icons.error_outline,
                danger: true,
                message: 'Could not load feedback: ${snapshot.error}',
              ),
            );
          }

          final stats = snapshot.data;
          final ratings = stats?.ratings ?? <Rating>[];

          return GymRefresh(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GymScaffold.side,
                AuthSpace.xs,
                GymScaffold.side,
                AuthSpace.m,
              ),
              // Header, section label, then one row per rating
              // (or a single empty-state row).
              itemCount: ratings.isEmpty ? 3 : ratings.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return StaggeredReveal(index: 0, child: _buildHeader(stats));
                }
                if (index == 1) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(0, AuthSpace.l, 0, 12),
                    child: StaggeredReveal(
                      index: 1,
                      child: GymSectionLabel(label: 'Feedback'),
                    ),
                  );
                }
                if (ratings.isEmpty) {
                  return const GymEmptyState(
                    icon: Icons.rate_review_outlined,
                    message: 'This trainer has no feedback yet.',
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StaggeredReveal(
                    index: index,
                    child: _buildFeedbackCard(ratings[index - 2]),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomBar: GymBottomBar(
        child: PressableButton(
          label: 'Choose this Trainer',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AuthType.display(34)),
        ),
        const SizedBox(height: 2),
        Text(caption.toUpperCase(), style: AuthType.mono()),
      ],
    );
  }
}
