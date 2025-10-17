import 'package:intl/intl.dart';

/// Utility class for consistent date and time formatting across the app
/// Eliminates duplicate date formatting logic
class DateTimeUtils {
  // Private constructor to prevent instantiation
  DateTimeUtils._();

  /// Day name abbreviations
  static const List<String> dayAbbreviations = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  /// Month name abbreviations
  static const List<String> monthAbbreviations = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Formats a DateTime for display in vendor posts and events
  /// Returns: "Today at 2:00 PM", "Tomorrow at 10:00 AM", "Wed at 3:30 PM", or "12/25 at 4:00 PM"
  static String formatPostDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final postDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (postDate == today) {
      dateStr = 'Today';
    } else if (postDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else if (postDate.isBefore(today.add(const Duration(days: 7)))) {
      // Within a week - show day name
      dateStr = dayAbbreviations[dateTime.weekday - 1];
    } else {
      // More than a week away - show date
      dateStr = '${dateTime.month}/${dateTime.day}';
    }
    
    final timeStr = formatTime(dateTime);
    return '$dateStr at $timeStr';
  }

  /// Formats just the time portion of a DateTime
  /// Returns: "2:00 PM", "10:30 AM", etc.
  static String formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Formats a date range for display
  /// Returns: "2:00 PM - 5:00 PM" or "Jan 1 2:00 PM - Jan 2 5:00 PM"
  static String formatDateTimeRange(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    
    if (startDate == endDate) {
      // Same day - just show times
      return '${formatTime(start)} - ${formatTime(end)}';
    } else {
      // Different days - show full date and time
      return '${formatShortDate(start)} ${formatTime(start)} - ${formatShortDate(end)} ${formatTime(end)}';
    }
  }

  /// Formats a date in short format
  /// Returns: "Jan 1", "Dec 31", etc.
  static String formatShortDate(DateTime date) {
    return '${monthAbbreviations[date.month - 1]} ${date.day}';
  }

  /// Formats a date in medium format
  /// Returns: "January 1, 2024"
  static String formatMediumDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// Formats a date in long format with day of week
  /// Returns: "Monday, January 1, 2024"
  static String formatLongDate(DateTime date) {
    return DateFormat.yMMMMEEEEd().format(date);
  }

  /// Checks if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  /// Checks if a date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && 
           date.month == tomorrow.month && 
           date.day == tomorrow.day;
  }

  /// Checks if a date is within the current week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekFromNow = today.add(const Duration(days: 7));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    return dateOnly.isAfter(today.subtract(const Duration(days: 1))) && 
           dateOnly.isBefore(weekFromNow);
  }

  /// Gets relative time string (e.g., "2 hours ago", "in 3 days")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.isNegative) {
      // Past
      final absDiff = difference.abs();
      if (absDiff.inMinutes < 1) {
        return 'just now';
      } else if (absDiff.inMinutes < 60) {
        final minutes = absDiff.inMinutes;
        return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
      } else if (absDiff.inHours < 24) {
        final hours = absDiff.inHours;
        return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
      } else if (absDiff.inDays < 7) {
        final days = absDiff.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      } else if (absDiff.inDays < 30) {
        final weeks = (absDiff.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else if (absDiff.inDays < 365) {
        final months = (absDiff.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else {
        final years = (absDiff.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      }
    } else {
      // Future
      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return 'in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return 'in $hours ${hours == 1 ? 'hour' : 'hours'}';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return 'in $days ${days == 1 ? 'day' : 'days'}';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return 'in $weeks ${weeks == 1 ? 'week' : 'weeks'}';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return 'in $months ${months == 1 ? 'month' : 'months'}';
      } else {
        final years = (difference.inDays / 365).floor();
        return 'in $years ${years == 1 ? 'year' : 'years'}';
      }
    }
  }

  /// Formats duration between two times
  /// Returns: "2 hours 30 minutes", "45 minutes", etc.
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'} $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      } else {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      }
    } else {
      final minutes = duration.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
  }

  /// Gets a greeting based on time of day
  /// Returns: "Good morning", "Good afternoon", "Good evening"
  static String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  /// Formats a date for calendar display
  /// Returns: "Mon, Jan 1" or "Today" or "Tomorrow"
  static String formatCalendarDate(DateTime date) {
    if (isToday(date)) {
      return 'Today';
    } else if (isTomorrow(date)) {
      return 'Tomorrow';
    } else {
      return '${dayAbbreviations[date.weekday - 1]}, ${formatShortDate(date)}';
    }
  }

  /// Gets the start of the current week (Monday)
  static DateTime getWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromMonday));
  }

  /// Gets the end of the current week (Sunday)
  static DateTime getWeekEnd() {
    final weekStart = getWeekStart();
    return weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  /// Gets the start of the current month
  static DateTime getMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Gets the end of the current month
  static DateTime getMonthEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  /// Checks if a date range is currently active
  static bool isDateRangeActive(DateTime start, DateTime end) {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Checks if a date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Checks if a date is in the future
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }
}