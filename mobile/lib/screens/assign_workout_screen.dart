
import 'package:flutter/material.dart';
import 'package:liftlog_mobile/models/workout.dart';
import 'package:liftlog_mobile/services/api_service.dart';
import 'package:liftlog_mobile/utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AssignWorkoutScreen extends StatefulWidget {
  final String memberId;
  const AssignWorkoutScreen({super.key, required this.memberId});

  @override
  State<AssignWorkoutScreen> createState() => _AssignWorkoutScreenState();
}

class _AssignWorkoutScreenState extends State<AssignWorkoutScreen> {
  late Future<List<Workout>> _workoutsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _workoutsFuture = _fetchWorkoutTemplates();
  }

  Future<List<Workout>> _fetchWorkoutTemplates() async {
    final trainerId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    final response = await _apiService.getTrainerWorkouts();
    return response.where((workout) => workout.trainerId == trainerId).toList();
  }

  void _assignWorkout(String workoutId) async {
    try {
      await _apiService.assignWorkoutToClient(widget.memberId, workoutId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout assigned successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning workout: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Workout'),
        backgroundColor: AppTheme.darkBackground,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: FutureBuilder<List<Workout>>(
        future: _workoutsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no workout templates.', style: TextStyle(color: Colors.white)));
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
                  onTap: () => _assignWorkout(workout.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
