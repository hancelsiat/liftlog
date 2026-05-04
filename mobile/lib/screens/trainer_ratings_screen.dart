import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rating_stats.dart';
import '../services/api_service.dart';
import 'package:liftlog_mobile/widgets/expandable_text.dart';
import '../utils/app_theme.dart';

class TrainerRatingsScreen extends StatefulWidget {
  const TrainerRatingsScreen({super.key});

  @override
  _TrainerRatingsScreenState createState() => _TrainerRatingsScreenState();
}

class _TrainerRatingsScreenState extends State<TrainerRatingsScreen> {
  late Future<RatingStats> _ratingsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _ratingsFuture = _apiService.getRatings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ratings'),
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
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.totalRatings == 0) {
            return const Center(child: Text('You have no ratings yet.', style: TextStyle(color: Colors.white)));
          }

          final ratingStats = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: AppTheme.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${ratingStats.ratingPercentage.toStringAsFixed(1)}% Positive Rating',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Based on ${ratingStats.totalRatings} ratings',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: ratingStats.ratings.length,
                  itemBuilder: (context, index) {
                    final rating = ratingStats.ratings[index];
                    return Card(
                      color: AppTheme.cardBackground,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(rating.rating.toString(), style: const TextStyle(color: Colors.white)),
                        ),
                        title: ExpandableText(text: rating.feedback ?? 'No feedback provided'),
                        subtitle: Text(DateFormat.yMMMd().format(rating.createdAt), style: const TextStyle(color: Colors.white70)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
