import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../utils/app_theme.dart';
import 'workout_session_screen.dart';
import 'workout_detail_screen.dart';
import 'rate_trainer_screen.dart';

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
        _assignedWorkouts = (response as List)
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
      } catch (e) {
        trainer['ratingPercentage'] = 0.0;
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadProfile(context);
      if (mounted) {
        setState(() {
          _user = authProvider.user;
          _loadFuture = _fetchAssignedWorkouts();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting trainer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLeaveTrainerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Another Trainer'),
          content: const Text(
            'Are you sure you want to leave your current trainer?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Leave'),
              onPressed: () {
                Navigator.of(context).pop();
                _leaveTrainer();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveTrainer() async {
    try {
      final String? formerTrainerId = _user?.trainer;
      if (formerTrainerId == null) return;

      await _apiService.leaveTrainer();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadProfile(context);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RateTrainerScreen(trainerId: formerTrainerId),
          ),
        );

        setState(() {
          _user = authProvider.user;
          _assignedWorkouts.clear(); // Clear old workouts
          _loadFuture = _loadTrainers();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error leaving trainer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.trainer != null ? 'My Plan' : 'Choose a Trainer'),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          if (_user?.trainer != null)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _showLeaveTrainerDialog,
              tooltip: 'Choose Another Trainer',
            ),
        ],
        bottom: _user?.trainer != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Assigned'),
                  Tab(text: 'Completed'),
                ],
              )
            : null,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (_user?.trainer != null) {
            final assigned = _assignedWorkouts
                .where((w) => w.completedAt == null)
                .toList();
            final completed = _assignedWorkouts
                .where((w) => w.completedAt != null)
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _loadFuture = _fetchAssignedWorkouts();
                    });
                    await _loadFuture;
                  },
                  child: _buildWorkoutsList(
                    assigned,
                    'Your trainer has not assigned you a plan yet.',
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _loadFuture = _fetchAssignedWorkouts();
                    });
                    await _loadFuture;
                  },
                  child: _buildWorkoutsList(
                    completed,
                    'You have no completed workouts yet.',
                  ),
                ),
              ],
            );
          } else {
            return RefreshIndicator(
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

  Widget _buildTrainersList() {
    if (_trainers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(
            child: Text(
              'No trainers available',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _trainers.length,
      itemBuilder: (context, index) {
        final trainer = _trainers[index];
        final double rating = trainer['ratingPercentage']?.toDouble() ?? 0.0;
        final bool isTopRated = rating >= 80.0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: AppTheme.glassMorphism.copyWith(
            border: isTopRated
                ? Border.all(
                    color: AppTheme.secondaryColor.withOpacity(0.8),
                    width: 1.5,
                  )
                : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: isTopRated
                ? AppTheme.glowShadow
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _selectTrainer(trainer['_id']),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: isTopRated
                            ? AppTheme.secondaryGradient
                            : AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: isTopRated
                            ? [
                                BoxShadow(
                                  color: AppTheme.secondaryColor.withOpacity(
                                    0.4,
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          trainer['username'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  trainer['username'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isTopRated)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.secondaryColor
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: AppTheme.secondaryColor,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Top Rated',
                                        style: TextStyle(
                                          color: AppTheme.secondaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trainer['email'],
                            style: TextStyle(
                              color: AppTheme.textSecondary.withOpacity(0.8),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.thumb_up_alt_outlined,
                                size: 16,
                                color: isTopRated
                                    ? AppTheme.secondaryColor
                                    : AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${rating.toStringAsFixed(1)}% Approval Rating',
                                style: TextStyle(
                                  color: isTopRated
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: isTopRated
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          const SizedBox(height: 100),
          Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        final formattedDate = DateFormat.yMMMd().format(workout.date.toLocal());

        List<String> subtitleParts = ['Assigned on: $formattedDate'];
        if (workout.trainerName != null) {
          subtitleParts.add('by ${workout.trainerName}');
        }
        if (workout.completedAt != null) {
          subtitleParts.add('Completed');
        }

        String subtitleText = subtitleParts.join(' | ');

        return Card(
          color: AppTheme.cardBackground,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              workout.title,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              subtitleText,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: workout.completedAt != null
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(
                    Icons.play_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
            onTap: () {
              if (workout.completedAt != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutDetailScreen(workout: workout),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        WorkoutSessionScreen(workout: workout),
                  ),
                ).then((_) {
                  // Refresh the list after a workout session
                  setState(() {
                    _loadFuture = _fetchAssignedWorkouts();
                  });
                });
              }
            },
          ),
        );
      },
    );
  }
}
