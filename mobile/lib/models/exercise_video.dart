class ExerciseVideo {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String trainerName;
  final List<String> tags;
  final String exerciseType;
  final String difficulty;

  ExerciseVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.trainerName,
    this.tags = const [],
    this.exerciseType = 'strength',
    this.difficulty = 'beginner',
  });

  factory ExerciseVideo.fromJson(Map<String, dynamic> json) {
    return ExerciseVideo(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      trainerName: json['trainerName'] ?? '',
      tags: json['tags'] != null
        ? List<String>.from(json['tags'])
        : [],
      exerciseType: json['exerciseType'] ?? 'strength',
      difficulty: json['difficulty'] ?? 'beginner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'trainerName': trainerName,
      'tags': tags,
      'exerciseType': exerciseType,
      'difficulty': difficulty,
    };
  }
}
