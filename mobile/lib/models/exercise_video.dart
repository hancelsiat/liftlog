class ExerciseVideo {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final String trainerName;
  final String? trainerId;
  final List<String> tags;
  final String exerciseType;
  final String difficulty;
  final int? duration;

  ExerciseVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.trainerName,
    this.trainerId,
    this.tags = const [],
    this.exerciseType = 'strength',
    this.difficulty = 'beginner',
    this.duration,
  });

  factory ExerciseVideo.fromJson(Map<String, dynamic> json) {
    // Handle trainer name and ID from populated trainer object or direct field
    String trainerName = '';
    String? trainerId;
    
    if (json['trainer'] is Map) {
      trainerName = json['trainer']['username'] ?? '';
      trainerId = json['trainer']['_id'] ?? json['trainer']['id'];
    } else if (json['trainer'] is String) {
      trainerId = json['trainer'];
      trainerName = json['trainerName'] ?? '';
    } else {
      trainerName = json['trainerName'] ?? '';
    }

    return ExerciseVideo(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      trainerName: trainerName,
      trainerId: trainerId,
      tags: json['tags'] != null
        ? List<String>.from(json['tags'])
        : [],
      exerciseType: json['exerciseType'] ?? 'strength',
      difficulty: json['difficulty'] ?? 'beginner',
      duration: json['duration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'trainerName': trainerName,
      'trainerId': trainerId,
      'tags': tags,
      'exerciseType': exerciseType,
      'difficulty': difficulty,
      'duration': duration,
    };
  }

  // Backwards-compatible getter so existing code that uses `videoFileId` keeps working.
  String get videoFileId => videoUrl;
  
  // Helper to format duration
  String get formattedDuration {
    if (duration == null || duration == 0) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
