import '../models/exercise.dart';

class Workout {
  final String id;
  final String? userId;
  final String name;
  final String description;
  final DateTime date;
  final List<Exercise> exercises;
  final String title;
  final DateTime? completedAt;
  final String? trainerName;
  final String? trainerId;

  /// Set for templates in "Recently deleted".
  final DateTime? deletedAt;

  /// 'trainer' or 'admin' (older removals without it were made by an admin).
  final String? deletedByRole;
  final String? deletionReason;

  /// True when the trainer can restore it (they deleted it themselves).
  bool get deletedByTrainer => deletedByRole == 'trainer';

  Workout({
    required this.id,
    this.userId,
    required this.name,
    required this.description,
    required this.date,
    required this.exercises,
    required this.title,
    this.completedAt,
    this.trainerName,
    this.trainerId,
    this.deletedAt,
    this.deletedByRole,
    this.deletionReason,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    String? trainerName;
    String? trainerId;
    if (json['trainer'] != null && json['trainer'] is Map) {
      trainerName = json['trainer']['username'];
      trainerId = json['trainer']['_id'];
    }

    return Workout(
      id: json['_id']?.toString() ?? '',
      userId: json['user']?.toString(),
      name:
          json['title']?.toString() ??
          json['name']?.toString() ??
          'Unnamed Workout',
      description: json['description']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      exercises: json['exercises'] != null
          ? (json['exercises'] as List<dynamic>)
                .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
      title: json['title'] ?? 'Unnamed Workout',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
      trainerName: trainerName,
      trainerId: trainerId,
      deletedAt: DateTime.tryParse(json['deletedAt']?.toString() ?? ''),
      deletedByRole: json['deletedByRole']?.toString(),
      deletionReason: json['deletionReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'date': date.toIso8601String(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'title': title,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
