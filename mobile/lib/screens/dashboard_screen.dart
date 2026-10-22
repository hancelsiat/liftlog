import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../widgets/auth/barbell_indicator.dart';
import '../widgets/auth/grain_background.dart';
import '../widgets/gym/gym.dart';
import 'login_screen.dart';
import 'workouts_screen.dart';
import 'progress_screen.dart';
import 'training_videos_screen.dart';
import 'video_upload_screen.dart';
import 'trainer_videos_screen.dart';
import 'create_workout_template_screen.dart';
import 'manage_workouts_screen.dart';
import 'admin_users_screen.dart';
import 'admin_reset_requests_screen.dart';
import 'admin_content_moderation_screen.dart';
import 'trainer_clients_screen.dart';
import 'trainer_ratings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.loadProfile(context);
    } catch (e) {
      // If profile loading fails due to invalid token, logout and redirect to login
      if (e.toString().contains('Authentication required')) {
        await authProvider.logout();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _open(Widget screen) {
    Navigator.push(context, GymPageRoute(builder: (context) => screen));
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await showAuthDialog<bool>(
      context: context,
      eyebrow: 'Leaving',
      title: 'Exit App',
      message: 'Do you want to exit the app?',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AuthDialogAction(
          label: 'Exit',
          primary: true,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    );
    return shouldExit ?? false;
  }

  void _showLogoutDialog(AuthProvider authProvider) {
    showAuthDialog<void>(
      context: context,
      eyebrow: 'Session',
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      actions: (dialogContext) => [
        AuthDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(dialogContext),
        ),
        AuthDialogAction(
          label: 'Logout',
          primary: true,
          onPressed: () {
            authProvider.logout();
            Navigator.of(dialogContext).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _loadingScaffold() {
    return const GrainBackground(
      child: Scaffold(backgroundColor: Colors.transparent, body: GymLoader()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading) return _loadingScaffold();

    // Check if user is null
    if (user == null) {
      // Redirect to login if no user is logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
      return _loadingScaffold();
    }

    // Prevent back button from logging out; confirm exit instead.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _confirmExit,
      child: GymScaffold(
        showBack: false,
        leading: const _LogoMark(),
        eyebrow: 'LiftLog / ${_getRoleText(user.role)}',
        title: 'Dashboard',
        actions: [
          GymIconButton(
            icon: Icons.logout,
            tooltip: 'Logout',
            danger: true,
            onTap: () => _showLogoutDialog(authProvider),
          ),
        ],
        // Pull down to reload the profile (e.g. trainer approval status).
        body: GymRefresh(
          onRefresh: _loadUserProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              GymScaffold.side,
              AuthSpace.xs,
              GymScaffold.side,
              AuthSpace.l,
            ),
            children: [
              EntranceRise(index: 0, child: _WelcomeCard(user: user)),
              const SizedBox(height: AuthSpace.l),
              // Role-based Dashboard
              ..._tilesFor(user.role),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tilesFor(UserRole role) {
    final List<_TileData> tiles;
    final String section;
    switch (role) {
      case UserRole.member:
        section = 'Your Fitness Journey';
        tiles = [
          _TileData(
            'Workouts',
            'Browse and track your workouts',
            Icons.fitness_center,
            () => _open(const WorkoutsScreen()),
          ),
          _TileData(
            'Track Progress',
            'Monitor your fitness journey',
            Icons.show_chart,
            () => _open(const ProgressScreen()),
          ),
          _TileData(
            'Training Videos',
            'Learn from expert trainers',
            Icons.video_library_outlined,
            () => _open(const TrainingVideosScreen()),
          ),
        ];
      case UserRole.trainer:
        section = 'Trainer Tools';
        tiles = [
          _TileData(
            'Create Workout',
            'Design workout templates',
            Icons.add_circle_outline,
            () => _open(CreateWorkoutTemplateScreen()),
          ),
          _TileData(
            'Upload Video',
            'Share training content',
            Icons.video_call_outlined,
            () => _open(const VideoUploadScreen()),
          ),
          _TileData(
            'My Videos',
            'Manage your content',
            Icons.video_collection_outlined,
            () => _open(const TrainerVideosScreen()),
          ),
          _TileData(
            'My Clients',
            'Manage your assigned members',
            Icons.group_outlined,
            () => _open(const TrainerClientsScreen()),
          ),
          _TileData(
            'Manage Workouts',
            'Edit or delete your workouts',
            Icons.edit_note,
            () => _open(const ManageWorkoutsScreen()),
          ),
          _TileData(
            'My Ratings',
            'View feedback from clients',
            Icons.star_outline,
            () => _open(const TrainerRatingsScreen()),
          ),
        ];
      case UserRole.admin:
        section = 'Admin Panel';
        tiles = [
          _TileData(
            'User Management',
            'Manage users and permissions',
            Icons.people_outline,
            () => _open(const AdminUsersScreen()),
          ),
          _TileData(
            'Trainer Videos',
            'Review and remove inappropriate uploads',
            Icons.video_library_outlined,
            () => _open(const AdminContentModerationScreen(initialTab: 0)),
          ),
          _TileData(
            'Trainer Workouts',
            'Review and remove inappropriate workouts',
            Icons.fitness_center,
            () => _open(const AdminContentModerationScreen(initialTab: 1)),
          ),
          _TileData(
            'Reset Requests',
            'Approve BMI / calorie cooldown resets',
            Icons.restart_alt,
            () => _open(const AdminResetRequestsScreen()),
          ),
        ];
    }

    return [
      EntranceRise(index: 1, child: GymSectionLabel(label: section)),
      const SizedBox(height: AuthSpace.s),
      for (var i = 0; i < tiles.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        EntranceRise(
          index: 2 + i,
          child: _DashTile(number: i + 1, data: tiles[i]),
        ),
      ],
    ];
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'ADMINISTRATOR';
      case UserRole.trainer:
        return 'TRAINER';
      case UserRole.member:
        return 'MEMBER';
    }
  }
}

class _TileData {
  const _TileData(this.title, this.subtitle, this.icon, this.onTap);

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

/// App logo in a 44px rounded square, in place of the back button.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AuthColors.textPrimary,
        borderRadius: BorderRadius.circular(AuthRadius.field),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuthRadius.thumb),
        child: Image.asset(
          'assets/fitness_logo.webp',
          fit: BoxFit.cover,
          semanticLabel: 'LiftLog',
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      padding: const EdgeInsets.all(AuthSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GymAvatar(text: user.name, size: 52, highlighted: true),
              const SizedBox(width: AuthSpace.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back,', style: AuthType.body(size: 14)),
                    const SizedBox(height: 4),
                    Text(
                      user.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuthType.display(32),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuthSpace.m),
          // The sign-in barbell, fully loaded and locked out: the lift is
          // done. Same Hero tag as the auth screens, so on logout it flies
          // back to the sign-in screen.
          const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: BarbellIndicator(
              plates: 3,
              maxPlates: 3,
              phase: BarbellPhase.lockout,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashTile extends StatelessWidget {
  const _DashTile({required this.number, required this.data});

  final int number;
  final _TileData data;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: data.onTap,
      semanticLabel: '${data.title}. ${data.subtitle}',
      padding: const EdgeInsets.fromLTRB(AuthSpace.s, 18, 12, 18),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: AuthType.mono(color: AuthColors.accent),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AuthColors.surfaceHi,
              borderRadius: BorderRadius.circular(AuthRadius.field),
              border: Border.all(color: AuthColors.line),
            ),
            child: Icon(data.icon, size: 20, color: AuthColors.textPrimary),
          ),
          const SizedBox(width: AuthSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title.toUpperCase(),
                  style: AuthType.display(22).copyWith(height: 1),
                ),
                const SizedBox(height: 4),
                Text(data.subtitle, style: AuthType.body(size: 13)),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward,
            size: 18,
            color: AuthColors.textMuted,
          ),
        ],
      ),
    );
  }
}
