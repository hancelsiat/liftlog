
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../utils/app_theme.dart';
import 'workout_session_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  late Future<List<Workout>> _assignedWorkoutsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _assignedWorkoutsFuture = _fetchAssignedWorkouts(authProvider.user!.id);
  }

  Future<List<Workout>> _fetchAssignedWorkouts(String userId) async {
    // This uses the existing getClientProgress endpoint, which we can reuse
    final response = await _apiService.getClientProgress(userId);
    return (response as List).map((data) => Workout.fromJson(data)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Plan'),
        backgroundColor: AppTheme.darkBackground,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: FutureBuilder<List<Workout>>(
        future: _assignedWorkoutsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no assigned workouts.', style: TextStyle(color: Colors.white)));
          }

          final workouts = snapshot.data!;
          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              return Card(
                color: AppTheme.cardBackground,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(workout.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Assigned on: ${workout.date.toLocal()}`.split(' ')[0]}', style: const TextStyle(color: Colors.white70)),
                  trailing: workout.completedAt != null
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.play_circle_outline, color: AppTheme.primaryColor),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutSessionScreen(workout: workout),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
