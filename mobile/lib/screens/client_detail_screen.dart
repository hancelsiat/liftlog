import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/gym/gym.dart';
import 'assign_workout_screen.dart';
import 'create_workout_template_screen.dart';
import 'workout_detail_screen.dart';
import 'chat_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final User client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Workout>> _progressFuture;
  final ApiService _apiService = ApiService();
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _progressFuture = _fetchProgress();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<List<Workout>> _fetchProgress() async {
    final response = await _apiService.getClientProgress(widget.client.id);
    return response.map((data) => Workout.fromJson(data)).toList();
  }

  void _removeClient() async {
    try {
      await _apiService.removeClient(widget.client.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client removed successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove client. Please try again.'),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    }
  }

  void _deleteWorkout(String workoutId) async {
    try {
      await _apiService.deleteWorkout(workoutId);
      if (!mounted) return;
      setState(() {
        _progressFuture = _fetchProgress();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete workout. Please try again.'),
            backgroundColor: AuthColors.danger,
          ),
        );
      }
    }
  }

  /// The member loses this workout from their plan, and it can't be
  /// restored, so ask first.
  Future<void> _confirmDeleteWorkout(Workout workout) async {
    final bool? confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Client / Plan',
      title: 'Delete Workout',
      message:
          'Remove "${workout.title}" from ${widget.client.username}\'s plan? '
          'This cannot be undone.',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: 'Delete',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed == true && mounted) _deleteWorkout(workout.id);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _progressFuture = _fetchProgress();
    });
  }

  Future<void> _confirmRemoveClient() async {
    final bool? confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Client',
      title: 'Remove Client',
      message: 'Are you sure you want to remove this client?',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: 'Remove',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed == true && mounted) _removeClient();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentTrainerId = authProvider.user?.id;
    final bool hasLeft = widget.client.trainer != currentTrainerId;

    return GymScaffold(
      eyebrow: hasLeft ? 'Client / Left' : 'Client',
      title: widget.client.username,
      actions: [
        GymIconButton(
          icon: Icons.chat_bubble_outline,
          tooltip: 'Message ${widget.client.username}',
          onTap: () {
            Navigator.push(
              context,
              GymPageRoute(
                builder: (context) => ChatScreen(partner: widget.client),
              ),
            );
          },
        ),
        GymIconButton(
          icon: Icons.person_remove_outlined,
          tooltip: 'Remove client',
          danger: true,
          onTap: _confirmRemoveClient,
        ),
      ],
      bottom: GymTabBar(
        controller: _tabController!,
        tabs: const ['Assigned', 'Completed'],
      ),
      bottomBar: hasLeft
          ? null
          : GymBottomBar(
              child: PressableButton(
                label: 'Assign Workout',
                onPressed: () {
                  Navigator.push(
                    context,
                    GymPageRoute(
                      builder: (context) =>
                          AssignWorkoutScreen(memberId: widget.client.id),
                    ),
                  ).then((_) => _refresh());
                },
              ),
            ),
      body: FutureBuilder<List<Workout>>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const GymLoader();
          }
          if (snapshot.hasError) {
            return Center(
              child: GymEmptyState(
                icon: Icons.error_outline,
                danger: true,
                message: 'Error: ${snapshot.error}',
                action: SizedBox(
                  width: 160,
                  child: PressableButton(
                    label: 'Retry',
                    height: 48,
                    showArrow: false,
                    onPressed: _refresh,
                  ),
                ),
              ),
            );
          }
          final all = snapshot.data ?? const <Workout>[];
          final assigned = all.where((w) => w.completedAt == null).toList();
          final completed = all.where((w) => w.completedAt != null).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildWorkoutsList(
                assigned,
                'No workouts assigned yet.',
                currentTrainerId,
                hasLeft,
              ),
              _buildWorkoutsList(
                completed,
                'No completed workouts yet.',
                currentTrainerId,
                hasLeft,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkoutsList(
    List<Workout> workouts,
    String emptyMessage,
    String? currentTrainerId,
    bool hasLeft,
  ) {
    if (workouts.isEmpty) {
      return Center(
        child: GymEmptyState(icon: Icons.fitness_center, message: emptyMessage),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        AuthSpace.s,
        GymScaffold.side,
        AuthSpace.l,
      ),
      itemCount: workouts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final workout = workouts[index];
        final formattedDate = DateFormat.yMMMd().format(workout.date.toLocal());
        final bool isOwner = workout.trainerId == currentTrainerId;
        final bool done = workout.completedAt != null;

        return StaggeredReveal(
          index: index,
          child: PressableSurface(
            semanticLabel: done ? 'Open ${workout.title}' : null,
            onTap: done
                ? () {
                    Navigator.push(
                      context,
                      GymPageRoute(
                        builder: (context) =>
                            WorkoutDetailScreen(workout: workout),
                      ),
                    );
                  }
                : null,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: AuthType.mono(
                      color: done ? AuthColors.textFaint : AuthColors.accent,
                    ),
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
                      const SizedBox(height: 6),
                      Text(
                        workout.trainerName != null
                            ? 'Assigned on: $formattedDate | by ${workout.trainerName}'
                            : 'Assigned on: $formattedDate',
                        style: AuthType.body(size: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (done)
                  const GymAvatar(
                    icon: Icons.check,
                    size: 36,
                    highlighted: true,
                  )
                else if (isOwner && !hasLeft) ...[
                  GymIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit ${workout.title}',
                    onTap: () {
                      Navigator.push(
                        context,
                        GymPageRoute(
                          builder: (context) =>
                              CreateWorkoutTemplateScreen(workout: workout),
                        ),
                      ).then((_) => _refresh());
                    },
                  ),
                  const SizedBox(width: 8),
                  GymIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete ${workout.title}',
                    danger: true,
                    onTap: () => _confirmDeleteWorkout(workout),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
