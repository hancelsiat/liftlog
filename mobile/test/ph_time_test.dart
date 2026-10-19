import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog_mobile/utils/ph_time.dart';

void main() {
  group('PhTime', () {
    test('converts UTC server time to Philippine time (UTC+8)', () {
      final utc = DateTime.parse('2026-10-19T05:30:00.000Z');
      final ph = PhTime.toPh(utc);
      expect(ph.hour, 13);
      expect(ph.minute, 30);
    });

    test('crosses midnight correctly', () {
      final ph = PhTime.toPh(DateTime.parse('2026-10-19T20:15:00.000Z'));
      expect(ph.day, 20);
      expect(ph.hour, 4);
    });

    test('shows only the time for messages sent today', () {
      final s = PhTime.formatChatTime(DateTime.now());
      expect(s, matches(RegExp(r'^\d{1,2}:\d{2} (AM|PM)$')));
    });

    test('shows "Yesterday" for messages from the previous PH day', () {
      final s = PhTime.formatChatTime(DateTime.now().subtract(const Duration(days: 1)));
      expect(s, startsWith('Yesterday '));
    });

    test('shows date for older messages', () {
      final s = PhTime.formatChatTime(DateTime.parse('2026-01-05T02:00:00.000Z'));
      expect(s, 'Jan 5, 10:00 AM');
    });
  });
}
