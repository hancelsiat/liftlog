import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workout.dart';
import '../providers/workout_provider.dart';
import 'create_workout_template_screen.dart';
import 'trainer_deleted_items_screen.dart';
import '../widgets/gym/gym.dart';

class ManageWorkoutsScreen extends StatefulWidget {
  const ManageWorkoutsScreen({super.key});

  @override
  State<ManageWorkoutsScreen> createState() => _ManageWorkoutsScreenState();
}

class _ManageWorkoutsScreenState extends State<ManageWorkoutsScreen> {
  bool _isSelecting = false;
  final Set<String> _selectedWorkouts = {};

  // Search filters what is shown. Selections hidden by a search are kept,
  // but bulk delete only touches selected workouts that are currently visible.
  String _query = '';

  // "Deleting N…" while a bulk delete runs; locks the selection bar.
  String? _bulkProgress;

  bool _matches(Workout w) => matchesSearch(_query, [
    w.name,
    w.description,
    ...w.exercises.map((e) => e.name),
  ]);

  List<Workout> _visible(List<Workout> workouts) =>
      workouts.where(_matches).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WorkoutProvider>(context, listen: false).loadWorkouts();
    });
  }

  /// Opens "Recently deleted"; restored templates show up when coming back.
  void _openDeleted() {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    Navigator.push(
      context,
      GymPageRoute(
        builder: (context) =>
            const TrainerDeletedItemsScreen(kind: DeletedKind.workout),
      ),
    ).then((_) {
      if (mounted) provider.loadWorkouts();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedWorkouts.remove(id)) _selectedWorkouts.add(id);
    });
  }

  void _exitSelection() {
    setState(() {
      _isSelecting = false;
      _selectedWorkouts.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workouts = workoutProvider.workouts;
    final visible = _visible(workouts);
    final busy = _bulkProgress != null;

    return GymScaffold(
      eyebrow: _isSelecting
          ? '${_selectedWorkouts.length} selected'
          : 'Trainer / Templates',
      title: _isSelecting ? 'Select Workouts' : 'Manage Workouts',
      actions: [
        GymIconButton(
          icon: Icons.restore_from_trash_outlined,
          tooltip: 'Recently deleted',
          onTap: busy || _isSelecting ? null : _openDeleted,
        ),
        GymIconButton(
          icon: _isSelecting ? Icons.close : Icons.checklist,
          tooltip: _isSelecting ? 'Exit selection' : 'Select multiple',
          onTap: busy || (workouts.isEmpty && !_isSelecting)
              ? null
              : (_isSelecting
                    ? _exitSelection
                    : () => setState(() => _isSelecting = true)),
        ),
      ],
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(
          GymScaffold.side,
          0,
          GymScaffold.side,
          AuthSpace.xs,
        ),
        child: GymSearchField(
          hint: 'Search name, description or exercise',
          enabled: !busy,
          onChanged: (q) => setState(() => _query = q.trim()),
        ),
      ),
      bottomBar: _isSelecting ? _buildSelectionBar(visible) : null,
      body: GymRefresh(
        onRefresh: () =>
            Provider.of<WorkoutProvider>(context, listen: false).loadWorkouts(),
        child: Builder(
          builder: (context) {
            if (workoutProvider.isLoading) {
              return const GymLoader();
            }
            if (workoutProvider.error != null) {
              return _scrollableMessage(
                GymEmptyState(
                  icon: Icons.error_outline,
                  danger: true,
                  message: 'Error: ${workoutProvider.error}',
                ),
              );
            }
            if (workouts.isEmpty) {
              return _scrollableMessage(
                const GymEmptyState(
                  icon: Icons.fitness_center,
                  message: 'You have not created any workouts yet.',
                ),
              );
            }
            if (visible.isEmpty) {
              return _scrollableMessage(
                GymEmptyState(
                  icon: Icons.search_off,
                  message: 'No workouts match "$_query".',
                ),
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                GymScaffold.side,
                AuthSpace.xs,
                GymScaffold.side,
                AuthSpace.l,
              ),
              itemCount: visible.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final workout = visible[index];
                final isSelected = _selectedWorkouts.contains(workout.id);
                return StaggeredReveal(
                  index: index,
                  child: _WorkoutTemplateCard(
                    index: index,
                    workout: workout,
                    selecting: _isSelecting,
                    selected: isSelected,
                    onToggle: busy ? null : () => _toggleSelection(workout.id),
                    onLongPress: busy
                        ? null
                        : () {
                            setState(() {
                              _isSelecting = true;
                              _selectedWorkouts.add(workout.id);
                            });
                          },
                    onDelete: busy ? null : () => _confirmAndDelete([workout]),
                    onEdit: () {
                      Navigator.push(
                        context,
                        GymPageRoute(
                          builder: (context) =>
                              CreateWorkoutTemplateScreen(workout: workout),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        child,
      ],
    );
  }

  Widget _buildSelectionBar(List<Workout> visible) {
    // Select all / clear act on the workouts the search currently shows.
    final visibleIds = visible.map((w) => w.id).toList();
    final chosen = visibleIds.where(_selectedWorkouts.contains).length;
    return GymSelectionBar(
      selectedCount: chosen,
      selectableCount: visibleIds.length,
      busyLabel: _bulkProgress,
      onSelectAll: () => setState(() => _selectedWorkouts.addAll(visibleIds)),
      onClear: () => setState(() => _selectedWorkouts.removeAll(visibleIds)),
      onClose: _exitSelection,
      actions: [
        GymSmallButton(
          label: chosen > 0 ? 'Delete $chosen' : 'Delete',
          icon: Icons.delete_outline,
          primary: true,
          onTap: chosen > 0 ? () => _deleteSelectedWorkouts(visible) : null,
        ),
      ],
    );
  }

  Future<void> _deleteSelectedWorkouts(List<Workout> visible) async {
    final targets = visible
        .where((w) => _selectedWorkouts.contains(w.id))
        .toList();
    await _confirmAndDelete(targets);
  }

  /// Moves [targets] to "Recently deleted" after a confirmation.
  Future<void> _confirmAndDelete(List<Workout> targets) async {
    if (targets.isEmpty) return;

    final names = targets.take(3).map((w) => '"${w.name}"').join(', ');
    final more = targets.length > 3 ? ' and ${targets.length - 3} more' : '';
    final confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Trainer / Templates',
      title: targets.length == 1
          ? 'Delete Workout'
          : 'Delete ${targets.length} Workouts',
      message:
          'Delete $names$more? Members will no longer see '
          '${targets.length == 1 ? 'it' : 'them'}. You can restore or '
          'permanently delete from Recently deleted.',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: targets.length == 1 ? 'Delete' : 'Delete all',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    final messenger = ScaffoldMessenger.of(context);
    final count = targets.length;

    // The backend deletes all of them in a single request.
    setState(() => _bulkProgress = 'Deleting $count…');
    final ok = await workoutProvider.deleteWorkouts(
      targets.map((w) => w.id).toList(),
    );
    if (!mounted) return;

    if (ok) {
      setState(() {
        _bulkProgress = null;
        _isSelecting = false;
        _selectedWorkouts.clear();
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $count ${count == 1 ? 'workout' : 'workouts'}.',
          ),
        ),
      );
    } else {
      final error = workoutProvider.error;
      // The provider stores the failure as its list error; clear it so the
      // list stays on screen and the selection can be retried.
      workoutProvider.clearError();
      setState(() => _bulkProgress = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete workouts. '
            '${error?.replaceFirst('Exception: ', '') ?? 'Please try again.'}',
          ),
          backgroundColor: AuthColors.danger,
        ),
      );
    }
  }
}

class _WorkoutTemplateCard extends StatelessWidget {
  const _WorkoutTemplateCard({
    required this.index,
    required this.workout,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final Workout workout;
  final bool selecting;
  final bool selected;

  /// Null while a bulk delete runs (selection is locked).
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final VoidCallback onEdit;

  /// Null while a bulk delete runs.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().format(workout.date.toLocal());

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: selecting ? null : onLongPress,
      child: PressableSurface(
        highlighted: selecting && selected,
        semanticLabel: selecting
            ? '${selected ? 'Deselect' : 'Select'} ${workout.name}'
            : workout.name,
        onTap: selecting ? onToggle : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selecting) ...[
              // The 44px check box has a 10px inset; pull it up and left so
              // the 24px box lines up with the card text.
              Transform.translate(
                offset: const Offset(-10, -10),
                child: GymCheckbox(
                  value: selected,
                  semanticLabel: 'Select ${workout.name}',
                  onChanged: onToggle == null ? null : (_) => onToggle!(),
                ),
              ),
            ] else
              SizedBox(
                width: 32,
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: AuthType.mono(color: AuthColors.accent),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name.toUpperCase(),
                    style: AuthType.display(22).copyWith(height: 1),
                  ),
                  if (workout.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      workout.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AuthType.body(size: 13),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'CREATED ${formattedDate.toUpperCase()}',
                    style: AuthType.mono(color: AuthColors.textFaint),
                  ),
                ],
              ),
            ),
            if (!selecting) ...[
              const SizedBox(width: 12),
              GymIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit ${workout.name}',
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              GymIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete ${workout.name}',
                danger: true,
                onTap: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
