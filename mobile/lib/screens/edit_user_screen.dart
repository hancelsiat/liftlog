import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';
import '../widgets/gym/gym.dart';
import 'register_screen.dart' show normalizeFullName, validateFullName;

class EditUserScreen extends StatefulWidget {
  final User user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _fullNameController;
  final ApiService _apiService = ApiService();
  bool _saving = false;

  bool get _isTrainer => widget.user.role == UserRole.trainer;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  String? _required(String label, String? value) {
    if (value == null || value.isEmpty) return 'Please enter a $label';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length < 6) {
        return 'Your password must be at least 6 characters long.';
      }
      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
        return 'Password must contain at least 1 uppercase, 1 lowercase, and 1 number.';
      }
    }
    return null;
  }

  void _updateUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _saving = true);
      try {
        final updates = {
          'username': _usernameController.text,
          'email': _emailController.text,
        };
        if (_isTrainer) {
          updates['fullName'] = normalizeFullName(_fullNameController.text);
        }

        if (_passwordController.text.isNotEmpty) {
          updates['password'] = _passwordController.text;
        }

        await _apiService.updateUser(widget.user.id, updates);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          showErrorSnackBar(context, e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user.role.toString().split('.').last;

    return GymScaffold(
      eyebrow: 'Admin / Users',
      title: 'Edit User',
      bottomBar: GymBottomBar(
        child: PressableButton(
          label: 'Update User',
          loading: _saving,
          onPressed: _saving ? null : _updateUser,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GymScaffold.side,
            AuthSpace.xs,
            GymScaffold.side,
            AuthSpace.l,
          ),
          children: [
            EntranceRise(
              index: 0,
              child: Row(
                children: [
                  GymAvatar(
                    text: widget.user.username,
                    size: 56,
                    highlighted: true,
                  ),
                  const SizedBox(width: AuthSpace.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.username.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuthType.display(26),
                        ),
                        const SizedBox(height: 6),
                        GymTag(label: role, icon: Icons.verified_user_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuthSpace.l),
            const EntranceRise(
              index: 1,
              child: GymSectionLabel(index: 1, label: 'Account'),
            ),
            const SizedBox(height: AuthSpace.s),
            if (_isTrainer) ...[
              EntranceRise(
                index: 2,
                child: AuthTextField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  // Older trainers may have none; allow keeping it blank.
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) &&
                          widget.user.fullName.isEmpty
                      ? null
                      : validateFullName(v),
                ),
              ),
              const SizedBox(height: AuthSpace.s),
            ],
            EntranceRise(
              index: 2,
              child: AuthTextField(
                label: 'Username',
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                validator: (v) => _required('Username', v),
              ),
            ),
            const SizedBox(height: AuthSpace.s),
            EntranceRise(
              index: 3,
              child: AuthTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) => _required('Email', v),
              ),
            ),
            const SizedBox(height: AuthSpace.l),
            const EntranceRise(
              index: 4,
              child: GymSectionLabel(index: 2, label: 'Security'),
            ),
            const SizedBox(height: AuthSpace.s),
            EntranceRise(
              index: 5,
              child: AuthTextField(
                label: 'New Password (optional)',
                controller: _passwordController,
                obscurable: true,
                textInputAction: TextInputAction.done,
                validator: _validatePassword,
              ),
            ),
            const SizedBox(height: AuthSpace.xs),
            EntranceRise(
              index: 6,
              child: Text(
                'Leave blank to keep the current password.',
                style: AuthType.body(size: 13, color: AuthColors.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
