import 'package:intl/intl.dart';

/// Philippine Standard Time helpers (UTC+8, no daylight saving).
class PhTime {
  static const Duration _offset = Duration(hours: 8);

  /// Converts any DateTime (UTC or device-local) to Philippine time.
  static DateTime toPh(DateTime date) => date.toUtc().add(_offset);

  /// Chat timestamp in PH time:
  /// - today: "3:45 PM"
  /// - yesterday: "Yesterday 3:45 PM"
  /// - older: "Oct 17, 3:45 PM"
  static String formatChatTime(DateTime date) {
    final ph = toPh(date);
    final nowPh = toPh(DateTime.now());
    final today = DateTime(nowPh.year, nowPh.month, nowPh.day);
    final msgDay = DateTime(ph.year, ph.month, ph.day);
    final time = DateFormat('h:mm a').format(ph);

    if (msgDay == today) return time;
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
    return '${DateFormat('MMM d').format(ph)}, $time';
  }
}
