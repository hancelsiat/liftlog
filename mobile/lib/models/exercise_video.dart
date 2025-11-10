class ExerciseVideo {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String trainerName;
  final List<String> tags;

  ExerciseVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.trainerName,
    this.tags = const [],
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
    };
  }
}