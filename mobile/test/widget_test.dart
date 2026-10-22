// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:liftlog_mobile/main.dart';
import 'package:liftlog_mobile/screens/dashboard_screen.dart';
import 'package:liftlog_mobile/screens/login_screen.dart';

void main() {
  setUpAll(() {
    // Tests have no network; don't try to download fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Logged-out app starts on the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });
}
