class Progress {
  final String id;
  final String userId;
  final double? bmi;
  final double? caloriesIntake;
  final double? calorieDeficit;
  final DateTime date;
  final DateTime? lastBmiUpdate;
  final DateTime? lastCaloriesUpdate;

  Progress({
    required this.id,
    required this.userId,
    this.bmi,
    this.caloriesIntake,
    this.calorieDeficit,
    DateTime? date,
    this.lastBmiUpdate,
    this.lastCaloriesUpdate,
  }) : date = date ?? DateTime.now();

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? json['user'] ?? '',
      bmi: (json['bmi'] as num?)?.toDouble(),
      caloriesIntake: (json['caloriesIntake'] as num?)?.toDouble(),
      calorieDeficit: (json['calorieDeficit'] as num?)?.toDouble(),
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      lastBmiUpdate: json['lastBmiUpdate'] != null ? DateTime.parse(json['lastBmiUpdate']) : null,
      lastCaloriesUpdate: json['lastCaloriesUpdate'] != null ? DateTime.parse(json['lastCaloriesUpdate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      if (bmi != null) 'bmi': bmi,
      if (caloriesIntake != null) 'caloriesIntake': caloriesIntake,
      if (calorieDeficit != null) 'calorieDeficit': calorieDeficit,
      'date': date.toIso8601String(),
      if (lastBmiUpdate != null) 'lastBmiUpdate': lastBmiUpdate!.toIso8601String(),
      if (lastCaloriesUpdate != null) 'lastCaloriesUpdate': lastCaloriesUpdate!.toIso8601String(),
    };
  }

  // Helper method to check if BMI can be updated (7 days)
  bool canUpdateBmi() {
    if (lastBmiUpdate == null) return true;
    final daysSince = DateTime.now().difference(lastBmiUpdate!).inDays;
    return daysSince >= 7;
  }

  // Helper method to check if Calories can be updated (24 hours)
  bool canUpdateCalories() {
    if (lastCaloriesUpdate == null) return true;
    final hoursSince = DateTime.now().difference(lastCaloriesUpdate!).inHours;
    return hoursSince >= 24;
  }

  // Get days until next BMI update
  int daysUntilNextBmiUpdate() {
    if (lastBmiUpdate == null) return 0;
    final daysSince = DateTime.now().difference(lastBmiUpdate!).inDays;
    return (7 - daysSince).clamp(0, 7);
  }

  // Get hours until next Calories update
  int hoursUntilNextCaloriesUpdate() {
    if (lastCaloriesUpdate == null) return 0;
    final hoursSince = DateTime.now().difference(lastCaloriesUpdate!).inHours;
    return (24 - hoursSince).clamp(0, 24);
  }
}
