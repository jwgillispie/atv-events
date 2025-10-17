import 'package:intl/intl.dart';

/// Centralized date formatting utilities for HiPop Markets
///
/// Provides consistent date formatting across the entire application,
/// eliminating code duplication and ensuring uniform user experience.
/// All methods are optimized for marketplace contexts where dates
/// are critical for event scheduling, vendor coordination, and user engagement.
class DateFormatter {
  // Prevent instantiation
  DateFormatter._();

  // ======= Core Date Formats =======

  /// Standard date format: "Jan 15, 2024"
  /// Used for: Event dates, market dates, general date display
  static String formatStandardDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date.toLocal());
  }

  /// Full date with day: "Monday, Jan 15, 2024"
  /// Used for: Event details, market schedules
  static String formatFullDate(DateTime date) {
    return DateFormat('EEEE, MMM d, yyyy').format(date.toLocal());
  }

  /// Short date: "1/15/24"
  /// Used for: Compact displays, tables, lists
  static String formatShortDate(DateTime date) {
    return DateFormat('M/d/yy').format(date.toLocal());
  }

  /// Month and year: "January 2024"
  /// Used for: Monthly analytics, subscription periods
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date.toLocal());
  }

  /// Day and month: "Jan 15"
  /// Used for: Current year events, upcoming markets
  static String formatDayMonth(DateTime date) {
    return DateFormat('MMM d').format(date.toLocal());
  }

  // ======= Time Formats =======

  /// Standard time: "2:30 PM"
  /// Used for: Event times, market hours
  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }

  /// 24-hour time: "14:30"
  /// Used for: Internal operations, API calls
  static String format24HourTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  /// Time from string: Converts "2:30 PM" to formatted time
  static String formatTimeFromString(String timeStr) {
    try {
      // Handle various input formats
      if (timeStr.contains(':')) {
        return timeStr; // Already formatted
      }
      // Add more parsing logic as needed
      return timeStr;
    } catch (e) {
      return timeStr; // Return original if parsing fails
    }
  }

  // ======= Combined Date & Time Formats =======

  /// Full date and time: "Jan 15, 2024 • 2:30 PM"
  /// Used for: Popup creation, event scheduling
  static String formatDateTime(DateTime dateTime) {
    final date = DateFormat('MMM d, yyyy').format(dateTime.toLocal());
    final time = DateFormat('h:mm a').format(dateTime.toLocal());
    return '$date • $time';
  }

  /// Compact date/time: "1/15 2:30PM"
  /// Used for: Notifications, compact displays
  static String formatCompactDateTime(DateTime dateTime) {
    return DateFormat('M/d h:mma').format(dateTime.toLocal());
  }

  /// Day and time: "Monday • 2:30 PM"
  /// Used for: Weekly schedules, recurring events
  static String formatDayTime(DateTime dateTime) {
    final day = DateFormat('EEEE').format(dateTime.toLocal());
    final time = DateFormat('h:mm a').format(dateTime.toLocal());
    return '$day • $time';
  }

  // ======= Relative Time Formats =======

  /// Relative time: "2 hours ago", "in 3 days"
  /// Used for: Social features, recent activity
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  /// Relative time with cutoff: Shows relative for recent, date for older
  /// Used for: Reviews, posts, vendor updates
  static String formatSmartRelative(DateTime dateTime, {int daysThreshold = 7}) {
    final now = DateTime.now();
    final difference = now.difference(dateTime).inDays.abs();

    if (difference <= daysThreshold) {
      return formatRelativeTime(dateTime);
    } else if (dateTime.year == now.year) {
      return formatDayMonth(dateTime);
    } else {
      return formatStandardDate(dateTime);
    }
  }

  /// Short relative: "2h", "3d", "1w"
  /// Used for: Compact timestamps, mobile views
  static String formatShortRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).round()}w';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).round()}mo';
    } else {
      return '${(difference.inDays / 365).round()}y';
    }
  }

  // ======= Range Formats =======

  /// Date range: "Jan 15 - Jan 17, 2024"
  /// Used for: Multi-day events, market seasons
  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year) {
      if (start.month == end.month) {
        // Same month: "Jan 15 - 17, 2024"
        final startDay = DateFormat('MMM d').format(start.toLocal());
        final endDay = DateFormat('d, yyyy').format(end.toLocal());
        return '$startDay - $endDay';
      } else {
        // Different months: "Jan 15 - Feb 17, 2024"
        final startDate = DateFormat('MMM d').format(start.toLocal());
        final endDate = DateFormat('MMM d, yyyy').format(end.toLocal());
        return '$startDate - $endDate';
      }
    } else {
      // Different years: "Dec 31, 2023 - Jan 2, 2024"
      final startDate = formatStandardDate(start);
      final endDate = formatStandardDate(end);
      return '$startDate - $endDate';
    }
  }

  /// Time range: "2:00 PM - 6:00 PM"
  /// Used for: Market hours, vendor availability
  static String formatTimeRange(DateTime start, DateTime end) {
    final startTime = formatTime(start);
    final endTime = formatTime(end);
    return '$startTime - $endTime';
  }

  /// Time range from strings
  static String formatTimeRangeFromStrings(String startTime, String endTime) {
    return '$startTime - $endTime';
  }

  /// Event schedule: "Saturday, Jan 15 • 2:00 PM - 6:00 PM"
  /// Used for: Market detail screens, event cards
  static String formatEventSchedule(DateTime date, String startTime, String endTime) {
    final dateStr = DateFormat('EEEE, MMM d').format(date.toLocal());
    return '$dateStr • $startTime - $endTime';
  }

  // ======= Duration Formats =======

  /// Duration: "2 hours", "45 minutes"
  /// Used for: Event durations, estimated times
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      final days = duration.inDays;
      return '$days ${days == 1 ? 'day' : 'days'}';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      final minutes = duration.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }

  /// Compact duration: "2h 30m"
  /// Used for: Timers, countdowns
  static String formatCompactDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  // ======= Validation & Parsing =======

  /// Parse date string safely with fallback
  static DateTime? parseDate(String dateStr, {DateTime? fallback}) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return fallback;
    }
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Check if date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
           date.month == tomorrow.month &&
           date.day == tomorrow.day;
  }

  /// Check if date is this week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
           date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// Check if date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Check if date is in the future
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }

  // ======= Special Marketplace Formats =======

  /// Market schedule format: "Every Saturday • 9:00 AM - 2:00 PM"
  /// Used for: Recurring market displays
  static String formatRecurringSchedule(String dayOfWeek, String startTime, String endTime) {
    return 'Every $dayOfWeek • $startTime - $endTime';
  }

  /// Vendor availability: "Available Jan 15-17"
  /// Used for: Vendor profiles, availability indicators
  static String formatAvailability(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      final month = DateFormat('MMM').format(start.toLocal());
      return 'Available $month ${start.day}-${end.day}';
    }
    return 'Available ${formatDateRange(start, end)}';
  }

  /// Next occurrence: "Next Saturday at 2:00 PM"
  /// Used for: Upcoming events, reminders
  static String formatNextOccurrence(DateTime date) {
    if (isToday(date)) {
      return 'Today at ${formatTime(date)}';
    } else if (isTomorrow(date)) {
      return 'Tomorrow at ${formatTime(date)}';
    } else if (isThisWeek(date)) {
      final day = DateFormat('EEEE').format(date.toLocal());
      return 'This $day at ${formatTime(date)}';
    } else {
      return '${formatStandardDate(date)} at ${formatTime(date)}';
    }
  }

  /// Countdown format: "2 days, 3 hours until market opens"
  /// Used for: Event countdowns, urgency indicators
  static String formatCountdown(DateTime target) {
    final now = DateTime.now();
    final difference = target.difference(now);

    if (difference.isNegative) {
      return 'Event has passed';
    }

    if (difference.inDays > 0) {
      final days = difference.inDays;
      final hours = difference.inHours.remainder(24);
      return '$days ${days == 1 ? 'day' : 'days'}, $hours ${hours == 1 ? 'hour' : 'hours'} remaining';
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);
      return '$hours ${hours == 1 ? 'hour' : 'hours'}, $minutes ${minutes == 1 ? 'minute' : 'minutes'} remaining';
    } else {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} remaining';
    }
  }

  /// Business hours format: "Mon-Fri: 9AM-5PM, Sat: 10AM-2PM"
  /// Used for: Vendor hours, market information
  static String formatBusinessHours(Map<String, String> hours) {
    final formatted = hours.entries.map((entry) {
      return '${entry.key}: ${entry.value}';
    }).join(', ');
    return formatted;
  }
}