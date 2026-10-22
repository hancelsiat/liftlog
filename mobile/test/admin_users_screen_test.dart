import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liftlog_mobile/screens/admin_users_screen.dart';
import 'package:liftlog_mobile/services/api_service.dart';

Map<String, dynamic> _user(
  String username,
  String role, {
  bool verified = true,
  bool approved = true,
}) => {
  '_id': username,
  'username': username,
  'email': '$username@test.com',
  'role': role,
  'isEmailVerified': verified,
  'isApproved': approved,
};

/// Returns a fixed user list instead of hitting the network.
class _FakeApi extends ApiService {
  @override
  Future<Map<String, dynamic>> getUsers({
    String? role,
    String? search,
    int page = 1,
    int limit = 10,
  }) async => {
    'users': [
      _user('admin1', 'admin'),
      _user('coachok', 'trainer'),
      _user('coachwait', 'trainer', approved: false),
      _user('coachnew', 'trainer', verified: false, approved: false),
      _user('memberok', 'member'),
      _user('membernew', 'member', verified: false),
    ],
  };
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: AdminUsersScreen(api: _FakeApi())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('trainers tab splits pending, approved and unverified', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('TRAINERS'), findsOneWidget);
    expect(find.text('MEMBERS'), findsOneWidget);

    expect(find.text('PENDING APPROVAL (1)'), findsOneWidget);
    expect(find.text('APPROVED TRAINERS (1)'), findsOneWidget);
    expect(find.text('UNVERIFIED EMAIL (1)'), findsOneWidget);
    expect(find.text('COACHWAIT'), findsOneWidget);
    expect(find.text('COACHOK'), findsOneWidget);
    expect(find.text('COACHNEW'), findsOneWidget);

    // Members and admins are not on the trainers tab.
    expect(find.text('MEMBEROK'), findsNothing);
    expect(find.text('ADMIN1'), findsNothing);
  });

  testWidgets('members tab splits verified and unverified', (tester) async {
    await pump(tester);

    await tester.tap(find.text('MEMBERS'));
    await tester.pumpAndSettle();

    expect(find.text('VERIFIED MEMBERS (1)'), findsOneWidget);
    expect(find.text('UNVERIFIED EMAIL (1)'), findsOneWidget);
    expect(find.text('MEMBEROK'), findsOneWidget);
    expect(find.text('MEMBERNEW'), findsOneWidget);
    expect(find.text('COACHOK'), findsNothing);
    expect(find.textContaining('PENDING APPROVAL'), findsNothing);
  });
}
