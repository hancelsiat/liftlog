import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  UserRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      final response = await apiService.getUsers(
        role: _selectedRole?.name,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      setState(() {
        _users = (response['users'] as List)
            .map((userJson) => User.fromJson(userJson))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  Future<void> _updateUser(User user, Map<String, dynamic> updates) async {
    try {
      final apiService = ApiService();
      await apiService.updateUser(user.id, updates);
      await _loadUsers(); // Reload the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: $e')),
        );
      }
    }
  }

  Future<void> _approveTrainer(User user, bool isApproved) async {
    final action = isApproved ? 'approve' : 'reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isApproved ? 'Approve' : 'Reject'} Trainer'),
        content: Text(
          'Are you sure you want to $action ${user.username} as a trainer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isApproved ? Colors.green : Colors.red,
            ),
            child: Text(isApproved ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = ApiService();
        await apiService.approveTrainer(user.id, isApproved);
        await _loadUsers(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trainer ${isApproved ? 'approved' : 'rejected'} successfully'),
              backgroundColor: isApproved ? Colors.green : Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to $action trainer: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = ApiService();
        await apiService.deleteUser(user.id);
        await _loadUsers(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e')),
          );
        }
      }
    }
  }

  void _showEditUserDialog(User user) {
    final usernameController = TextEditingController(text: user.username);
    final emailController = TextEditingController(text: user.email);
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController(text: user.profile?.firstName ?? '');
    final lastNameController = TextEditingController(text: user.profile?.lastName ?? '');
    UserRole selectedRole = user.role;
    bool changePassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${user.username}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Change Password'),
                    Switch(
                      value: changePassword,
                      onChanged: (value) {
                        setState(() => changePassword = value);
                      },
                    ),
                  ],
                ),
                if (changePassword)
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updates = {
                  'username': usernameController.text,
                  'email': emailController.text,
                  'profile': {
                    'firstName': firstNameController.text,
                    'lastName': lastNameController.text,
                  },
                  'role': selectedRole.name,
                };

                if (changePassword && passwordController.text.isNotEmpty) {
                  updates['password'] = passwordController.text;
                }

                await _updateUser(user, updates);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search users...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _loadUsers();
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole?>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Filter by Role'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Roles'),
                    ),
                    ...UserRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.name.toUpperCase()),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRole = value);
                    _loadUsers();
                  },
                ),
              ],
            ),
          ),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isTrainer = user.role == UserRole.trainer;
                          final needsApproval = isTrainer && !user.isApproved;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            color: needsApproval ? Colors.orange.withOpacity(0.1) : null,
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: needsApproval ? Colors.orange : null,
                                    child: Text(user.username[0].toUpperCase()),
                                  ),
                                  if (needsApproval)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.pending,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(user.username),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${user.email} • ${user.role.name.toUpperCase()}'),
                                  if (isTrainer) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          user.isEmailVerified ? Icons.check_circle : Icons.cancel,
                                          size: 14,
                                          color: user.isEmailVerified ? Colors.green : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          user.isEmailVerified ? 'Email Verified' : 'Email Not Verified',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: user.isEmailVerified ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          user.isApproved ? Icons.check_circle : Icons.pending,
                                          size: 14,
                                          color: user.isApproved ? Colors.green : Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          user.isApproved ? 'Approved' : 'Pending Approval',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: user.isApproved ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'approve':
                                      _approveTrainer(user, true);
                                      break;
                                    case 'reject':
                                      _approveTrainer(user, false);
                                      break;
                                    case 'edit':
                                      _showEditUserDialog(user);
                                      break;
                                    case 'delete':
                                      _deleteUser(user);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (isTrainer && !user.isApproved) ...[
                                    const PopupMenuItem(
                                      value: 'approve',
                                      child: Row(
                                        children: [
                                          Icon(Icons.check, color: Colors.green, size: 20),
                                          SizedBox(width: 8),
                                          Text('Approve Trainer'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reject',
                                      child: Row(
                                        children: [
                                          Icon(Icons.close, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Text('Reject Trainer'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                    textStyle: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUsers,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
