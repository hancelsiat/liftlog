import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'workouts_screen.dart';
import 'progress_screen.dart';
import 'training_videos_screen.dart';
import 'video_upload_screen.dart';
import 'trainer_videos_screen.dart';
import 'settings_screen.dart';
import 'user_management_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Check if user is null or not a member
    if (user == null) {
      // Redirect to login if no user is logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ServerSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Message
              Text(
                'Welcome, ${user.name}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Role-based Dashboard
              if (user.role == UserRole.member) ...[
                // Member-specific dashboard
                _buildMemberDashboard(context),
              ] else if (user.role == UserRole.trainer) ...[
                // Trainer-specific dashboard
                _buildTrainerDashboard(context),
              ] else if (user.role == UserRole.admin) ...[
                // Admin-specific dashboard
                _buildAdminDashboard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Workouts Section
        _buildDashboardCard(
          title: 'Workouts',
          icon: Icons.fitness_center,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WorkoutsScreen()),
            );
          },
        ),

        // Progress Tracking Section
        _buildDashboardCard(
          title: 'Track Progress',
          icon: Icons.show_chart,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProgressScreen()),
            );
          },
        ),

        // Training Videos Section
        _buildDashboardCard(
          title: 'Training Videos',
          icon: Icons.video_library,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TrainingVideosScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrainerDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDashboardCard(
          title: 'Manage Workouts',
          icon: Icons.fitness_center,
          onTap: () {
            // TODO: Implement trainer workout management
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trainer features coming soon')),
            );
          },
        ),
        _buildDashboardCard(
          title: 'Upload Training Video',
          icon: Icons.video_library,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VideoUploadScreen()),
            );
          },
        ),
        _buildDashboardCard(
          title: 'My Training Videos',
          icon: Icons.video_collection,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TrainerVideosScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDashboardCard(
          title: 'User Management',
          icon: Icons.people,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UserManagementScreen()),
            );
          },
        ),
        _buildDashboardCard(
          title: 'System Settings',
          icon: Icons.settings,
          onTap: () {
            // TODO: Implement system settings
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('System settings coming soon')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(icon, size: 40),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}