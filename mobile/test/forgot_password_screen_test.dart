import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liftlog_mobile/screens/forgot_password_screen.dart';
import 'package:liftlog_mobile/services/api_service.dart';

/// Records calls instead of hitting the network.
class _FakeApi extends ApiService {
  final calls = <String>[];
  String validCode = '123456';

  @override
  Future<void> requestPasswordReset(String email) async {
    calls.add('request:$email');
  }

  @override
  Future<String> verifyPasswordResetOtp(String email, String otp) async {
    calls.add('verify:$email:$otp');
    if (otp != validCode) {
      throw ApiException(
        message: 'That code is incorrect. 4 tries left.',
        statusCode: 400,
      );
    }
    return 'reset-token';
  }

  @override
  Future<void> resetPassword(
    String email,
    String resetToken,
    String password,
  ) async {
    calls.add('reset:$email:$resetToken:$password');
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _FakeApi api;
  String? popped;

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    api = _FakeApi();
    popped = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(
                        initialEmail: 'Irish.Siat@gmail.com',
                        api: api,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('email → code → new password, then pops with the email', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('RESET / 1 OF 3'), findsOneWidget);

    await tapButton(tester, 'SEND CODE');
    expect(api.calls, ['request:irish.siat@gmail.com']);
    expect(find.text('RESET / 2 OF 3'), findsOneWidget);
    expect(find.textContaining('RESEND IN'), findsOneWidget);

    // Letters are stripped; only 6 digits are kept.
    await tester.enterText(
      find.byKey(const ValueKey('reset-code')).last,
      '12ab3456789',
    );
    await tapButton(tester, 'VERIFY CODE');
    expect(api.calls.last, 'verify:irish.siat@gmail.com:123456');
    expect(find.text('RESET / 3 OF 3'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('reset-password')).last,
      'NewPass1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm')).last,
      'NewPass1',
    );
    await tapButton(tester, 'SAVE PASSWORD');

    expect(
      api.calls.last,
      'reset:irish.siat@gmail.com:reset-token:NewPass1',
    );
    expect(popped, 'irish.siat@gmail.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrong code shows the server error and stays on step 2', (
    tester,
  ) async {
    await pump(tester);
    await tapButton(tester, 'SEND CODE');

    await tester.enterText(
      find.byKey(const ValueKey('reset-code')).last,
      '000000',
    );
    await tapButton(tester, 'VERIFY CODE');

    expect(find.text('That code is incorrect. 4 tries left.'), findsOneWidget);
    expect(find.text('RESET / 2 OF 3'), findsOneWidget);
  });

  testWidgets('checks code length and password rules before calling server', (
    tester,
  ) async {
    await pump(tester);
    await tapButton(tester, 'SEND CODE');

    await tester.enterText(find.byKey(const ValueKey('reset-code')).last, '12');
    await tapButton(tester, 'VERIFY CODE');
    expect(find.text('Enter the 6-digit code from your email.'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('verify')), isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('reset-code')).last,
      '123456',
    );
    await tapButton(tester, 'VERIFY CODE');

    await tester.enterText(
      find.byKey(const ValueKey('reset-password')).last,
      'weakpass',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm')).last,
      'different',
    );
    await tapButton(tester, 'SAVE PASSWORD');
    expect(
      find.text(
        'Password must contain at least 1 uppercase, 1 lowercase, and 1 number.',
      ),
      findsOneWidget,
    );
    expect(find.text('Passwords don\'t match.'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('reset')), isEmpty);
  });
}
