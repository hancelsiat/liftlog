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

  // Predefined exercises by category
  final Map<String, List<Map<String, dynamic>>> _predefinedExercises = {
    'strength': [
      {'name': 'Bench Press', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 10},
      {'name': 'Squats', 'icon': Icons.accessibility_new, 'defaultSets': 4, 'defaultReps': 12},
      {'name': 'Deadlift', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 8},
      {'name': 'Shoulder Press', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 10},
      {'name': 'Bicep Curls', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 12},
      {'name': 'Tricep Dips', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 12},
      {'name': 'Lat Pulldown', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 10},
      {'name': 'Leg Press', 'icon': Icons.accessibility_new, 'defaultSets': 3, 'defaultReps': 12},
      {'name': 'Lunges', 'icon': Icons.accessibility_new, 'defaultSets': 3, 'defaultReps': 10},
      {'name': 'Pull-ups', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 8},
      {'name': 'Push-ups', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 15},
      {'name': 'Plank', 'icon': Icons.self_improvement, 'defaultSets': 3, 'defaultReps': 1},
    ],
    'cardio': [
      {'name': 'Running', 'icon': Icons.directions_run, 'defaultSets': 1, 'defaultReps': 30},
      {'name': 'Cycling', 'icon': Icons.directions_bike, 'defaultSets': 1, 'defaultReps': 30},
      {'name': 'Jump Rope', 'icon': Icons.sports, 'defaultSets': 3, 'defaultReps': 100},
      {'name': 'Burpees', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 15},
      {'name': 'Mountain Climbers', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 20},
      {'name': 'High Knees', 'icon': Icons.directions_run, 'defaultSets': 3, 'defaultReps': 30},
      {'name': 'Jumping Jacks', 'icon': Icons.sports, 'defaultSets': 3, 'defaultReps': 30},
    ],
    'flexibility': [
      {'name': 'Yoga Flow', 'icon': Icons.self_improvement, 'defaultSets': 1, 'defaultReps': 20},
      {'name': 'Stretching', 'icon': Icons.self_improvement, 'defaultSets': 1, 'defaultReps': 15},
      {'name': 'Hamstring Stretch', 'icon': Icons.self_improvement, 'defaultSets': 2, 'defaultReps': 1},
      {'name': 'Quad Stretch', 'icon': Icons.self_improvement, 'defaultSets': 2, 'defaultReps': 1},
      {'name': 'Shoulder Stretch', 'icon': Icons.self_improvement, 'defaultSets': 2, 'defaultReps': 1},
    ],
    'mixed': [
      {'name': 'Circuit Training', 'icon': Icons.fitness_center, 'defaultSets': 3, 'defaultReps': 12},
      {'name': 'HIIT', 'icon': Icons.sports, 'defaultSets': 4, 'defaultReps': 30},
      {'name': 'CrossFit WOD', 'icon': Icons.fitness_center, 'defaultSets': 1, 'defaultReps': 1},
    ],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _showExerciseSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Exercises',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  ..._categories.map((category) {
                    final exercises = _predefinedExercises[category] ?? [];
                    if (exercises.isEmpty) return const SizedBox.shrink();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...exercises.map((exercise) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              exercise['icon'] as IconData,
                              color: Theme.of(context).primaryColor,
                            ),
                            title: Text(exercise['name'] as String),
                            subtitle: Text(
                              '${exercise['defaultSets']} sets × ${exercise['defaultReps']} reps',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () {
                              _addPredefinedExercise(exercise);
                              Navigator.pop(context);
                            },
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),
                  // Custom exercise option
                  Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.edit, color: Colors.blue),
                      title: const Text('Custom Exercise'),
                      subtitle: const Text('Create your own exercise'),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.pop(context);
                        _addCustomExercise();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addPredefinedExercise(Map<String, dynamic> exercise) {
    setState(() {
      _exercises.add({
        'name': exercise['name'],
        'sets': exercise['defaultSets'],
        'reps': exercise['defaultReps'],
        'weight': 0,
        'notes': '',
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${exercise['name']} added!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addCustomExercise() {
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
              const Text(
                'Exercises',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (_exercises.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No exercises added yet.\nTap "Add Exercise" to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _exercises[index]['name'].isEmpty 
                                        ? 'Exercise ${index + 1}' 
                                        : _exercises[index]['name'],
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
              const SizedBox(height: 24),

              // Add Exercise Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _showExerciseSelector,
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  label: const Text(
                    'Add Exercise',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Save Workout Button
              if (_exercises.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveWorkoutTemplate,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 28),
                    label: Text(
                      _isLoading ? 'Saving...' : 'Save Workout Template',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
