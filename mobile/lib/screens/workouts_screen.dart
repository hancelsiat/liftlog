import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../widgets/gym/gym.dart';
import 'workout_session_screen.dart';
import 'workout_detail_screen.dart';
import 'rate_trainer_screen.dart';
import 'trainer_feedback_screen.dart';
import 'chat_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Future<void>? _loadFuture;
  List<Workout> _assignedWorkouts = [];
  List<Map<String, dynamic>> _trainers = [];
  User? _user;

  /// Search text for the "Choose a Trainer" list (filtered on the device).
  String _trainerQuery = '';

  /// Trainers matching the search by username, full name, email or bio.
  List<Map<String, dynamic>> get _visibleTrainers => _trainers
      .where(
        (t) => matchesSearch(_trainerQuery, [
          t['username']?.toString(),
          t['fullName']?.toString(),
          t['email']?.toString(),
          t['bio']?.toString(),
        ]),
      )
      .toList();
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _user = Provider.of<AuthProvider>(context, listen: false).user;
    if (_user != null) {
      _loadFuture = _user!.trainer != null
          ? _fetchAssignedWorkouts()
          : _loadTrainers();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchAssignedWorkouts() async {
    final response = await _apiService.getAssignedWorkouts();
    if (mounted) {
      setState(() {
        _assignedWorkouts = response
            .map((data) => Workout.fromJson(data))
            .toList();
      });
    }
  }

  Future<void> _loadTrainers() async {
    final trainersData = await _apiService.getAvailableTrainers();
    List<Map<String, dynamic>> trainers = [];
    for (var trainer in trainersData) {
      try {
        final ratingStats = await _apiService.getTrainerRating(trainer['_id']);
        trainer['ratingPercentage'] = ratingStats.ratingPercentage;
        trainer['totalRatings'] = ratingStats.totalRatings;
      } catch (e) {
        trainer['ratingPercentage'] = 0.0;
        trainer['totalRatings'] = 0;
      }
      trainers.add(trainer);
    }
    if (mounted) {
      // Sort trainers by rating descending
      trainers.sort(
        (a, b) => (b['ratingPercentage'] ?? 0.0).compareTo(
          a['ratingPercentage'] ?? 0.0,
        ),
      );
      setState(() {
        _trainers = trainers;
      });
    }
  }

  Future<void> _selectTrainer(String trainerId) async {
    try {
      await _apiService.selectTrainer(trainerId);
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadProfile(context);
      if (mounted) {
        setState(() {
          _user = authProvider.user;
          _trainerQuery = '';
          _loadFuture = _fetchAssignedWorkouts();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting trainer: $e'),
          backgroundColor: AuthColors.danger,
        ),
      );
    }
  }

  /// Opens the anonymous feedback screen for a trainer. If the member taps
  /// "Choose this Trainer" there, the trainer is selected.
  Future<void> _openTrainerFeedback(Map<String, dynamic> trainer) async {
    final bool? choose = await Navigator.of(context).push<bool>(
      GymPageRoute(
        builder: (context) => TrainerFeedbackScreen(
          trainerId: trainer['_id'].toString(),
          trainerName: trainer['username']?.toString() ?? 'Trainer',
          trainerBio: trainer['bio']?.toString(),
        ),
      ),
    );
    if (choose == true && mounted) {
      await _confirmSelectTrainer(trainer);
    }
  }

  /// Asks for confirmation before choosing a trainer.
  Future<void> _confirmSelectTrainer(Map<String, dynamic> trainer) async {
    final String name = trainer['username']?.toString() ?? 'this trainer';
    final bool? confirmed = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Trainer',
      title: 'Choose Trainer',
      message: 'Do you want to choose $name as your trainer?',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        AuthDialogAction(
          label: 'Choose',
          primary: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed == true && mounted) {
      await _selectTrainer(trainer['_id'].toString());
    }
  }

  /// Opens the realtime chat with the member's current trainer.
  /// The profile only stores the trainer's id, so the trainer's
  /// username is looked up from the available trainers list.
  Future<void> _openTrainerChat() async {
    final String? trainerId = _user?.trainer;
    if (trainerId == null) return;

    String trainerName = 'Trainer';
    String trainerEmail = '';
    try {
      final trainers = await _apiService.getAvailableTrainers();
      final match = trainers.firstWhere(
        (t) => t['_id']?.toString() == trainerId,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        trainerName = match['username']?.toString() ?? trainerName;
        trainerEmail = match['email']?.toString() ?? '';
      }
    } catch (_) {
      // Fall back to a generic name; chat still works with the id.
    }

    if (!mounted) return;
    Navigator.of(context).push(
      GymPageRoute(
        builder: (context) => ChatScreen(
          partner: User(
            id: trainerId,
            email: trainerEmail,
            username: trainerName,
            name: trainerName,
            role: UserRole.trainer,
          ),
        ),
      ),
    );
  }

  void _showLeaveTrainerDialog() {
    showAuthDialog<void>(
      context: context,
      eyebrow: 'Trainer',
      title: 'Choose Another Trainer',
      message: 'Are you sure you want to leave your current trainer?',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () {
            Navigator.of(dialogContext).pop();
          },
        ),
        AuthDialogAction(
          label: 'Leave',
          primary: true,
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _leaveTrainer();
          },
        ),
      ],
    );
  }

  Future<void> _leaveTrainer() async {
    try {
      final String? formerTrainerId = _user?.trainer;
      if (formerTrainerId == null) return;

      await _apiService.leaveTrainer();
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadProfile(context);

      if (mounted) {
        Navigator.of(context).push(
          GymPageRoute(
            builder: (context) => RateTrainerScreen(trainerId: formerTrainerId),
          ),
        );

        setState(() {
          _user = authProvider.user;
          _assignedWorkouts.clear(); // Clear old workouts
          _trainerQuery = ''; // The search box is rebuilt empty
          _loadFuture = _loadTrainers();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error leaving trainer: $e'),
          backgroundColor: AuthColors.danger,
        ),
      );
    }
  }

  Future<void> _refreshAssigned() async {
    setState(() {
      _loadFuture = _fetchAssignedWorkouts();
    });
    await _loadFuture;
  }

  @override
  Widget build(BuildContext context) {
    final hasTrainer = _user?.trainer != null;
    return GymScaffold(
      eyebrow: hasTrainer ? 'Member / Training' : 'Member / Step 01',
      title: hasTrainer ? 'My Plan' : 'Choose a Trainer',
      actions: [
        if (hasTrainer)
          GymIconButton(
            icon: Icons.chat_bubble_outline,
            onTap: _openTrainerChat,
            tooltip: 'Chat with Trainer',
          ),
        if (hasTrainer)
          GymIconButton(
            icon: Icons.swap_horiz,
            onTap: _showLeaveTrainerDialog,
            tooltip: 'Choose Another Trainer',
          ),
      ],
      bottom: hasTrainer
          ? GymTabBar(
              controller: _tabController!,
              tabs: const ['Assigned', 'Completed'],
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                GymScaffold.side,
                0,
                GymScaffold.side,
                AuthSpace.xs,
              ),
              child: GymSearchField(
                hint: 'Search trainer name, email or bio',
                onChanged: (q) => setState(() => _trainerQuery = q.trim()),
              ),
            ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const GymLoader();
          }
          if (snapshot.hasError) {
            return GymRefresh(
              onRefresh: () async {
                setState(() {
                  _loadFuture = hasTrainer
                      ? _fetchAssignedWorkouts()
                      : _loadTrainers();
                });
                await _loadFuture?.catchError((_) {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                  GymEmptyState(
                    icon: Icons.error_outline,
                    danger: true,
                    message: 'Error: ${snapshot.error}',
                  ),
                ],
              ),
            );
          }

          if (hasTrainer) {
            final assigned = _assignedWorkouts
                .where((w) => w.completedAt == null)
                .toList();
            final completed = _assignedWorkouts
                .where((w) => w.completedAt != null)
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                GymRefresh(
                  onRefresh: _refreshAssigned,
                  child: _buildWorkoutsList(
                    assigned,
                    'Your trainer has not assigned you a plan yet.',
                  ),
                ),
                GymRefresh(
                  onRefresh: _refreshAssigned,
                  child: _buildWorkoutsList(
                    completed,
                    'You have no completed workouts yet.',
                  ),
                ),
              ],
            );
          } else {
            return GymRefresh(
              onRefresh: () async {
                setState(() {
                  _loadFuture = _loadTrainers();
                });
                await _loadFuture;
              },
              child: _buildTrainersList(),
            );
          }
        },
      ),
    );
  }

  static const EdgeInsets _listPadding = EdgeInsets.fromLTRB(
    GymScaffold.side,
    AuthSpace.s,
    GymScaffold.side,
    AuthSpace.l,
  );

  Widget _buildTrainersList() {
    if (_trainers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          GymEmptyState(
            icon: Icons.person_search_outlined,
            message: 'No trainers available',
          ),
        ],
      );
    }

    final visible = _visibleTrainers;
    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          GymEmptyState(
            icon: Icons.search_off,
            message: 'No trainers match "$_trainerQuery".',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _listPadding,
      itemCount: visible.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trainer = visible[index];
        return StaggeredReveal(
          index: index,
          child: _TrainerCard(
            trainer: trainer,
            onOpen: () => _openTrainerFeedback(trainer),
            onChoose: () => _confirmSelectTrainer(trainer),
          ),
        );
      },
    );
  }

  Widget _buildWorkoutsList(List<Workout> workouts, String emptyMessage) {
    if (workouts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GymEmptyState(icon: Icons.fitness_center, message: emptyMessage),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _listPadding,
      itemCount: workouts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final workout = workouts[index];
        final formattedDate = DateFormat.yMMMd().format(workout.date.toLocal());
        final done = workout.completedAt != null;

        List<String> subtitleParts = ['Assigned on: $formattedDate'];
        if (workout.trainerName != null) {
          subtitleParts.add('by ${workout.trainerName}');
        }
        if (done) {
          subtitleParts.add('Completed');
        }

        String subtitleText = subtitleParts.join(' | ');

        return StaggeredReveal(
          index: index,
          child: PressableSurface(
            semanticLabel: '${workout.title}. $subtitleText',
            padding: const EdgeInsets.fromLTRB(AuthSpace.s, 14, 12, 14),
            onTap: () {
              if (done) {
                Navigator.push(
                  context,
                  GymPageRoute(
                    builder: (context) => WorkoutDetailScreen(workout: workout),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  GymPageRoute(
                    builder: (context) =>
                        WorkoutSessionScreen(workout: workout),
                  ),
                ).then((_) {
                  // Refresh the list after a workout session
                  if (!mounted) return;
                  setState(() {
                    _loadFuture = _fetchAssignedWorkouts();
                  });
                });
              }
            },
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
                      Text(subtitleText, style: AuthType.body(size: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                done
                    ? const GymAvatar(
                        icon: Icons.check,
                        size: 36,
                        highlighted: true,
                      )
                    : const GymAvatar(icon: Icons.play_arrow, size: 36),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({
    required this.trainer,
    required this.onOpen,
    required this.onChoose,
  });

  final Map<String, dynamic> trainer;
  final VoidCallback onOpen;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final double rating = trainer['ratingPercentage']?.toDouble() ?? 0.0;
    final bool isTopRated = rating >= 80.0;
    final String username = trainer['username']?.toString() ?? 'Trainer';
    final String fullName = trainer['fullName']?.toString().trim() ?? '';
    final String email = trainer['email']?.toString() ?? '';

    return PressableSurface(
      onTap: onOpen,
      highlighted: isTopRated,
      semanticLabel: '$username, ${rating.toStringAsFixed(1)}% approval',
      padding: const EdgeInsets.all(AuthSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GymAvatar(text: username, size: 52, highlighted: isTopRated),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            username.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuthType.display(26).copyWith(height: 1),
                          ),
                        ),
                        if (isTopRated)
                          const GymTag(
                            label: 'Top Rated',
                            icon: Icons.star_rounded,
                            color: AuthColors.accent,
                          ),
                      ],
                    ),
                    if (fullName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuthType.body(
                          size: 14,
                          color: AuthColors.textPrimary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuthType.body(size: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuthSpace.s),
          Row(
            children: [
              Text(
                '${rating.toStringAsFixed(1)}%',
                style: AuthType.display(24).copyWith(
                  color: isTopRated
                      ? AuthColors.accent
                      : AuthColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text('Approval Rating'.toUpperCase(), style: AuthType.mono()),
            ],
          ),
          const SizedBox(height: 8),
          GymMeter(
            value: rating / 100,
            color: isTopRated ? AuthColors.accent : AuthColors.textMuted,
          ),
          const SizedBox(height: AuthSpace.s),
          Row(
            children: [
              Expanded(
                child: GymSmallButton(
                  icon: Icons.reviews_outlined,
                  label: 'Feedbacks (${trainer['totalRatings'] ?? 0})',
                  onTap: onOpen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GymSmallButton(
                  icon: Icons.check,
                  label: 'Choose',
                  primary: true,
                  onTap: onChoose,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
