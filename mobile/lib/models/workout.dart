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

  Workout({
    required this.id,
    this.userId,
    required this.name,
    required this.description,
    required this.date,
    required this.exercises,
    required this.title,
    this.completedAt,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['_id']?.toString() ?? '',
      userId: json['user']?.toString(),
      name: json['title']?.toString() ?? json['name']?.toString() ?? 'Unnamed Workout',
      description: json['description']?.toString() ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now(),
      exercises: json['exercises'] != null
          ? (json['exercises'] as List<dynamic>).map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      title: json['title'] ?? 'Unnamed Workout',
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
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
