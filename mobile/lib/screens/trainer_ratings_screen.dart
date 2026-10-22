import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rating.dart';
import '../models/rating_stats.dart';
import '../services/api_service.dart';
import 'package:liftlog_mobile/widgets/expandable_text.dart';
import '../widgets/gym/gym.dart';

class TrainerRatingsScreen extends StatefulWidget {
  const TrainerRatingsScreen({super.key});

  @override
  State<TrainerRatingsScreen> createState() => _TrainerRatingsScreenState();
}

class _TrainerRatingsScreenState extends State<TrainerRatingsScreen> {
  late Future<RatingStats> _ratingsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _ratingsFuture = _apiService.getRatings();
  }

  Future<void> _refresh() async {
    final future = _apiService.getRatings();
    setState(() => _ratingsFuture = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Trainer / Feedback',
      title: 'My Ratings',
      body: GymRefresh(
        onRefresh: _refresh,
        child: FutureBuilder<RatingStats>(
          future: _ratingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const GymLoader();
            }
            if (snapshot.hasError) {
              return _scrollableMessage(
                GymEmptyState(
                  icon: Icons.error_outline,
                  danger: true,
                  message: 'Error: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.totalRatings == 0) {
              return _scrollableMessage(
                const GymEmptyState(
                  icon: Icons.star_outline_rounded,
                  message: 'You have no ratings yet.',
                ),
              );
            }

            final ratingStats = snapshot.data!;
            final ratings = ratingStats.ratings;

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GymScaffold.side,
                AuthSpace.xs,
                GymScaffold.side,
                AuthSpace.l,
              ),
              // Summary, section label, then one card per rating.
              itemCount: ratings.length + 2,
              separatorBuilder: (context, index) =>
                  SizedBox(height: index < 2 ? AuthSpace.m : 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return StaggeredReveal(
                    index: 0,
                    child: _SummaryCard(stats: ratingStats),
                  );
                }
                if (index == 1) {
                  return const GymSectionLabel(index: 1, label: 'Reviews');
                }
                final i = index - 2;
                return StaggeredReveal(
                  index: i + 1,
                  child: _RatingCard(rating: ratings[i]),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        child,
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats});

  final RatingStats stats;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      padding: const EdgeInsets.all(AuthSpace.m),
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPROVAL', style: AuthType.mono(color: AuthColors.accent)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stats.ratingPercentage.toStringAsFixed(1),
                style: AuthType.display(56),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '% POSITIVE',
                  style: AuthType.label(color: AuthColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuthSpace.s),
          GymMeter(value: stats.ratingPercentage / 100),
          const SizedBox(height: 12),
          Text(
            'Based on ${stats.totalRatings} '
            '${stats.totalRatings == 1 ? 'rating' : 'ratings'}',
            style: AuthType.body(size: 14),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating});

  final Rating rating;

  @override
  Widget build(BuildContext context) {
    final feedback = rating.feedback;
    return PressableSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GymStars(rating: rating.rating),
              const Spacer(),
              Text(
                DateFormat.yMMMd().format(rating.createdAt).toUpperCase(),
                style: AuthType.mono(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (feedback != null && feedback.trim().isNotEmpty)
            ExpandableText(text: feedback)
          else
            Text(
              'No feedback provided',
              style: AuthType.body(size: 14, color: AuthColors.textFaint),
            ),
        ],
      ),
    );
  }
}
