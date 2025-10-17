import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

/// Utility class for handling timezone conversions and EST/EDT aware operations
/// All notifications and time displays should use Eastern Time for consistency
class TimezoneUtils {
  // Private constructor to prevent instantiation
  TimezoneUtils._();

  static bool _initialized = false;
  static late tz.Location _easternLocation;

  /// Initialize timezone data - must be called once at app startup
  static Future<void> initialize() async {
    if (_initialized) return;
    
    tz.initializeTimeZones();
    _easternLocation = tz.getLocation('America/New_York');
    _initialized = true;
  }

  /// Get the current time in Eastern Time
  static DateTime nowInEastern() {
    _ensureInitialized();
    final now = DateTime.now();
    return tz.TZDateTime.from(now, _easternLocation);
  }

  /// Convert any DateTime to Eastern Time
  static DateTime toEastern(DateTime dateTime) {
    _ensureInitialized();
    return tz.TZDateTime.from(dateTime, _easternLocation);
  }

  /// Convert a local DateTime to Eastern Time
  static DateTime localToEastern(DateTime localDateTime) {
    _ensureInitialized();
    // First convert to UTC, then to Eastern
    final utc = localDateTime.toUtc();
    return tz.TZDateTime.from(utc, _easternLocation);
  }

  /// Convert Eastern Time to local time
  static DateTime easternToLocal(DateTime easternDateTime) {
    _ensureInitialized();
    // Convert Eastern to UTC, then to local
    final easternTz = tz.TZDateTime.from(easternDateTime, _easternLocation);
    return easternTz.toLocal();
  }

