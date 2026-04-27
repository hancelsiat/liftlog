
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import 'assign_workout_screen.dart';
import 'create_workout_template_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final User client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late Future<List<Workout>> _progressFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _progressFuture = _fetchProgress();
  }

  Future<List<Workout>> _fetchProgress() async {
    final response = await _apiService.getClientProgress(widget.client.id);
    return (response as List).map((data) => Workout.fromJson(data)).toList();
  }

  void _removeClient() async {
    try {
      await _apiService.removeClient(widget.client.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client removed successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing client: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteWorkout(String workoutId) async {
    try {
      await _apiService.deleteWorkout(workoutId);
      setState(() {
        _progressFuture = _fetchProgress();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting workout: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.username),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Remove Client'),
                    content: const Text('Are you sure you want to remove this client?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _removeClient();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      backgroundColor: AppTheme.darkBackground,
      body: _buildProgressTab(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssignWorkoutScreen(memberId: widget.client.id),
            ),
          ).then((_) {
            // Refresh progress when coming back
            setState(() {
              _progressFuture = _fetchProgress();
            });
          });
        },
        child: const Icon(Icons.assignment),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildProgressTab() {
    return FutureBuilder<List<Workout>>(
      future: _progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No workouts assigned yet.', style: TextStyle(color: Colors.white)));
        }

        final workouts = snapshot.data!;
        return ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            final formattedDate = DateFormat.yMMMd().format(workout.date.toLocal());
            return Card(
              color: AppTheme.cardBackground,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(workout.title, style: const TextStyle(color: Colors.white)),
                subtitle: Text('Assigned on: $formattedDate', style: const TextStyle(color: Colors.white70)),
                trailing: workout.completedAt != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateWorkoutTemplateScreen(workout: workout),
                                ),
                              ).then((_) {
                                setState(() {
                                  _progressFuture = _fetchProgress();
                                });
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteWorkout(workout.id),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
