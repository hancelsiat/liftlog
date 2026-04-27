
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutSessionScreen({super.key, required this.workout});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final ApiService _apiService = ApiService();

  void _markAsComplete() async {
    try {
      await _apiService.markWorkoutAsComplete(widget.workout.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout completed!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing workout: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.title),
        backgroundColor: AppTheme.darkBackground,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.workout.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = widget.workout.exercises[index];
                  return Card(
                    color: AppTheme.cardBackground,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(exercise.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${exercise.sets} sets of ${exercise.reps} reps', style: const TextStyle(color: Colors.white70)),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _markAsComplete,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Mark as Complete'),
            ),
          ],
        ),
      ),
    );
  }
}
