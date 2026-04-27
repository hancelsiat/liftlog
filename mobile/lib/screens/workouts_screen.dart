
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
  final ApiService _apiService = ApiService();
  Future<void>? _loadFuture;
  List<Workout> _assignedWorkouts = [];
  List<Map<String, dynamic>> _trainers = [];
  User? _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _user = Provider.of<AuthProvider>(context, listen: false).user;
    if (_user != null) {
      _loadFuture = _user!.trainer != null
          ? _fetchAssignedWorkouts()
          : _loadTrainers();
    }
  }

  Future<void> _fetchAssignedWorkouts() async {
    final response = await _apiService.getAssignedWorkouts();
    if (mounted) {
      setState(() {
        _assignedWorkouts = (response as List).map((data) => Workout.fromJson(data)).toList();
      });
    }
  }

  Future<void> _loadTrainers() async {
    final trainers = await _apiService.getAvailableTrainers();
    if (mounted) {
      setState(() {
        _trainers = trainers;
      });
    }
  }

  Future<void> _selectTrainer(String trainerId) async {
    try {
      await _apiService.selectTrainer(trainerId);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadProfile(context);
      if (mounted) {
        setState(() {
          _user = authProvider.user;
          _loadFuture = _fetchAssignedWorkouts();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting trainer: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.trainer != null ? 'My Plan' : 'Choose a Trainer'),
        backgroundColor: AppTheme.darkBackground,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }

          if (_user?.trainer != null) {
            return _buildWorkoutsList();
          } else {
            return _buildTrainersList();
          }
        },
      ),
    );
  }

  Widget _buildTrainersList() {
    if (_trainers.isEmpty) {
      return const Center(
        child: Text('No trainers available', style: TextStyle(color: Colors.white)),
      );
    }

    return ListView.builder(
      itemCount: _trainers.length,
      itemBuilder: (context, index) {
        final trainer = _trainers[index];
        return Card(
          color: AppTheme.cardBackground,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Text(trainer['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
            ),
            title: Text(trainer['username'], style: const TextStyle(color: Colors.white)),
            subtitle: Text(trainer['email'], style: const TextStyle(color: Colors.white70)),
            onTap: () => _selectTrainer(trainer['_id']),
          ),
        );
      },
    );
  }

  Widget _buildWorkoutsList() {
    if (_assignedWorkouts.isEmpty) {
      return const Center(
        child: Text('Your trainer has not assigned you a plan yet.', style: const TextStyle(color: Colors.white)),
      );
    }

    return ListView.builder(
      itemCount: _assignedWorkouts.length,
      itemBuilder: (context, index) {
        final workout = _assignedWorkouts[index];
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
              ).then((_) {
                // Refresh the list after a workout session
                setState(() {
                  _loadFuture = _fetchAssignedWorkouts();
                });
              });
            },
          ),
        );
      },
    );
  }
}
