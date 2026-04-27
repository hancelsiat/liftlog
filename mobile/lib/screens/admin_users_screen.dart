
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';
import 'edit_user_screen.dart';
import 'credential_viewer_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<Map<UserRole, List<User>>> _usersFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchAndGroupUsers();
  }

  Future<Map<UserRole, List<User>>> _fetchAndGroupUsers() async {
    final response = await _apiService.getUsers();
    final usersData = response['users'] as List;
    final users = usersData.map((data) => User.fromJson(data)).toList();

    final Map<UserRole, List<User>> groupedUsers = {
      UserRole.trainer: [],
      UserRole.member: [],
      UserRole.admin: [],
    };

    for (var user in users) {
      groupedUsers[user.role]!.add(user);
    }

    return groupedUsers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: FutureBuilder<Map<UserRole, List<User>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final groupedUsers = snapshot.data!;
          final trainers = groupedUsers[UserRole.trainer]!;
          final members = groupedUsers[UserRole.member]!;

          return ListView(
            children: [
              _buildUserSection('Trainers', trainers),
              _buildUserSection('Members', members),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserSection(String title, List<User> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(user.email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _buildActionButtons(user, context),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons(User user, BuildContext context) {
    List<Widget> buttons = [];

    if (user.role == UserRole.trainer) {
      if (!user.isApproved) {
        if (user.credentialImageUrl.isNotEmpty) {
          buttons.add(
            IconButton(
              icon: const Icon(Icons.badge_outlined, color: Colors.blue),
              tooltip: 'View Credential',
              onPressed: () => _viewCredential(context, user.credentialImageUrl),
            ),
          );
        }
        buttons.add(
          ElevatedButton(
            onPressed: () => _approveTrainer(user.id, true, context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        );
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          ElevatedButton(
            onPressed: () => _showRejectionDialog(context, user.id),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        );
      } else {
        buttons.add(
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.green),
            tooltip: 'Edit User',
            onPressed: () => _editUser(context, user),
          ),
        );
        buttons.add(
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete User',
            onPressed: () => _deleteUser(context, user.id),
          ),
        );
      }
    } else if (user.role != UserRole.admin) {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.green),
          tooltip: 'Edit User',
          onPressed: () => _editUser(context, user),
        ),
      );
      buttons.add(
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete User',
          onPressed: () => _deleteUser(context, user.id),
        ),
      );
    }

    return buttons;
  }

  void _viewCredential(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CredentialViewerScreen(imageUrl: imageUrl),
      ),
    );
  }

  void _approveTrainer(String userId, bool approve, BuildContext context, {String? rejectionReason}) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.approveTrainer(context, userId, approve, rejectionReason: rejectionReason);
      setState(() {
        _usersFuture = _fetchAndGroupUsers();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trainer ${approve ? 'approved' : 'rejected'} successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      showErrorSnackBar(context, e.toString());
    }
  }

  void _showRejectionDialog(BuildContext context, String userId) {
    final rejectionReasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Trainer'),
          content: TextField(
            controller: rejectionReasonController,
            decoration: const InputDecoration(hintText: "Reason for rejection"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final reason = rejectionReasonController.text;
                if (reason.isNotEmpty) {
                  _approveTrainer(userId, false, context, rejectionReason: reason);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  void _editUser(BuildContext context, User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserScreen(user: user),
      ),
    ).then((_) => setState(() {
      _usersFuture = _fetchAndGroupUsers();
    }));
  }

  void _deleteUser(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: const Text('Are you sure you want to delete this user?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                try {
                  await _apiService.deleteUser(userId);
                  setState(() {
                    _usersFuture = _fetchAndGroupUsers();
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  showErrorSnackBar(context, e.toString());
                }
              },
            ),
          ],
        );
      },
    );
  }
}
