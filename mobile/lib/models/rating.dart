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
    // Feedback is anonymous: the backend no longer sends member info.
    // Kept defensive in case an older backend still returns a populated member.
    final member = json['member'];
    return Rating(
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      feedback: json['feedback'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      memberName: member is Map ? member['username'] as String? : null,
    );
  }
}
