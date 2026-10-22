import 'package:flutter/material.dart';
import 'package:liftlog_mobile/models/workout.dart';
import 'package:liftlog_mobile/services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/gym/gym.dart';

class AssignWorkoutScreen extends StatefulWidget {
  final String memberId;
  const AssignWorkoutScreen({super.key, required this.memberId});

  @override
  State<AssignWorkoutScreen> createState() => _AssignWorkoutScreenState();
}

class _AssignWorkoutScreenState extends State<AssignWorkoutScreen> {
  late Future<List<Workout>> _workoutsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _workoutsFuture = _fetchWorkoutTemplates();
  }

  Future<List<Workout>> _fetchWorkoutTemplates() async {
    final trainerId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.id;
    final response = await _apiService.getTrainerWorkouts();
    return response.where((workout) => workout.trainerId == trainerId).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _workoutsFuture = _fetchWorkoutTemplates();
    });
    try {
      await _workoutsFuture;
    } catch (_) {
      // The FutureBuilder shows the error.
    }
  }

  /// Pullable wrapper for the error and empty messages.
  Widget _scrollableMessage(Widget child) {
    return GymRefresh(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          child,
        ],
      ),
    );
  }

  /// Id of the workout being assigned, so its row shows a loader and the
  /// rest are locked until the request finishes.
  String? _assigningId;

  void _assignWorkout(String workoutId) async {
    if (_assigningId != null) return;
    setState(() => _assigningId = workoutId);
    try {
      await _apiService.assignWorkoutToClient(widget.memberId, workoutId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout successfully assigned to the client!'),
          ),
        );
        Navigator.of(context).pop(); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _assigningId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not assign the workout. Please try again.'),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Trainer / Assign',
      title: 'Assign Workout',
      body: FutureBuilder<List<Workout>>(
        future: _workoutsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const GymLoader();
          }
          if (snapshot.hasError) {
            return _scrollableMessage(
              GymEmptyState(
                icon: Icons.error_outline,
                danger: true,
                message: 'Error: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _scrollableMessage(
              const GymEmptyState(
                icon: Icons.fitness_center,
                message: 'You have no workout templates.',
              ),
            );
          }

          final workouts = snapshot.data!;
          return GymRefresh(
            onRefresh: _refresh,
            child: _templateList(workouts),
          );
        },
      ),
    );
  }

  Widget _templateList(List<Workout> workouts) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        AuthSpace.xs,
        GymScaffold.side,
        AuthSpace.l,
      ),
      itemCount: workouts.length + 1,
      separatorBuilder: (context, index) =>
          SizedBox(height: index == 0 ? AuthSpace.s : 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const GymSectionLabel(
            index: 1,
            label: 'Tap a template to assign',
          );
        }
        final i = index - 1;
        final workout = workouts[i];
        final busy = _assigningId == workout.id;
        final locked = _assigningId != null;
        return StaggeredReveal(
          index: i,
          child: PressableSurface(
            highlighted: busy,
            semanticLabel: 'Assign ${workout.title}',
            onTap: locked ? null : () => _assignWorkout(workout.id),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    (i + 1).toString().padLeft(2, '0'),
                    style: AuthType.mono(color: AuthColors.accent),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.title.toUpperCase(),
                        style: AuthType.display(22).copyWith(height: 1),
                      ),
                      if (workout.exercises.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${workout.exercises.length} '
                          '${workout.exercises.length == 1 ? 'exercise' : 'exercises'}',
                          style: AuthType.body(size: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 28,
                  child: busy
                      ? const BarLoader(color: AuthColors.accent)
                      : Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: locked
                              ? AuthColors.textFaint
                              : AuthColors.textMuted,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
