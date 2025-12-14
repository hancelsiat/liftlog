import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'workouts_screen.dart';
import 'progress_screen.dart';
import 'training_videos_screen.dart';
import 'video_upload_screen.dart';
import 'trainer_videos_screen.dart';
import 'settings_screen.dart';
import 'user_management_screen.dart';
import 'create_workout_template_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.loadProfile();
      _animationController.forward();
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
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ),
      );
    }

    // Check if user is null
    if (user == null) {
      // Redirect to login if no user is logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from logging out
        // Show dialog to confirm exit
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Exit App', style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text(
              'Do you want to exit the app?',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Custom App Bar
                _buildAppBar(context, authProvider, user),
                
                // Dashboard Content
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Welcome Card
                            _buildWelcomeCard(user),
                            const SizedBox(height: 24),

                            // Role-based Dashboard
                            if (user.role == UserRole.member) ...[
                              _buildMemberDashboard(context),
                            ] else if (user.role == UserRole.trainer) ...[
                              _buildTrainerDashboard(context),
                            ] else if (user.role == UserRole.admin) ...[
                              _buildAdminDashboard(context),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AuthProvider authProvider, User user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.3),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(
              'LiftLog',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_outlined, size: 20),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ServerSettingsScreen()),
            );
          },
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.logout, size: 20, color: AppTheme.errorColor),
          ),
          onPressed: () {
            _showLogoutDialog(context, authProvider);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWelcomeCard(User user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRoleIcon(user.role),
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _getRoleText(user.role),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Your Fitness Journey'),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'Workouts',
          subtitle: 'Browse and track your workouts',
          icon: Icons.fitness_center,
          gradient: AppTheme.primaryGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WorkoutsScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'Track Progress',
          subtitle: 'Monitor your fitness journey',
          icon: Icons.show_chart,
          gradient: AppTheme.secondaryGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProgressScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'Training Videos',
          subtitle: 'Learn from expert trainers',
          icon: Icons.video_library,
          gradient: AppTheme.accentGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TrainingVideosScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainerDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Trainer Tools'),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'Create Workout',
          subtitle: 'Design workout templates',
          icon: Icons.add_circle_outline,
          gradient: AppTheme.primaryGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateWorkoutTemplateScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'Upload Video',
          subtitle: 'Share training content',
          icon: Icons.video_call,
          gradient: AppTheme.secondaryGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VideoUploadScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'My Videos',
          subtitle: 'Manage your content',
          icon: Icons.video_collection,
          gradient: AppTheme.accentGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TrainerVideosScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Admin Panel'),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'User Management',
          subtitle: 'Manage users and permissions',
          icon: Icons.people,
          gradient: AppTheme.primaryGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserManagementScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildPremiumCard(
          title: 'System Settings',
          subtitle: 'Configure application',
          icon: Icons.settings,
          gradient: AppTheme.secondaryGradient,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('System settings coming soon'),
                backgroundColor: AppTheme.surfaceColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassMorphism,
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.trainer:
        return Icons.sports;
      case UserRole.member:
        return Icons.person;
    }
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

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              authProvider.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
