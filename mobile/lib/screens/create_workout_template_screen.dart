import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/workout.dart';
import '../models/user.dart';
import '../models/exercise.dart';

class CreateWorkoutTemplateScreen extends StatefulWidget {
  const CreateWorkoutTemplateScreen({super.key});

  @override
  State<CreateWorkoutTemplateScreen> createState() => _CreateWorkoutTemplateScreenState();
}

class _CreateWorkoutTemplateScreenState extends State<CreateWorkoutTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();

  String _category = 'strength';
  String _intensity = 'moderate';
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = false;

  final List<String> _categories = ['strength', 'cardio', 'flexibility', 'mixed'];
  final List<String> _intensities = ['low', 'moderate', 'high'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _addExercise() {
    setState(() {
      _exercises.add({
        'name': '',
        'sets': 3,
        'reps': 10,
        'weight': 0,
        'notes': '',
      });
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _updateExercise(int index, String field, dynamic value) {
    setState(() {
      _exercises[index][field] = value;
    });
  }

  Future<void> _saveWorkoutTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      await apiService.createWorkoutTemplate(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        exercises: _exercises,
        category: _category,
        intensity: _intensity,
        duration: int.tryParse(_durationController.text),
        caloriesBurned: int.tryParse(_caloriesController.text),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout template created successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating workout template: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user?.role != UserRole.trainer) {
      return const Scaffold(
        body: Center(child: Text('This screen is only for trainers')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Workout Template'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveWorkoutTemplate,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Workout Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a workout title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _category = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _intensity,
                      decoration: const InputDecoration(
                        labelText: 'Intensity',
                        border: OutlineInputBorder(),
                      ),
                      items: _intensities.map((intensity) {
                        return DropdownMenuItem(
                          value: intensity,
                          child: Text(intensity.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _intensity = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesController,
                      decoration: const InputDecoration(
                        labelText: 'Calories Burned',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Exercises Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Exercises',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_exercises.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No exercises added yet.\nTap "Add Exercise" to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Exercise ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeExercise(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _exercises[index]['name'],
                              decoration: const InputDecoration(
                                labelText: 'Exercise Name',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => _updateExercise(index, 'name', value),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter exercise name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _exercises[index]['sets'].toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Sets',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => _updateExercise(index, 'sets', int.tryParse(value) ?? 3),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _exercises[index]['reps'].toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Reps',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => _updateExercise(index, 'reps', int.tryParse(value) ?? 10),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _exercises[index]['weight'].toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Weight (lbs)',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => _updateExercise(index, 'weight', int.tryParse(value) ?? 0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _exercises[index]['notes'],
                              decoration: const InputDecoration(
                                labelText: 'Notes (optional)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                              onChanged: (value) => _updateExercise(index, 'notes', value),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
