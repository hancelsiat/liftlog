import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../utils/auth_tokens.dart';
import '../widgets/auth/auth_scaffold.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/auth/error_banner.dart';
import '../widgets/auth/pressable_button.dart';
import '../widgets/auth/shake_on_error.dart';
import '../widgets/auth/staggered_entrance.dart';

enum _Step { email, code, password }

/// Forgot password, in three steps on one screen:
///   1. Email → the server emails a 6-digit code to the sign-up address.
///   2. Code  → the user copies it from that email (proves they own the inbox).
///   3. New password → saved with the one-time token from step 2.
///
/// Pops with the email on success so the login screen can prefill it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail, this.api});

  final String? initialEmail;

  /// Injected in tests; defaults to the real service.
  final ApiService? api;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  static const int _resendSeconds = 60;
  static final _passwordRule = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)');

  late final ApiService _api = widget.api ?? ApiService();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: AuthMotion.entranceTotalMs),
  );

  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  String? _error;
  int _failCount = 0;
  String? _resetToken;

  Timer? _timer;
  int _resendIn = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isDismissed) {
      if (AuthMotion.reduced(context)) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entrance.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  // ---------------------------------------------------------------- actions

  void _startResendTimer([int seconds = _resendSeconds]) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendIn <= 1) timer.cancel();
      setState(() => _resendIn = _resendIn <= 1 ? 0 : _resendIn - 1);
    });
  }

  /// Runs [action] with the loading state and turns any failure into the
  /// inline error banner + shake. Returns false on failure.
  Future<bool> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not reach the server. Check your connection and try again.';
        _failCount++;
      });
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _failCount++);
      return;
    }
    final ok = await _run(() => _api.requestPasswordReset(_email));
    if (!ok || !mounted) return;
    _codeController.clear();
    setState(() => _step = _Step.code);
    _startResendTimer();
  }

  Future<void> _resendCode() async {
    final ok = await _run(() => _api.requestPasswordReset(_email));
    if (!ok || !mounted) return;
    _codeController.clear();
    _startResendTimer();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('A new code is on its way.')));
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _failCount++);
      return;
    }
    final ok = await _run(() async {
      _resetToken = await _api.verifyPasswordResetOtp(
        _email,
        _codeController.text.trim(),
      );
    });
    if (!ok || !mounted) return;
    setState(() => _step = _Step.password);
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _failCount++);
      return;
    }
    final ok = await _run(
      () => _api.resetPassword(_email, _resetToken!, _passwordController.text),
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password changed. Sign in with your new password.'),
      ),
    );
    Navigator.of(context).pop(_email);
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _step = _Step.email;
      _error = null;
      _resendIn = 0;
      _resetToken = null;
    });
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    final (lines, label, body) = switch (_step) {
      _Step.email => (
        const ['FORGOT YOUR', 'PASSWORD?'],
        'Forgot your password?',
        'Enter the email you signed up with. We\'ll send you a 6-digit code.',
      ),
      _Step.code => (
        const ['CHECK YOUR', 'INBOX.'],
        'Check your inbox.',
        'Copy the 6-digit code we sent to $_email. It expires in 10 minutes.',
      ),
      _Step.password => (
        const ['SET A NEW', 'PASSWORD.'],
        'Set a new password.',
        'Code confirmed. Choose a new password for your account.',
      ),
    };

    return AuthScaffold(
      entrance: _entrance,
      step: 'Reset / ${_step.index + 1} of 3',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBars(current: _step.index),
          SizedBox(height: compact ? AuthSpace.s : AuthSpace.m),
          HeadlineReveal(
            key: ValueKey(_step),
            lines: lines,
            fontSize: compact ? 44 : 56,
            semanticsLabel: label,
          ),
          const SizedBox(height: 12),
          EntranceRise(
            index: 0,
            child: Text(body, style: AuthType.body()),
          ),
        ],
      ),
      form: ShakeOnError(
        trigger: _failCount,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...switch (_step) {
                _Step.email => _emailStep(),
                _Step.code => _codeStep(),
                _Step.password => _passwordStep(),
              },
              ErrorBanner(message: _error),
            ],
          ),
        ),
      ),
      footer: AuthFooterLink(
        prompt: 'Remembered it?',
        action: 'Sign In',
        onTap: () => Navigator.of(context).pop(),
      ),
    );
  }

  List<Widget> _emailStep() => [
    EntranceRise(
      index: 1,
      child: AuthTextField(
        key: const ValueKey('reset-email'),
        label: 'Email',
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        onSubmitted: (_) => _loading ? null : _sendCode(),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your email address.';
          }
          if (!value.contains('@')) {
            return 'This doesn\'t look like a valid email address.';
          }
          return null;
        },
      ),
    ),
    const SizedBox(height: AuthSpace.m),
    EntranceRise(
      index: 2,
      child: PressableButton(
        label: 'Send Code',
        loading: _loading,
        onPressed: _loading ? null : _sendCode,
      ),
    ),
  ];

  List<Widget> _codeStep() {
    final minutes = _resendIn ~/ 60;
    final seconds = (_resendIn % 60).toString().padLeft(2, '0');
    return [
      AuthTextField(
        key: const ValueKey('reset-code'),
        label: 'Reset code',
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onSubmitted: (_) => _loading ? null : _verifyCode(),
        validator: (value) {
          if (value == null || value.trim().length != 6) {
            return 'Enter the 6-digit code from your email.';
          }
          return null;
        },
      ),
      const SizedBox(height: AuthSpace.m),
      PressableButton(
        label: 'Verify Code',
        loading: _loading,
        onPressed: _loading ? null : _verifyCode,
      ),
      const SizedBox(height: AuthSpace.xs),
      PressableButton(
        label: _resendIn > 0 ? 'Resend in $minutes:$seconds' : 'Resend Code',
        variant: PressableVariant.ghost,
        showArrow: false,
        onPressed: _resendIn > 0 || _loading ? null : _resendCode,
      ),
      const SizedBox(height: AuthSpace.xs),
      Center(
        child: TextButton(
          onPressed: _loading ? null : _changeEmail,
          child: Text(
            'Use a different email',
            style: AuthType.body(size: 14, color: AuthColors.textPrimary),
          ),
        ),
      ),
    ];
  }

  List<Widget> _passwordStep() => [
    AuthTextField(
      key: const ValueKey('reset-password'),
      label: 'New password',
      controller: _passwordController,
      obscurable: true,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a new password.';
        }
        if (value.length < 6) {
          return 'Your password must be at least 6 characters long.';
        }
        if (!_passwordRule.hasMatch(value)) {
          return 'Password must contain at least 1 uppercase, 1 lowercase, and 1 number.';
        }
        return null;
      },
    ),
    const SizedBox(height: AuthSpace.s),
    AuthTextField(
      key: const ValueKey('reset-confirm'),
      label: 'Confirm password',
      controller: _confirmController,
      obscurable: true,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onSubmitted: (_) => _loading ? null : _savePassword(),
      validator: (value) {
        if (value != _passwordController.text) {
          return 'Passwords don\'t match.';
        }
        return null;
      },
    ),
    const SizedBox(height: AuthSpace.m),
    PressableButton(
      label: 'Save Password',
      loading: _loading,
      onPressed: _loading ? null : _savePassword,
    ),
  ];
}

/// Three thin progress bars; done/current ones are lime.
class _StepBars extends StatelessWidget {
  const _StepBars({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final duration = AuthMotion.reduced(context)
        ? Duration.zero
        : AuthMotion.base;
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: duration,
              curve: AuthMotion.standard,
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? AuthColors.accent : AuthColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