  /// Parse a time string (HH:mm) and return it as today's DateTime in Eastern Time
  static DateTime parseTimeInEastern(String timeString) {
    _ensureInitialized();
    
    final parts = timeString.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time format. Expected HH:mm');
    }
    
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    final nowEastern = nowInEastern();
    return tz.TZDateTime(
      _easternLocation,
      nowEastern.year,
      nowEastern.month,
      nowEastern.day,
      hour,
      minute,
    );
  }

  /// Get the next occurrence of a specific time in Eastern Time
  /// If the time has already passed today, returns tomorrow's occurrence
  static DateTime getNextOccurrenceInEastern(String timeString) {
    _ensureInitialized();
    
    final parts = timeString.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time format. Expected HH:mm');
    }
    
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    final nowEastern = nowInEastern();
    var scheduledTime = tz.TZDateTime(
      _easternLocation,
      nowEastern.year,
      nowEastern.month,
      nowEastern.day,
      hour,
      minute,
    );
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(nowEastern)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    return scheduledTime;
  }

  /// Format a DateTime in Eastern Time with timezone indicator
  static String formatWithTimezone(DateTime dateTime, {bool showDate = true}) {
    _ensureInitialized();
    
    final easternTime = toEastern(dateTime);
    final isDST = _isDaylightSavingTime(easternTime);
    final tzAbbr = isDST ? 'EDT' : 'EST';
    
    if (showDate) {
      return '${DateFormat('MMM d, yyyy h:mm a').format(easternTime)} $tzAbbr';
    } else {
      return '${DateFormat('h:mm a').format(easternTime)} $tzAbbr';
    }
  }

  /// Format just the time portion with timezone
  static String formatTimeWithTimezone(DateTime dateTime) {
    _ensureInitialized();
    
    final easternTime = toEastern(dateTime);
    final isDST = _isDaylightSavingTime(easternTime);
    final tzAbbr = isDST ? 'EDT' : 'EST';
    
    return '${DateFormat('h:mm a').format(easternTime)} $tzAbbr';
  }

  /// Get timezone abbreviation for current time
  static String getCurrentTimezoneAbbreviation() {
    _ensureInitialized();
    
    final nowEastern = nowInEastern();
    return _isDaylightSavingTime(nowEastern) ? 'EDT' : 'EST';
  }

  /// Check if a DateTime is in daylight saving time
  static bool _isDaylightSavingTime(DateTime easternDateTime) {
    _ensureInitialized();
    
    final tzDateTime = tz.TZDateTime.from(easternDateTime, _easternLocation);
    // In Eastern Time, DST is UTC-4, Standard is UTC-5
    // The timeZoneOffset is in hours
    return tzDateTime.timeZoneOffset.inHours == -4;
  }

  /// Check if current time in Eastern is within quiet hours
  static bool isInQuietHours(String quietStart, String quietEnd) {
    _ensureInitialized();
    
    final nowEastern = nowInEastern();
    final currentMinutes = nowEastern.hour * 60 + nowEastern.minute;
    
    final startParts = quietStart.split(':');
    final endParts = quietEnd.split(':');
    
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    
    // Handle overnight quiet hours (e.g., 22:00 to 07:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
  }

  /// Get the start of today in Eastern Time
  static DateTime getTodayStartInEastern() {
    _ensureInitialized();
    
    final nowEastern = nowInEastern();
    return tz.TZDateTime(
      _easternLocation,
      nowEastern.year,
      nowEastern.month,
      nowEastern.day,
    );
  }

  /// Get the end of today in Eastern Time
  static DateTime getTodayEndInEastern() {
    _ensureInitialized();
    
    final nowEastern = nowInEastern();
    return tz.TZDateTime(
      _easternLocation,
      nowEastern.year,
      nowEastern.month,
      nowEastern.day,
      23,
      59,
      59,
    );
  }

  /// Schedule a notification for a specific time in Eastern Time
  /// Returns the DateTime when the notification should be sent (in UTC for Cloud Functions)
  static DateTime scheduleForEasternTime(String timeString, {DateTime? onDate}) {
    _ensureInitialized();
    
    final parts = timeString.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time format. Expected HH:mm');
    }
    
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    final dateToUse = onDate != null ? toEastern(onDate) : nowInEastern();
    
    final scheduledTime = tz.TZDateTime(
      _easternLocation,
      dateToUse.year,
      dateToUse.month,
      dateToUse.day,
      hour,
      minute,
    );
    
    // Return in UTC for Cloud Functions
    return scheduledTime.toUtc();
  }

  /// Convert a time string from Eastern to user's local timezone for display
  static String convertEasternTimeToLocalDisplay(String easternTimeString) {
    _ensureInitialized();
    
    // Parse the Eastern time
    final easternTime = parseTimeInEastern(easternTimeString);
    
    // Convert to local
    final localTime = easternToLocal(easternTime);
    
    // Format for display
    return DateFormat('h:mm a').format(localTime);
  }

  /// Get a descriptive string for the timezone offset
  static String getTimezoneOffsetDescription() {
    _ensureInitialized();
    
    final nowEastern = nowInEastern();
    final localNow = DateTime.now();
    
    final difference = localNow.timeZoneOffset.inHours - 
                      (nowEastern as tz.TZDateTime).timeZoneOffset.inHours;
    
    if (difference == 0) {
      return 'Your local time matches Eastern Time';
    } else if (difference > 0) {
      return 'Your local time is $difference hour${difference.abs() == 1 ? '' : 's'} ahead of Eastern Time';
    } else {
      return 'Your local time is ${difference.abs()} hour${difference.abs() == 1 ? '' : 's'} behind Eastern Time';
    }
  }

  /// Ensure timezone data is initialized
  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'TimezoneUtils not initialized. Call TimezoneUtils.initialize() at app startup.',
      );
    }
  }

  /// Format a time for notification display with Eastern Time indicator
  static String formatNotificationTime(String timeString) {
    _ensureInitialized();
    
    final time = parseTimeInEastern(timeString);
    final isDST = _isDaylightSavingTime(time);
    final tzAbbr = isDST ? 'EDT' : 'EST';
    
    // Parse the time string and format it nicely
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    final displayHour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    
    return '$displayHour:$minuteStr $period $tzAbbr';
  }

  /// Check if daylight saving time transition is within the next week
  /// Useful for showing warnings to users about time changes
  static bool isDSTTransitionSoon() {
    _ensureInitialized();
    
    final now = nowInEastern();
    final weekFromNow = now.add(const Duration(days: 7));
    
    // Check if DST status changes within the week
    return _isDaylightSavingTime(now) != _isDaylightSavingTime(weekFromNow);
  }

  /// Get a user-friendly message about DST transition if it's happening soon
  static String? getDSTTransitionMessage() {
    if (!isDSTTransitionSoon()) return null;
    
    final now = nowInEastern();
    final isDSTNow = _isDaylightSavingTime(now);
    
    if (isDSTNow) {
      return 'Daylight Saving Time ends soon. Notification times will remain consistent in Eastern Time.';
    } else {
      return 'Daylight Saving Time begins soon. Notification times will remain consistent in Eastern Time.';
    }
  }
}