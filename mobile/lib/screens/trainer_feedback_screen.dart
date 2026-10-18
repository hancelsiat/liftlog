import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rating.dart';
import '../models/rating_stats.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../widgets/expandable_text.dart';

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

  Widget _buildStars(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: AppTheme.secondaryColor,
          size: size,
        );
      }),
    );
  }

  Widget _buildHeader(RatingStats? stats) {
    final bio = widget.trainerBio?.trim() ?? '';
    return Card(
      color: AppTheme.cardBackground,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.trainerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpandableText(text: bio),
            ],
            const SizedBox(height: 12),
            if (stats != null && stats.totalRatings > 0)
              Row(
                children: [
                  _buildStars(stats.averageRating.round(), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${stats.averageRating.toStringAsFixed(1)} / 5  •  '
                      '${stats.ratingPercentage.toStringAsFixed(1)}% approval  •  '
                      '${stats.totalRatings} review${stats.totalRatings == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              )
            else
              const Text(
                'No reviews yet',
                style: TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Rating rating) {
    final feedback = (rating.feedback ?? '').trim();
    return Card(
      color: AppTheme.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.person_outline, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Username is intentionally hidden — feedback is anonymous
                      const Expanded(
                        child: Text(
                          'Anonymous Member',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStars(rating.rating),
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
                    DateFormat.yMMMd().format(rating.createdAt.toLocal()),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Feedback'),
        backgroundColor: AppTheme.darkBackground,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: FutureBuilder<RatingStats>(
        future: _ratingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load feedback: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final stats = snapshot.data;
          final ratings = stats?.ratings ?? <Rating>[];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: ratings.isEmpty ? 2 : ratings.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildHeader(stats);
                if (ratings.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'This trainer has no feedback yet.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }
                return _buildFeedbackCard(ratings[index - 1]);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Choose this Trainer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ),
      ),
    );
  }
}
