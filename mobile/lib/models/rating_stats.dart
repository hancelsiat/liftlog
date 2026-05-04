import './rating.dart';

class RatingStats {
  final List<Rating> ratings;
  final double averageRating;
  final int totalRatings;
  final double ratingPercentage;

  RatingStats({
    required this.ratings,
    required this.averageRating,
    required this.totalRatings,
    required this.ratingPercentage,
  });

  factory RatingStats.fromJson(Map<String, dynamic> json) {
    return RatingStats(
      ratings: (json['ratings'] as List).map((i) => Rating.fromJson(i)).toList(),
      averageRating: (json['averageRating'] as num).toDouble(),
      totalRatings: json['totalRatings'] as int,
      ratingPercentage: (json['ratingPercentage'] as num).toDouble(),
    );
  }
}
