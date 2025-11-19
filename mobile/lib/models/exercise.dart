class Exercise {
  final String name;
  final int sets;
  final int reps;
  final int weight;
  final String notes;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.weight = 0,
    this.notes = '',
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name']?.toString() ?? '',
      sets: json['sets'] is int ? json['sets'] : int.tryParse(json['sets']?.toString() ?? '3') ?? 3,
      reps: json['reps'] is int ? json['reps'] : int.tryParse(json['reps']?.toString() ?? '10') ?? 10,
      weight: json['weight'] is int ? json['weight'] : int.tryParse(json['weight']?.toString() ?? '0') ?? 0,
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'notes': notes,
    };
  }
}
