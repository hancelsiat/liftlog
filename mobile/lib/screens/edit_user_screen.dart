
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/error_handler.dart';

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
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _passwordController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit User'),
        backgroundColor: AppTheme.darkBackground,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(_usernameController, 'Username', Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email', Icons.email_outlined),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'New Password (optional)', Icons.lock_outline, obscureText: true),
                const SizedBox(height: 24),
                _buildRoleDisplay(),
                const SizedBox(height: 40),
                _buildUpdateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      ),
      validator: (value) {
        if (label != 'New Password (optional)' && (value == null || value.isEmpty)) {
          return 'Please enter a $label';
        }
        return null;
      },
    );
  }

  Widget _buildRoleDisplay() {
    return TextFormField(
      initialValue: widget.user.role.toString().split('.').last,
      readOnly: true,
      style: const TextStyle(color: AppTheme.textSecondary),
      decoration: const InputDecoration(
        labelText: 'Role',
        prefixIcon: Icon(Icons.verified_user_outlined, color: AppTheme.textSecondary),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.surfaceColor),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return ElevatedButton(
      onPressed: _updateUser,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Center(child: Text('Update User', style: TextStyle(fontSize: 16, color: Colors.white))),
    );
  }

  void _updateUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updates = {
          'username': _usernameController.text,
          'email': _emailController.text,
        };

        if (_passwordController.text.isNotEmpty) {
          updates['password'] = _passwordController.text;
        }

        await _apiService.updateUser(widget.user.id, updates);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      } catch (e) {
        showErrorSnackBar(context, e.toString());
      }
    }
  }
}
