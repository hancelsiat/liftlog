import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../widgets/gym/gym.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().format(workout.date.toLocal());
    final completedDate = workout.completedAt != null
        ? DateFormat.yMMMd().format(workout.completedAt!.toLocal())
        : 'Not completed';

    return GymScaffold(
      eyebrow: workout.completedAt != null ? 'Workout / Done' : 'Workout',
      title: workout.title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          GymScaffold.side,
          AuthSpace.xs,
          GymScaffold.side,
          AuthSpace.l,
        ),
        children: [
          if (workout.description.isNotEmpty) ...[
            EntranceRise(
              index: 0,
              child: Text(workout.description, style: AuthType.body(size: 16)),
            ),
            const SizedBox(height: AuthSpace.m),
          ],
          EntranceRise(
            index: 1,
            child: PressableSurface(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Assigned on',
                    value: formattedDate,
                  ),
                  if (workout.trainerName != null)
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: 'Assigned by',
                      value: workout.trainerName!,
                    ),
                  if (workout.completedAt != null)
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Completed on',
                      value: completedDate,
                      accent: true,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AuthSpace.l),
          EntranceRise(
            index: 2,
            child: GymSectionLabel(
              index: 1,
              label: 'Exercises (${workout.exercises.length})',
            ),
          ),
          const SizedBox(height: AuthSpace.s),
          if (workout.exercises.isEmpty)
            const GymEmptyState(
              icon: Icons.fitness_center,
              message: 'No exercises in this workout.',
            )
          else
            for (var i = 0; i < workout.exercises.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              StaggeredReveal(
                index: i,
                child: _ExerciseCard(index: i, exercise: workout.exercises[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: accent ? AuthColors.accent : AuthColors.textMuted,
          ),
          const SizedBox(width: 12),
          Text(label.toUpperCase(), style: AuthType.label()),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AuthType.body(color: AuthColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.index, required this.exercise});

  final int index;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                (index + 1).toString().padLeft(2, '0'),
                style: AuthType.mono(color: AuthColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise.name.toUpperCase(),
                  style: AuthType.display(22).copyWith(height: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuthSpace.s),
          Row(
            children: [
              Expanded(child: _Stat('Sets', exercise.sets.toString())),
              Expanded(child: _Stat('Reps', exercise.reps.toString())),
              Expanded(child: _Stat('Weight', '${exercise.weight} lbs')),
            ],
          ),
          if (exercise.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Notes: ${exercise.notes}', style: AuthType.body(size: 14)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AuthType.mono()),
        const SizedBox(height: 4),
        Text(value, style: AuthType.display(26)),
      ],
    );
  }
}
