class Workout {
  final String id;
  final String userId;
  final String name;
  final String description;
  final DateTime date;
  final List<String> exercises;

  Workout({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.date,
    required this.exercises,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['_id'],
      userId: json['userId'],
      name: json['name'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      exercises: List<String>.from(json['exercises']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'date': date.toIso8601String(),
      'exercises': exercises,
    };
  }
}
