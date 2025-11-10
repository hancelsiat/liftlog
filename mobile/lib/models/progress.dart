class Progress {
  final String id;
  final String userId;
  final double bmi;
  final double caloriesIntake;
  final double calorieDeficit;
  final DateTime date;

  Progress({
    required this.id,
    required this.userId,
    required this.bmi,
    required this.caloriesIntake,
    required this.calorieDeficit,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      bmi: (json['bmi'] as num?)?.toDouble() ?? 0.0,
      caloriesIntake: (json['caloriesIntake'] as num?)?.toDouble() ?? 0.0,
      calorieDeficit: (json['calorieDeficit'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'bmi': bmi,
      'caloriesIntake': caloriesIntake,
      'calorieDeficit': calorieDeficit,
      'date': date.toIso8601String(),
    };
  }
}