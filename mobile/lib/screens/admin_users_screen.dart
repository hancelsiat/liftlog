
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'edit_user_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<User>> _usersFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
  }

  Future<List<User>> _fetchUsers() async {
    final response = await _apiService.getUsers(); 
    final usersData = response['users'] as List;
    return usersData.map((data) => User.fromJson(data)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: FutureBuilder<List<User>>(
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

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  isThreeLine: true,
                  title: Text(user.username),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user.role == UserRole.trainer && user.credentialImageUrl.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.badge_outlined, color: Colors.blue),
                          tooltip: 'View Credential',
                          onPressed: () => _viewCredential(user.credentialImageUrl),
                        ),
                      if (user.role == UserRole.trainer && !user.isApproved)
                        ElevatedButton(
                          onPressed: () => _approveTrainer(user.id),
                          child: const Text('Approve'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.green),
                        tooltip: 'Edit User',
                        onPressed: () => _editUser(context, user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete User',
                        onPressed: () => _deleteUser(context, user.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _viewCredential(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open credential URL: $url')),
      );
    }
  }

  void _approveTrainer(String userId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.approveTrainer(userId, true);
      setState(() {
        _usersFuture = _fetchUsers(); // Refresh the list
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trainer approved successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving trainer: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _editUser(BuildContext context, User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserScreen(user: user),
      ),
    ).then((_) => setState(() {
      _usersFuture = _fetchUsers();
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
                    _usersFuture = _fetchUsers();
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting user: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
