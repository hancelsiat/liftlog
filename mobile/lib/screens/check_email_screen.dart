import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth/auth_page_route.dart';
import '../widgets/gym/gym.dart';
import 'login_screen.dart';

/// Shown right after sign-up: tells the user where the verification link
/// went, what to do next, and lets them resend it after a cooldown.
class CheckEmailScreen extends StatefulWidget {
  final String email;

  const CheckEmailScreen({super.key, required this.email});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  static const int _cooldownSeconds = 60;

  Timer? _timer;
  int _countdown = _cooldownSeconds;
  bool _sending = false;

  bool get _coolingDown => _countdown > 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _countdown = _cooldownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  String get _countdownLabel {
    final minutes = _countdown ~/ 60;
    final seconds = (_countdown % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    // The provider shows its own error snackbar and returns false on failure.
    final sent = await Provider.of<AuthProvider>(
      context,
      listen: false,
    ).resendVerificationEmail(context, widget.email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent) _startTimer();
    });
    if (!sent) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent again.')),
    );
  }

  void _backToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      AuthPageRoute(reverse: true, builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GymScaffold(
      eyebrow: 'Sign up / Verify',
      title: 'Check your email',
      showBack: false,
      bottomBar: GymBottomBar(
        child: PressableButton(
          label: 'Back to sign in',
          variant: PressableVariant.ghost,
          showArrow: false,
          onPressed: _backToSignIn,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          GymScaffold.side,
          AuthSpace.xs,
          GymScaffold.side,
          AuthSpace.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EntranceRise(index: 0, child: _SentToCard(email: widget.email)),
            const SizedBox(height: AuthSpace.l),
            const EntranceRise(
              index: 1,
              child: GymSectionLabel(label: 'Next steps', index: 1),
            ),
            const SizedBox(height: AuthSpace.xs),
            const EntranceRise(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Step(number: 1, text: 'Open the email from LiftLog.'),
                  _Step(number: 2, text: 'Tap "Verify Your Email".'),
                  _Step(
                    number: 3,
                    text: 'Come back here and sign in.',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuthSpace.m),
            const EntranceRise(
              index: 3,
              child: GymStatusStrip(
                color: GymColors.warn,
                icon: Icons.info_outline,
                title: "Can't find it?",
                lines: [
                  'Check your Spam or Promotions folder.',
                  'Trainer accounts also need admin approval after verifying.',
                ],
              ),
            ),
            const SizedBox(height: AuthSpace.l),
            EntranceRise(
              index: 4,
              child: PressableButton(
                label: _coolingDown
                    ? 'Resend in $_countdownLabel'
                    : 'Resend email',
                showArrow: false,
                loading: _sending,
                onPressed: _coolingDown || _sending ? null : _resend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Graphite card with the lime envelope badge and the destination address.
class _SentToCard extends StatelessWidget {
  const _SentToCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GymAvatar(
            icon: Icons.mark_email_unread_outlined,
            size: 52,
            highlighted: true,
          ),
          const SizedBox(width: AuthSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VERIFICATION LINK SENT TO', style: AuthType.label()),
                const SizedBox(height: 6),
                SelectableText(
                  email,
                  style: AuthType.body(
                    color: AuthColors.textPrimary,
                    size: 17,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'LINK EXPIRES IN 24 HOURS',
                  style: AuthType.mono(color: AuthColors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `01  Step text` row with a hairline divider underneath.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, this.last = false});

  final int number;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AuthColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: AuthType.mono(color: AuthColors.accent),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AuthType.body(color: AuthColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
