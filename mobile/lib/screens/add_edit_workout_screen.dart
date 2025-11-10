import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';

class AddEditWorkoutScreen extends StatefulWidget {
  final Workout? workout;

  const AddEditWorkoutScreen({super.key, this.workout});

  @override
  State<AddEditWorkoutScreen> createState() => _AddEditWorkoutScreenState();
}

class _AddEditWorkoutScreenState extends State<AddEditWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _exercises = [];

  @override
  void initState() {
    super.initState();
    if (widget.workout != null) {
      _nameController.text = widget.workout!.name;
      _descriptionController.text = widget.workout!.description;
      _exercises.addAll(widget.workout!.exercises);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout == null ? 'Add Workout' : 'Edit Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Add Exercise'),
                      onSubmitted: _addExercise,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addExercise(_exercises.isNotEmpty ? _exercises.last : ''),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_exercises[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => setState(() => _exercises.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (workoutProvider.isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _saveWorkout,
                  child: Text(widget.workout == null ? 'Add Workout' : 'Update Workout'),
                ),
              if (workoutProvider.error != null)
                Text(
                  workoutProvider.error!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _addExercise(String exercise) {
    if (exercise.isNotEmpty && !_exercises.contains(exercise)) {
      setState(() => _exercises.add(exercise));
    }
  }

  void _saveWorkout() async {
    if (_formKey.currentState!.validate() && _exercises.isNotEmpty) {
      bool success;
      if (widget.workout == null) {
        success = await Provider.of<WorkoutProvider>(context, listen: false)
            .createWorkout(_nameController.text, _descriptionController.text, _exercises);
      } else {
        success = await Provider.of<WorkoutProvider>(context, listen: false)
            .updateWorkout(widget.workout!.id, _nameController.text, _descriptionController.text, _exercises);
      }

      if (success && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
