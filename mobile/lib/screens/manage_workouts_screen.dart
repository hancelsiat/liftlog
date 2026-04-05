import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/workout.dart';
import 'create_workout_template_screen.dart';

class ManageWorkoutsScreen extends StatefulWidget {
  const ManageWorkoutsScreen({super.key});

  @override
  _ManageWorkoutsScreenState createState() => _ManageWorkoutsScreenState();
}

class _ManageWorkoutsScreenState extends State<ManageWorkoutsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Workout>> _workoutsFuture;

  @override
  void initState() {
    super.initState();
    _workoutsFuture = _fetchTrainerWorkouts();
  }

  Future<List<Workout>> _fetchTrainerWorkouts() async {
    try {
      return await _apiService.getTrainerWorkouts();
    } catch (e) {
      // Handle error appropriately
      print(e);
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Workouts'),
      ),
      body: FutureBuilder<List<Workout>>(
        future: _workoutsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have not created any workouts yet.'));
          } else {
            final workouts = snapshot.data!;
            return ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return ListTile(
                  title: Text(workout.name),
                  subtitle: Text(workout.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CreateWorkoutTemplateScreen(workout: workout),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteWorkout(workout.id);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  void _deleteWorkout(String workoutId) async {
    try {
      await _apiService.deleteWorkout(workoutId);
      setState(() {
        _workoutsFuture = _fetchTrainerWorkouts();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete workout: $e')),
      );
    }
  }
}
