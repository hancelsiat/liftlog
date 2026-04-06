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
  bool _isSelecting = false;
  Set<String> _selectedWorkouts = {};

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
    return FutureBuilder<List<Workout>>(
      future: _workoutsFuture,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isSelecting ? 'Select Workouts' : 'Manage Workouts'),
            actions: [
              if (_isSelecting)
                IconButton(
                  icon: Icon(Icons.select_all),
                  onPressed: () {
                    setState(() {
                      if (snapshot.hasData) {
                        if (_selectedWorkouts.length == snapshot.data!.length) {
                          _selectedWorkouts.clear();
                        } else {
                          _selectedWorkouts = snapshot.data!.map((w) => w.id).toSet();
                        }
                      }
                    });
                  },
                ),
              if (_isSelecting)
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: _deleteSelectedWorkouts,
                ),
              IconButton(
                icon: Icon(_isSelecting ? Icons.close : Icons.check_box_outline_blank),
                onPressed: () {
                  setState(() {
                    _isSelecting = !_isSelecting;
                    _selectedWorkouts.clear();
                  });
                },
              ),
            ],
          ),
          body: Builder(
            builder: (context) {
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
                  final isSelected = _selectedWorkouts.contains(workout.id);
                  return ListTile(
                    leading: _isSelecting ? Checkbox(value: isSelected, onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedWorkouts.add(workout.id);
                        } else {
                          _selectedWorkouts.remove(workout.id);
                        }
                      });
                    }) : null,
                    title: Text(workout.name),
                    subtitle: Text(workout.description),
                    onTap: () {
                      if (_isSelecting) {
                        setState(() {
                          if (isSelected) {
                            _selectedWorkouts.remove(workout.id);
                          } else {
                            _selectedWorkouts.add(workout.id);
                          }
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateWorkoutTemplateScreen(workout: workout),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      setState(() {
                        _isSelecting = true;
                        _selectedWorkouts.add(workout.id);
                      });
                    },
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
                      ],
                    ),
                  );
                },
              );
            }
          }),
        );
      },
    );
  }

  void _deleteSelectedWorkouts() async {
    if (_selectedWorkouts.isEmpty) return;

    try {
      await _apiService.deleteWorkouts(_selectedWorkouts.toList());
      setState(() {
        _workoutsFuture = _fetchTrainerWorkouts();
        _isSelecting = false;
        _selectedWorkouts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workouts deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete workouts: $e')),
      );
    }
  }
}
