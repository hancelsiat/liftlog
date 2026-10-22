import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';
import '../models/user.dart';
import '../widgets/gym/gym.dart';

class CreateWorkoutTemplateScreen extends StatefulWidget {
  final Workout? workout;

  const CreateWorkoutTemplateScreen({super.key, this.workout});

  @override
  State<CreateWorkoutTemplateScreen> createState() =>
      _CreateWorkoutTemplateScreenState();
}

class _CreateWorkoutTemplateScreenState
    extends State<CreateWorkoutTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();

  String _category = 'strength';
  String _intensity = 'moderate';
  final List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = false;

  final List<String> _categories = [
    'strength',
    'cardio',
    'flexibility',
    'mixed',
  ];
  final List<String> _intensities = ['low', 'moderate', 'high'];

  // Predefined exercises by category
  final Map<String, List<Map<String, dynamic>>> _predefinedExercises = {
    'strength': [
      {
        'name': 'Bench Press',
        'icon': Icons.fitness_center,
        'intensity': 'moderate',
        'defaultSets': 3,
        'defaultReps': 10,
      },
      {
        'name': 'Squats',
        'icon': Icons.accessibility_new,
        'intensity': 'moderate',
        'defaultSets': 4,
        'defaultReps': 12,
      },
      {
        'name': 'Deadlift',
        'icon': Icons.fitness_center,
        'intensity': 'high',
        'defaultSets': 3,
        'defaultReps': 8,
      },
      {
        'name': 'Shoulder Press',
        'icon': Icons.fitness_center,
        'intensity': 'moderate',
        'defaultSets': 3,
        'defaultReps': 10,
      },
      {
        'name': 'Bicep Curls',
        'icon': Icons.fitness_center,
        'intensity': 'low',
        'defaultSets': 3,
        'defaultReps': 12,
      },
      {
        'name': 'Tricep Dips',
        'icon': Icons.fitness_center,
        'intensity': 'low',
        'defaultSets': 3,
        'defaultReps': 12,
      },
      {
        'name': 'Lat Pulldown',
        'icon': Icons.fitness_center,
        'intensity': 'moderate',
        'defaultSets': 3,
        'defaultReps': 10,
      },
      {
        'name': 'Leg Press',
        'icon': Icons.accessibility_new,
        'intensity': 'moderate',
        'defaultSets': 3,
        'defaultReps': 12,
      },
      {
        'name': 'Lunges',
        'icon': Icons.accessibility_new,
        'intensity': 'low',
        'defaultSets': 3,
        'defaultReps': 10,
      },
      {
        'name': 'Pull-ups',
        'icon': Icons.fitness_center,
        'intensity': 'high',
        'defaultSets': 3,
        'defaultReps': 8,
      },
      {
        'name': 'Push-ups',
        'icon': Icons.fitness_center,
        'intensity': 'moderate',
        'defaultSets': 3,
        'defaultReps': 15,
      },
      {
        'name': 'Plank',
        'icon': Icons.self_improvement,
        'intensity': 'low',
        'defaultSets': 3,
        'defaultReps': 1,
      },
    ],
    'cardio': [
      {
        'name': 'Running',
        'icon': Icons.directions_run,
        'intensity': 'moderate',
        'defaultSets': 1,
        'defaultReps': 30,
      },
      {
        'name': 'Cycling',
        'icon': Icons.directions_bike,
        'intensity': 'moderate',
        'defaultSets': 1,
        'defaultReps': 30,
      },
      {
        'name': 'Jump Rope',
        'icon': Icons.sports,
        'intensity': 'high',
        'defaultSets': 3,
        'defaultReps': 100,
      },
      {
        'name': 'Burpees',
        'icon': Icons.fitness_center,
        'intensity': 'high',
        'defaultSets': 3,
        'defaultReps': 15,
      },
      {
        'name': 'Mountain Climbers',
        'icon': Icons.fitness_center,
        'intensity': 'high',
        'defaultSets': 3,
        'defaultReps': 20,
      },
      {
        'name': 'High Knees',
        'icon': Icons.directions_run,
        'intensity': 'moderate',
        'defaultSets': 3,
        'defaultReps': 30,
      },
      {
        'name': 'Jumping Jacks',
        'icon': Icons.sports,
        'intensity': 'low',
        'defaultSets': 3,
        'defaultReps': 30,
      },
    ],
    'flexibility': [
      {
        'name': 'Yoga Flow',
        'icon': Icons.self_improvement,
        'intensity': 'low',
        'defaultSets': 1,
        'defaultReps': 20,
      },
      {
        'name': 'Stretching',
        'icon': Icons.self_improvement,
        'intensity': 'low',
        'defaultSets': 1,
        'defaultReps': 15,
      },
      {
        'name': 'Hamstring Stretch',
        'icon': Icons.self_improvement,
        'intensity': 'low',
        'defaultSets': 2,
        'defaultReps': 1,
      },
      {
        'name': 'Quad Stretch',
        'icon': Icons.self_improvement,
        'intensity': 'low',
        'defaultSets': 2,
        'defaultReps': 1,
      },
      {
        'name': 'Shoulder Stretch',
        'icon': Icons.self_improvement,
        'intensity': 'low',
        'defaultSets': 2,
        'defaultReps': 1,
      },
    ],
    'mixed': [
      {
        'name': 'Circuit Training',
        'icon': Icons.fitness_center,
        'intensity': 'moderate',
        'defaultSets': 3,
        'defaultReps': 12,
      },
      {
        'name': 'HIIT',
        'icon': Icons.sports,
        'intensity': 'high',
        'defaultSets': 4,
        'defaultReps': 30,
      },
      {
        'name': 'CrossFit WOD',
        'icon': Icons.fitness_center,
        'intensity': 'high',
        'defaultSets': 1,
        'defaultReps': 1,
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.workout != null) {
      _titleController.text = widget.workout!.name;
      _descriptionController.text = widget.workout!.description;
      _exercises.addAll(widget.workout!.exercises.map((e) => e.toJson()));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _showExerciseSelector() {
    // Filter exercises based on selected category and intensity
    final filteredExercises = (_predefinedExercises[_category] ?? [])
        .where((exercise) => exercise['intensity'] == _intensity)
        .toList();
    final theme = GymTheme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuthColors.surface,
      barrierColor: AuthColors.barrier,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AuthRadius.dialog),
        ),
        side: BorderSide(color: AuthColors.line),
      ),
      builder: (sheetContext) => Theme(
        data: theme,
        child: _ExercisePickerSheet(
          eyebrow: '${_category.toUpperCase()} / ${_intensity.toUpperCase()}',
          exercises: filteredExercises,
          onPick: (exercise) {
            _addPredefinedExercise(exercise);
            Navigator.pop(sheetContext, true);
          },
          onCustom: () {
            Navigator.pop(sheetContext);
            _addCustomExercise();
          },
        ),
      ),
    );
  }

  Map<String, int> _getSetsAndRepsForIntensity(String intensity) {
    switch (intensity) {
      case 'low':
        return {'sets': 3, 'reps': 15};
      case 'moderate':
        return {'sets': 3, 'reps': 10};
      case 'high':
        return {'sets': 4, 'reps': 8};
      default:
        return {'sets': 3, 'reps': 10};
    }
  }

  void _addPredefinedExercise(Map<String, dynamic> exercise) {
    final setsAndReps = _getSetsAndRepsForIntensity(_intensity);

    setState(() {
      _exercises.add({
        'name': exercise['name'],
        'sets': setsAndReps['sets'],
        'reps': setsAndReps['reps'],
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

  /// Shows the server's error and clears it from the provider so the
  /// Manage Workouts list doesn't switch to its error view.
  void _showSaveError(WorkoutProvider provider) {
    final error = provider.error?.replaceFirst('Exception: ', '');
    provider.clearError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to save workout template. ${error ?? 'Please try again.'}',
        ),
        backgroundColor: AuthColors.danger,
      ),
    );
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
      final workoutProvider = Provider.of<WorkoutProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // The provider catches API errors and returns false (the message is
      // in `workoutProvider.error`), so check the result before showing
      // success.
      if (widget.workout == null) {
        final ok = await workoutProvider.createWorkout(
          _titleController.text.trim(),
          _descriptionController.text.trim(),
          _exercises,
          _category,
          _intensity,
          authProvider.user!.id,
        );
        if (!mounted) return;
        if (!ok) {
          _showSaveError(workoutProvider);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout template created successfully!'),
          ),
        );
      } else {
        final ok = await workoutProvider.updateWorkout(
          widget.workout!.id,
          _titleController.text.trim(),
          _descriptionController.text.trim(),
          _exercises,
        );
        if (!mounted) return;
        if (!ok) {
          _showSaveError(workoutProvider);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout template updated successfully!'),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save workout template. Please try again.'),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user?.role != UserRole.trainer) {
      return const GymScaffold(
        title: 'Workout Template',
        body: GymEmptyState(
          icon: Icons.lock_outline,
          message: 'This screen is only for trainers',
        ),
      );
    }

    final editing = widget.workout != null;

    return GymScaffold(
      eyebrow: editing ? 'Trainer / Edit template' : 'Trainer / New template',
      title: editing ? 'Edit Workout' : 'Create Workout',
      bottomBar: _exercises.isEmpty
          ? null
          : GymBottomBar(
              child: PressableButton(
                label: 'Save Workout Template',
                loading: _isLoading,
                onPressed: _isLoading ? null : _saveWorkoutTemplate,
              ),
            ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GymScaffold.side,
            AuthSpace.xs,
            GymScaffold.side,
            AuthSpace.l,
          ),
          children: [
            const EntranceRise(
              index: 0,
              child: GymSectionLabel(index: 1, label: 'Basic Information'),
            ),
            const SizedBox(height: AuthSpace.s),
            EntranceRise(
              index: 1,
              child: AuthTextField(
                label: 'Workout Title',
                controller: _titleController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a workout title';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AuthSpace.s),
            EntranceRise(
              index: 2,
              child: GymLabeledField(
                label: 'Description',
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: AuthType.input(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: AuthSpace.m),
            EntranceRise(
              index: 3,
              child: GymLabeledField(
                label: 'Category',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in _categories)
                      GymChoiceChip(
                        label: category,
                        selected: _category == category,
                        onTap: () => setState(() => _category = category),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuthSpace.s),
            EntranceRise(
              index: 4,
              child: GymLabeledField(
                label: 'Intensity',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final intensity in _intensities)
                      GymChoiceChip(
                        label: intensity,
                        selected: _intensity == intensity,
                        onTap: () => setState(() => _intensity = intensity),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuthSpace.l),
            EntranceRise(
              index: 5,
              child: GymSectionLabel(
                index: 2,
                label: 'Exercises (${_exercises.length})',
              ),
            ),
            const SizedBox(height: AuthSpace.s),
            if (_exercises.isEmpty)
              const GymEmptyState(
                icon: Icons.fitness_center,
                message:
                    'No exercises added yet.\nTap "Add Exercise" to get started.',
              )
            else
              for (var index = 0; index < _exercises.length; index++)
                Padding(
                  key: ObjectKey(_exercises[index]),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseEditor(
                    index: index,
                    exercise: _exercises[index],
                    onRemove: () => _removeExercise(index),
                    onChanged: (field, value) =>
                        _updateExercise(index, field, value),
                  ),
                ),
            const SizedBox(height: AuthSpace.xs),
            PressableButton(
              label: 'Add Exercise',
              variant: PressableVariant.ghost,
              showArrow: false,
              onPressed: _showExerciseSelector,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExercisePickerSheet extends StatelessWidget {
  const _ExercisePickerSheet({
    required this.eyebrow,
    required this.exercises,
    required this.onPick,
    required this.onCustom,
  });

  final String eyebrow;
  final List<Map<String, dynamic>> exercises;
  final ValueChanged<Map<String, dynamic>> onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AuthColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuthSpace.m,
              AuthSpace.s,
              AuthSpace.s,
              AuthSpace.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: AuthType.mono(color: AuthColors.accent),
                      ),
                      const SizedBox(height: 6),
                      Text('SELECT EXERCISES', style: AuthType.display(28)),
                    ],
                  ),
                ),
                GymIconButton(
                  icon: Icons.close,
                  tooltip: 'Close',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AuthSpace.m,
                AuthSpace.xs,
                AuthSpace.m,
                AuthSpace.l,
              ),
              children: [
                if (exercises.isEmpty)
                  const GymEmptyState(
                    icon: Icons.search_off,
                    message:
                        'No exercises found for the selected category and intensity.',
                  )
                else
                  for (final exercise in exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PickerRow(
                        icon: exercise['icon'] as IconData,
                        title: exercise['name'] as String,
                        subtitle:
                            '${exercise['defaultSets']} sets × ${exercise['defaultReps']} reps',
                        trailing: Icons.add,
                        onTap: () => onPick(exercise),
                      ),
                    ),
                const SizedBox(height: AuthSpace.s),
                // Custom exercise option
                _PickerRow(
                  icon: Icons.edit_outlined,
                  title: 'Custom Exercise',
                  subtitle: 'Create your own exercise',
                  trailing: Icons.arrow_forward,
                  highlighted: true,
                  onTap: onCustom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      highlighted: highlighted,
      semanticLabel: title,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          GymAvatar(icon: icon, size: 40, highlighted: highlighted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: AuthType.display(20)),
                const SizedBox(height: 4),
                Text(subtitle, style: AuthType.mono()),
              ],
            ),
          ),
          Icon(trailing, size: 20, color: AuthColors.accent),
        ],
      ),
    );
  }
}

/// One editable exercise. Fields use `initialValue` + `onChanged` exactly
/// like before, so the parent's `_exercises` list stays the source of truth.
class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    required this.index,
    required this.exercise,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final Map<String, dynamic> exercise;
  final VoidCallback onRemove;
  final void Function(String field, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    final String name = exercise['name'] ?? '';
    return PressableSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: AuthType.mono(color: AuthColors.accent),
                ),
              ),
              Expanded(
                child: Text(
                  (name.isEmpty ? 'Exercise ${index + 1}' : name).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuthType.display(22).copyWith(height: 1),
                ),
              ),
              const SizedBox(width: 8),
              GymIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Remove exercise',
                danger: true,
                onTap: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AuthSpace.s),
          GymLabeledField(
            label: 'Exercise Name',
            child: TextFormField(
              initialValue: exercise['name'],
              style: AuthType.input(),
              onChanged: (value) => onChanged('name', value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter exercise name';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _numberField(
                  label: 'Sets',
                  initial: exercise['sets'],
                  onChanged: (v) => onChanged('sets', int.tryParse(v) ?? 3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  label: 'Reps',
                  initial: exercise['reps'],
                  onChanged: (v) => onChanged('reps', int.tryParse(v) ?? 10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  label: 'Weight (lbs)',
                  initial: exercise['weight'],
                  onChanged: (v) => onChanged('weight', int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GymLabeledField(
            label: 'Notes (optional)',
            child: TextFormField(
              initialValue: exercise['notes'],
              maxLines: 2,
              style: AuthType.input(),
              onChanged: (value) => onChanged('notes', value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required String label,
    required dynamic initial,
    required ValueChanged<String> onChanged,
  }) {
    return GymLabeledField(
      label: label,
      child: TextFormField(
        initialValue: initial.toString(),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: AuthType.input(),
        onChanged: onChanged,
      ),
    );
  }
}
