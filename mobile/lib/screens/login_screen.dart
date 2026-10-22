import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_tokens.dart';
import '../widgets/auth/auth_dialog.dart';
import '../widgets/auth/auth_page_route.dart';
import '../widgets/auth/auth_scaffold.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/auth/barbell_indicator.dart';
import '../widgets/auth/error_banner.dart';
import '../widgets/auth/pressable_button.dart';
import '../widgets/auth/shake_on_error.dart';
import '../widgets/auth/staggered_entrance.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animationController;

  int _failCount = 0;
  bool _lockout = false;
  int _lastPlates = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AuthMotion.entranceTotalMs),
    );
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

  // Rebuild only when the plate count actually changes.
  void _onFieldChanged() {
    if (_plates != _lastPlates) setState(() => _lastPlates = _plates);
  }

  // Same rules as the validators below; drives the barbell plates only.
  int get _plates {
    final email = _emailController.text;
    final password = _passwordController.text;
    return (email.isNotEmpty && email.contains('@') ? 1 : 0) +
        (password.length >= 6 ? 1 : 0);
  }

  void _fail() => setState(() => _failCount++);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return AuthScaffold(
      entrance: _animationController,
      step: '01 / Sign in',
      header: _buildHeader(authProvider),
      form: _buildForm(authProvider),
      footer: _buildRegisterLink(),
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
          maxPlates: 2,
          failTrigger: _failCount,
          phase: _lockout
              ? BarbellPhase.lockout
              : authProvider.isLoading
              ? BarbellPhase.working
              : BarbellPhase.idle,
        ),
        SizedBox(height: compact ? AuthSpace.s : AuthSpace.m),
        HeadlineReveal(
          lines: const ['BACK UNDER', 'THE BAR.'],
          fontSize: compact ? 48 : 60,
          semanticsLabel: 'Back under the bar.',
        ),
        const SizedBox(height: 12),
        EntranceRise(
          index: 0,
          child: Text(
            'Sign in to pick up where you left off.',
            style: AuthType.body(),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider authProvider) {
    return ShakeOnError(
      trigger: _failCount,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              EntranceRise(index: 1, child: _buildEmailField()),
              const SizedBox(height: AuthSpace.s),
              EntranceRise(index: 2, child: _buildPasswordField()),
              EntranceRise(index: 2, child: _buildForgotPasswordLink()),
              const SizedBox(height: AuthSpace.xs),
              EntranceRise(index: 3, child: _buildLoginButton(authProvider)),
              // Special cases (unverified / pending) are handled by dialogs.
              ErrorBanner(
                message:
                    authProvider.emailNotVerified ||
                        authProvider.pendingApproval
                    ? null
                    : authProvider.error,
              ),
            ],
          ),
        ),
      ),
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
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (!auth.isLoading && !_lockout) _login();
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password.';
        }
        if (value.length < 6) {
          return 'Your password must be at least 6 characters long.';
        }
        return null;
      },
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: 'Forgot password?',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openForgotPassword,
          child: SizedBox(
            height: AuthSpace.tapTarget,
            child: Center(
              child: Text(
                'Forgot password?',
                style:
                    AuthType.body(
                      color: AuthColors.textPrimary,
                      size: 14,
                      weight: FontWeight.w500,
                    ).copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: AuthColors.accent,
                      decorationThickness: 2,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    FocusScope.of(context).unfocus();
    Provider.of<AuthProvider>(context, listen: false).clearError();
    final email = await Navigator.push<String>(
      context,
      AuthPageRoute(
        builder: (context) =>
            ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
    // After a successful reset, fill in the email and clear the old password.
    if (email != null && mounted) {
      _emailController.text = email;
      _passwordController.clear();
    }
  }

  Widget _buildLoginButton(AuthProvider authProvider) {
    return PressableButton(
      label: 'Sign In',
      loading: authProvider.isLoading || _lockout,
      onPressed: authProvider.isLoading || _lockout ? null : _login,
    );
  }

  Widget _buildRegisterLink() {
    return AuthFooterLink(
      prompt: 'Don\'t have an account?',
      action: 'Sign Up',
      onTap: () {
        Navigator.push(
          context,
          AuthPageRoute(builder: (context) => const RegisterScreen()),
        );
      },
    );
  }

  void _login() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        context,
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Lockout: the bar lifts and holds for a beat, then we leave.
        setState(() => _lockout = true);
        if (!AuthMotion.reduced(context)) {
          await Future<void>.delayed(AuthMotion.base + AuthMotion.lockoutHold);
        }
        if (!mounted) return;
        // Navigate to dashboard with fade transition
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else if (!mounted) {
        return;
      } else if (authProvider.pendingApproval) {
        showAuthDialog<void>(
          context: context,
          barrierDismissible:
              false, // User must tap button to dismiss, so they read the message
          eyebrow: 'Pending review',
          title: 'Waiting for Admin Approval',
          message:
              'Your trainer registration was successful, and your email is verified! However, an administrator needs to review and approve your account before you can log in.\n\nPlease be patient, as this usually takes less than 24 hours.',
          actions: (dialogContext) => [
            AuthDialogAction(
              label: 'I Understand',
              primary: true,
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      } else if (authProvider.emailNotVerified) {
        showAuthDialog<void>(
          context: context,
          eyebrow: 'One more step',
          title: 'Email Not Verified',
          message:
              'Please verify your email address before logging in. Would you like to resend the verification email?',
          actions: (dialogContext) => [
            AuthDialogAction(
              label: 'Cancel',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AuthDialogAction(
              label: 'Resend',
              primary: true,
              onPressed: () {
                authProvider.resendVerificationEmail(
                  context,
                  _emailController.text.trim(),
                );
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      } else {
        // Generic failure (the provider already showed the snackbar).
        _fail();
      }
    } else {
      _fail();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
