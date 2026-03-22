import 'package:intl/intl.dart';

/// Utility class for handling Philippine Standard Time (PST) throughout the application
/// PST is UTC+8 and does not observe daylight saving time
class TimeUtils {
  // Philippine Standard Time is UTC+8
  static const int _pstOffsetHours = 8;
  static const Duration _pstOffset = Duration(hours: _pstOffsetHours);

  /// Get current time in Philippine Standard Time
  static DateTime nowPST() {
    final utcNow = DateTime.now().toUtc();
    return utcNow.add(_pstOffset);
  }

  /// Convert any DateTime to Philippine Standard Time
  static DateTime toPST(DateTime dateTime) {
    if (dateTime.isUtc) {
      return dateTime.add(_pstOffset);
    } else {
      // Convert local time to UTC first, then to PST
      return dateTime.toUtc().add(_pstOffset);
    }
  }

  /// Convert Philippine Standard Time to UTC for database storage
  static DateTime pstToUtc(DateTime pstDateTime) {
    return pstDateTime.subtract(_pstOffset);
  }

  /// Format PST DateTime for database storage (ISO 8601 format in UTC)
  static String formatForDatabase(DateTime? pstDateTime) {
    if (pstDateTime == null) return DateTime.now().toUtc().toIso8601String();
    return pstToUtc(pstDateTime).toIso8601String();
  }

  /// Parse database timestamp and convert to PST
  static DateTime parseFromDatabase(String? dbTimestamp) {
    if (dbTimestamp == null) return nowPST();
    final utcDateTime = DateTime.parse(dbTimestamp).toUtc();
    return utcDateTime.add(_pstOffset);
  }

  /// Get today's date in PST (date only, time set to 00:00:00)
  static DateTime todayPST() {
    final now = nowPST();
    return DateTime(now.year, now.month, now.day);
  }

  /// Get start of day in PST (00:00:00)
  static DateTime startOfDayPST([DateTime? date]) {
    final targetDate = date ?? nowPST();
    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

  /// Get end of day in PST (23:59:59.999)
  static DateTime endOfDayPST([DateTime? date]) {
    final targetDate = date ?? nowPST();
    return DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      23,
      59,
      59,
      999,
    );
  }

  /// Format PST DateTime for display
  static String formatForDisplay(
    DateTime? pstDateTime, [
    String pattern = 'MMM dd, yyyy h:mm a',
  ]) {
    if (pstDateTime == null) return '';
    return DateFormat(pattern).format(pstDateTime);
  }

  /// Format time only for display
  static String formatTimeForDisplay(DateTime? pstDateTime) {
    if (pstDateTime == null) return '';
    return DateFormat('h:mm a').format(pstDateTime);
  }

  /// Format date only for display
  static String formatDateForDisplay(DateTime? pstDateTime) {
    if (pstDateTime == null) return '';
    return DateFormat('MMM dd, yyyy').format(pstDateTime);
  }

  /// Format date for database queries (yyyy-MM-dd)
  static String formatDateForQuery(DateTime? pstDateTime) {
    if (pstDateTime == null) return formatDateForQuery(nowPST());
    return DateFormat('yyyy-MM-dd').format(pstDateTime);
  }

  /// Check if a PST DateTime is today in PST
  static bool isToday(DateTime pstDateTime) {
    final today = todayPST();
    return pstDateTime.year == today.year &&
        pstDateTime.month == today.month &&
        pstDateTime.day == today.day;
  }

  /// Check if a PST DateTime is in the past (before current PST time)
  static bool isPast(DateTime pstDateTime) {
    return pstDateTime.isBefore(nowPST());
  }

  /// Check if a PST DateTime is in the future (after current PST time)
  static bool isFuture(DateTime pstDateTime) {
    return pstDateTime.isAfter(nowPST());
  }

  /// Get difference in days from now (PST)
  static int daysDifference(DateTime pstDateTime) {
    final now = nowPST();
    final nowDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(
      pstDateTime.year,
      pstDateTime.month,
      pstDateTime.day,
    );
    return targetDate.difference(nowDate).inDays;
  }

  /// Create a PST DateTime from date and time components
  static DateTime createPST(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) {
    return DateTime(year, month, day, hour, minute, second);
  }

  /// Parse time string (HH:MM or HH:MM:SS) and create PST DateTime for today
  static DateTime parseTimeForToday(String timeString) {
    final parts = timeString.split(':');
    if (parts.length < 2)
      throw FormatException('Invalid time format: $timeString');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final second = parts.length > 2 ? int.parse(parts[2]) : 0;

    final today = todayPST();
    return DateTime(today.year, today.month, today.day, hour, minute, second);
  }

  /// Get the current school day status in PST
  static SchoolDayStatus getSchoolDayStatus() {
    final now = nowPST();
    final currentTime = DateTime(2000, 1, 1, now.hour, now.minute);

    // Define school hours in PST
    final schoolStart = DateTime(2000, 1, 1, 7, 0); // 7:00 AM
    final schoolEnd = DateTime(2000, 1, 1, 17, 0); // 5:00 PM
    final lateThreshold = DateTime(2000, 1, 1, 8, 0); // 8:00 AM

    if (currentTime.isBefore(schoolStart)) {
      return SchoolDayStatus.beforeSchool;
    } else if (currentTime.isBefore(lateThreshold)) {
      return SchoolDayStatus.onTime;
    } else if (currentTime.isBefore(schoolEnd)) {
      return SchoolDayStatus.duringSchool;
    } else {
      return SchoolDayStatus.afterSchool;
    }
  }

  /// Convert UTC timestamp from database to PST and format for display
  static String formatDatabaseTimestamp(
    String? utcTimestamp, [
    String pattern = 'MMM dd, yyyy h:mm a',
  ]) {
    if (utcTimestamp == null) return '';
    final pstDateTime = parseFromDatabase(utcTimestamp);
    return formatForDisplay(pstDateTime, pattern);
  }

  /// Get PST time zone name for display
  static String get timeZoneName => 'PST (UTC+8)';

  /// Get PST offset string
  static String get offsetString => '+08:00';

  /// Debug method to show current time information
  static Map<String, String> getDebugTimeInfo() {
    final localNow = DateTime.now();
    final utcNow = DateTime.now().toUtc();
    final pstNow = nowPST();

    return {
      'local_time': localNow.toString(),
      'utc_time': utcNow.toString(),
      'pst_time': pstNow.toString(),
      'pst_formatted': formatForDisplay(pstNow),
      'timezone': timeZoneName,
      'offset': offsetString,
      'for_database': formatForDatabase(pstNow),
    };
  }
}

/// Enum for school day status
enum SchoolDayStatus { beforeSchool, onTime, duringSchool, afterSchool }
