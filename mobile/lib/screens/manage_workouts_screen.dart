import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';
import 'create_workout_template_screen.dart';

class ManageWorkoutsScreen extends StatefulWidget {
  const ManageWorkoutsScreen({super.key});

  @override
  _ManageWorkoutsScreenState createState() => _ManageWorkoutsScreenState();
}

class _ManageWorkoutsScreenState extends State<ManageWorkoutsScreen> {
  bool _isSelecting = false;
  final Set<String> _selectedWorkouts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WorkoutProvider>(context, listen: false).loadWorkouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workouts = workoutProvider.workouts;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelecting ? 'Select Workouts' : 'Manage Workouts'),
        actions: [
          if (_isSelecting)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  if (_selectedWorkouts.length == workouts.length) {
                    _selectedWorkouts.clear();
                  } else {
                    _selectedWorkouts.addAll(workouts.map((w) => w.id));
                  }
                });
              },
            ),
          if (_isSelecting)
            IconButton(
              icon: const Icon(Icons.delete),
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
      body: Builder(builder: (context) {
        if (workoutProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (workoutProvider.error != null) {
          return Center(child: Text('Error: ${workoutProvider.error}'));
        } else if (workouts.isEmpty) {
          return const Center(child: Text('You have not created any workouts yet.'));
        } else {
          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              final isSelected = _selectedWorkouts.contains(workout.id);
              return ListTile(
                leading: _isSelecting
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedWorkouts.add(workout.id);
                            } else {
                              _selectedWorkouts.remove(workout.id);
                            }
                          });
                        },
                      )
                    : null,
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
  }

  void _deleteSelectedWorkouts() async {
    if (_selectedWorkouts.isEmpty) return;

    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final List<String> workoutsToDelete = _selectedWorkouts.toList();

    try {
      await workoutProvider.deleteWorkouts(workoutsToDelete);
      setState(() {
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
