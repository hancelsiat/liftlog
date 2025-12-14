import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _workouts = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedTrainerId;

  @override
  void initState() {
    super.initState();
    _loadTrainers();
  }

  void _loadTrainers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final apiService = ApiService();
      final trainers = await apiService.getAvailableTrainers();

      setState(() {
        _trainers = trainers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      if (e.toString().contains('Authentication required')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        // Navigate back to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _loadWorkoutsByTrainer(String trainerId) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _selectedTrainerId = trainerId;
      });

      final apiService = ApiService();
      final workouts = await apiService.getWorkoutsByTrainer(trainerId);

      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      if (e.toString().contains('Authentication required')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        // Navigate back to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user?.role != UserRole.member) {
      return const Scaffold(
        body: Center(child: Text('This screen is only for members')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Workouts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      ElevatedButton(
                        onPressed: _selectedTrainerId != null ? () => _loadWorkoutsByTrainer(_selectedTrainerId!) : _loadTrainers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _selectedTrainerId == null
                  ? _buildTrainersList()
                  : _buildWorkoutsList(),
    );
  }

  Widget _buildTrainersList() {
    if (_trainers.isEmpty) {
      return const Center(
        child: Text('No trainers available'),
      );
    }

    return ListView.builder(
      itemCount: _trainers.length,
      itemBuilder: (context, index) {
        final trainer = _trainers[index];
        final firstName = trainer['profile']?['firstName'] ?? '';
        final lastName = trainer['profile']?['lastName'] ?? '';
        final displayName = firstName.isNotEmpty || lastName.isNotEmpty
            ? '$firstName $lastName'.trim()
            : trainer['username'] ?? 'Unknown Trainer';

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.fitness_center),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(trainer['email'] ?? ''),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _loadWorkoutsByTrainer(trainer['_id']),
          ),
        );
      },
    );
  }

  Widget _buildWorkoutsList() {
    if (_workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No workouts available from this trainer'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedTrainerId = null;
                  _workouts = [];
                });
                _loadTrainers();
              },
              child: const Text('Choose Different Trainer'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Available Workouts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Change Trainer'),
                onPressed: () {
                  setState(() {
                    _selectedTrainerId = null;
                    _workouts = [];
                  });
                  _loadTrainers();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _workouts.length,
            itemBuilder: (context, index) {
              final workout = _workouts[index];
              final trainer = workout['trainer'] as Map<String, dynamic>?;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    workout['title'] ?? 'Untitled Workout',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workout['description'] ?? ''),
                      Text('By: ${trainer?['username'] ?? 'Unknown Trainer'}'),
                      Text('Category: ${workout['category'] ?? 'Mixed'}'),
                      if (workout['duration'] != null)
                        Text('Duration: ${workout['duration']} minutes'),
                    ],
                  ),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _showWorkoutDetails(workout),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showWorkoutDetails(Map<String, dynamic> workout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(workout['title'] ?? 'Workout Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (workout['description'] != null)
                Text('Description: ${workout['description']}'),
              if (workout['category'] != null)
                Text('Category: ${workout['category']}'),
              if (workout['intensity'] != null)
                Text('Intensity: ${workout['intensity']}'),
              if (workout['duration'] != null)
                Text('Duration: ${workout['duration']} minutes'),
              if (workout['caloriesBurned'] != null)
                Text('Calories Burned: ${workout['caloriesBurned']}'),
              const SizedBox(height: 16),
              const Text(
                'Exercises:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(workout['exercises'] as List<dynamic>? ?? []).map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '• ${exercise['name']}: ${exercise['sets']} sets × ${exercise['reps']} reps',
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
