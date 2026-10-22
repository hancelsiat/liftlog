import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog_mobile/models/user.dart';
import 'package:liftlog_mobile/screens/credential_viewer_screen.dart';
import 'package:liftlog_mobile/screens/register_screen.dart';

void main() {
  group('validateFullName', () {
    test('accepts first + last name, including accents and punctuation', () {
      expect(validateFullName('Juan Dela Cruz'), isNull);
      expect(validateFullName('  María   José  Peña '), isNull);
      expect(validateFullName("Mary-Jane O'Neil Jr."), isNull);
    });

    test('rejects empty, single-word, digits and symbols', () {
      expect(validateFullName(''), isNotNull);
      expect(validateFullName('   '), isNotNull);
      expect(
        validateFullName('Juan'),
        'Please enter your first and last name.',
      );
      expect(validateFullName('Juan 123'), isNotNull);
      expect(validateFullName('Juan @Cruz'), isNotNull);
      expect(
        validateFullName('Juan -'),
        'Please enter your first and last name.',
      );
      expect(validateFullName('A ${'b' * 100}'), isNotNull);
    });

    test('normalizeFullName trims and collapses spaces', () {
      expect(normalizeFullName('  Juan   Dela\tCruz '), 'Juan Dela Cruz');
    });
  });

  group('User.fullName', () {
    test('parses fullName and uses it as the display name', () {
      final u = User.fromJson({
        '_id': '1',
        'username': 'coachj',
        'fullName': ' Juan Dela Cruz ',
        'role': 'trainer',
      });
      expect(u.fullName, 'Juan Dela Cruz');
      expect(u.name, 'Juan Dela Cruz');
      expect(u.toJson()['fullName'], 'Juan Dela Cruz');
    });

    test('older accounts without fullName fall back to username', () {
      final u = User.fromJson({'_id': '1', 'username': 'coachj'});
      expect(u.fullName, '');
      expect(u.name, 'coachj');
    });
  });

  group('CredentialViewerScreen', () {
    testWidgets('shows the declared name to compare', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CredentialViewerScreen(
            imageUrl: 'http://localhost/none.png',
            fullName: 'Juan Dela Cruz',
            username: 'coachj',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('NAME GIVEN AT SIGN-UP'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('@coachj'), findsOneWidget);
    });

    testWidgets('warns when no name was provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CredentialViewerScreen(imageUrl: 'http://localhost/none.png'),
        ),
      );
      await tester.pump();
      expect(find.text('Not provided'), findsOneWidget);
    });
  });
}
