import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liftlog_mobile/screens/check_email_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: CheckEmailScreen(email: 'irish.siat@gmail.com')),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the app-styled verify layout', (tester) async {
    await pump(tester);

    expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
    expect(find.text('SIGN UP / VERIFY'), findsOneWidget);
    expect(find.text('irish.siat@gmail.com'), findsOneWidget);
    expect(find.text('NEXT STEPS'), findsOneWidget);
    expect(find.text('BACK TO SIGN IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend button counts down then unlocks', (tester) async {
    await pump(tester);
    expect(find.textContaining('RESEND IN 0:5'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('RESEND EMAIL'), findsOneWidget);
  });
}
