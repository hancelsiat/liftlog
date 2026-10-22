import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/auth_tokens.dart';
import '../widgets/auth/auth_page_route.dart';
import '../widgets/auth/auth_scaffold.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/auth/barbell_indicator.dart';
import '../widgets/auth/credential_picker.dart';
import '../widgets/auth/error_banner.dart';
import '../widgets/auth/pressable_button.dart';
import '../widgets/auth/role_segmented_control.dart';
import '../widgets/auth/shake_on_error.dart';
import '../widgets/auth/staggered_entrance.dart';
import 'login_screen.dart';
import 'check_email_screen.dart';

// Same rules as validateFullName in backend/routes/auth.js.
final _fullNameRule = RegExp(r"^\p{L}[\p{L} .'-]*$", unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);

/// Collapses repeated whitespace and trims, the form the server stores.
String normalizeFullName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Validates a trainer's legal name (first and last name, letters only).
/// Used by sign-up and by the admin's Edit User screen.
String? validateFullName(String? value) {
  final name = normalizeFullName(value ?? '');
  if (name.isEmpty) {
    return 'Please enter your full name as it appears on your credential.';
  }
  if (name.length > 100) {
    return 'Your full name must be 100 characters or fewer.';
  }
  if (!_fullNameRule.hasMatch(name)) {
    return 'Use letters, spaces, periods, apostrophes and hyphens only.';
  }
  if (name.split(' ').where((p) => _letter.hasMatch(p)).length < 2) {
    return 'Please enter your first and last name.';
  }
  return null;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  UserRole _selectedRole = UserRole.member;
  File? _credentialFile;
  late AnimationController _animationController;

  static final _passwordRule = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)');

  int _failCount = 0;
  int _lastPlates = 0;
  bool _credentialMissing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AuthMotion.entranceTotalMs),
    );
    _usernameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationController.isDismissed) {
      if (AuthMotion.reduced(context)) {
        _animationController.value = 1;
      } else {
        _animationController.forward();
      }
    }
  }

  void _onFieldChanged() {
    if (_plates != _lastPlates) setState(() => _lastPlates = _plates);
  }

  // Same rules as the validators below; drives the barbell plates only.
  int get _plates {
    final username = _usernameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    return (username.length >= 3 ? 1 : 0) +
        (email.isNotEmpty && email.contains('@') ? 1 : 0) +
        (password.length >= 6 && _passwordRule.hasMatch(password) ? 1 : 0);
  }

  void _fail() => setState(() => _failCount++);

  Future<void> _pickCredential() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _credentialFile = File(result.files.single.path!);
        _credentialMissing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return AuthScaffold(
      entrance: _animationController,
      step: '02 / Sign up',
      header: _buildHeader(authProvider),
      form: _buildForm(authProvider),
      footer: _buildLoginLink(),
    );
  }

  Widget _buildHeader(AuthProvider authProvider) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BarbellIndicator(
          plates: _plates,
          maxPlates: 3,
          failTrigger: _failCount,
          phase: authProvider.isLoading
              ? BarbellPhase.working
              : BarbellPhase.idle,
        ),
        SizedBox(height: compact ? AuthSpace.s : AuthSpace.m),
        HeadlineReveal(
          lines: const ['LOAD THE', 'FIRST PLATE.'],
          fontSize: compact ? 44 : 56,
          semanticsLabel: 'Load the first plate.',
        ),
        const SizedBox(height: 12),
        EntranceRise(
          index: 0,
          child: Text(
            'Create your account. Every set gets logged.',
            style: AuthType.body(),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider authProvider) {
    final isTrainer = _selectedRole == UserRole.trainer;
    return ShakeOnError(
      trigger: _failCount,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              EntranceRise(index: 1, child: _buildRoleSelection()),
              AnimatedSize(
                duration: AuthMotion.reduced(context)
                    ? Duration.zero
                    : AuthMotion.base,
                curve: AuthMotion.enter,
                alignment: Alignment.topCenter,
                child: isTrainer
                    ? Padding(
                        padding: const EdgeInsets.only(top: AuthSpace.s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFullNameField(),
                            const SizedBox(height: AuthSpace.xs),
                            Text(
                              'Must match the name on your credential. '
                              'An admin compares them before approving you.',
                              style: AuthType.body(
                                size: 13,
                                color: AuthColors.textFaint,
                              ),
                            ),
                            const SizedBox(height: AuthSpace.s),
                            CredentialPicker(
                              file: _credentialFile,
                              onPick: _pickCredential,
                              showRequired: _credentialMissing,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: AuthSpace.s),
              EntranceRise(index: 2, child: _buildUsernameField()),
              const SizedBox(height: AuthSpace.s),
              EntranceRise(index: 3, child: _buildEmailField()),
              const SizedBox(height: AuthSpace.s),
              EntranceRise(index: 4, child: _buildPasswordField()),
              const SizedBox(height: AuthSpace.m),
              EntranceRise(index: 5, child: _buildRegisterButton(authProvider)),
              ErrorBanner(message: authProvider.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('I AM A', style: AuthType.label()),
        const SizedBox(height: AuthSpace.xs),
        RoleSegmentedControl<UserRole>(
          segments: const [
            RoleSegment(value: UserRole.member, label: 'Member'),
            RoleSegment(value: UserRole.trainer, label: 'Trainer'),
          ],
          selected: _selectedRole,
          onChanged: (role) => setState(() => _selectedRole = role),
        ),
        const SizedBox(height: AuthSpace.xs),
        RoleHelperLine(
          text: _selectedRole == UserRole.trainer
              ? 'Trainer accounts require admin approval before activation.'
              : 'Track your lifts, sessions and progress.',
        ),
      ],
    );
  }

  Widget _buildFullNameField() {
    return AuthTextField(
      label: 'Full Name',
      controller: _fullNameController,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      validator: validateFullName,
    );
  }

  Widget _buildUsernameField() {
    return AuthTextField(
      label: 'Username',
      controller: _usernameController,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newUsername],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a username.';
        }
        if (value.length < 3) {
          return 'Your username must be at least 3 characters long.';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return AuthTextField(
      label: 'Email',
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email address.';
        }
        if (!value.contains('@')) {
          return 'This doesn\'t look like a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return AuthTextField(
      label: 'Password',
      controller: _passwordController,
      obscurable: true,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onSubmitted: (_) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (!auth.isLoading) _register();
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password.';
        }
        if (value.length < 6) {
          return 'Your password must be at least 6 characters long.';
        }
        if (!_passwordRule.hasMatch(value)) {
          return 'Password must contain at least 1 uppercase, 1 lowercase, and 1 number.';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton(AuthProvider authProvider) {
    bool canRegister = !authProvider.isLoading;
    if (_selectedRole == UserRole.trainer && _credentialFile == null) {
      canRegister = false;
    }
    return PressableButton(
      label: 'Create Account',
      loading: authProvider.isLoading,
      onPressed: canRegister ? _register : null,
    );
  }

  void _register() async {
    FocusScope.of(context).unfocus();
    Provider.of<AuthProvider>(context, listen: false).clearError();

    if (_formKey.currentState!.validate()) {
      if (_selectedRole == UserRole.trainer && _credentialFile == null) {
        setState(() => _credentialMissing = true);
        _fail();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your trainer credential.'),
          ),
        );
        return;
      }

      final success = await Provider.of<AuthProvider>(context, listen: false)
          .register(
            context,
            _emailController.text.trim(),
            _passwordController.text,
            _usernameController.text.trim(),
            role: _selectedRole,
            credentialFile: _credentialFile,
            fullName: _selectedRole == UserRole.trainer
                ? normalizeFullName(_fullNameController.text)
                : null,
          );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CheckEmailScreen(email: _emailController.text.trim()),
          ),
        );
      } else if (mounted) {
        _fail();
      }
    } else {
      _fail();
    }
  }

  Widget _buildLoginLink() {
    return AuthFooterLink(
      prompt: 'Already have an account?',
      action: 'Sign In',
      onTap: () {
        Navigator.pushReplacement(
          context,
          AuthPageRoute(
            reverse: true,
            builder: (context) => const LoginScreen(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }
}
