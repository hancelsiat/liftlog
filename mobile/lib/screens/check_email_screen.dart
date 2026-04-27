
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';

class CheckEmailScreen extends StatefulWidget {
  final String email;

  const CheckEmailScreen({super.key, required this.email});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  Timer? _timer;
  int _countdown = 60;
  bool _isButtonDisabled = true;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isButtonDisabled = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Check Your Email'),
        backgroundColor: AppTheme.darkBackground,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email, size: 100, color: AppTheme.primaryColor),
              const SizedBox(height: 20),
              const Text(
                'Please check your email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'We have sent a verification link to ${widget.email}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isButtonDisabled ? null : () {
                  Provider.of<AuthProvider>(context, listen: false).resendVerificationEmail(widget.email);
                  setState(() {
                    _countdown = 60;
                    _isButtonDisabled = true;
                  });
                  startTimer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isButtonDisabled ? Colors.grey : AppTheme.primaryColor,
                ),
                child: Text(_isButtonDisabled ? 'Resend in $_countdown' : 'Resend Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
