class Rating {
  final int rating;
  final String? feedback;
  final DateTime createdAt;
  final String? memberName;

  Rating({
    required this.rating,
    this.feedback,
    required this.createdAt,
    this.memberName,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      rating: json['rating'],
      feedback: json['feedback'],
      createdAt: DateTime.parse(json['createdAt']),
      memberName: json['member'] != null ? json['member']['username'] : null,
    );
  }
}
