import '../../market/models/market.dart';

class MarketEvent {
  final String id;
  final String marketId;
  final String marketName;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final String timeRange;

  const MarketEvent({
    required this.id,
    required this.marketId,
    required this.marketName,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.timeRange,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MarketCalendarService {
  /// Convert markets to calendar events for a specific date range
  /// In the new 1:1 system, each market is a single event
  static Future<List<MarketEvent>> getMarketEventsForDateRange(
    List<Market> markets,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final List<MarketEvent> events = [];
    
    for (final market in markets) {
      // Check if market event date falls within the requested range
      if (market.eventDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          market.eventDate.isBefore(endDate.add(const Duration(days: 1)))) {
        
        events.add(MarketEvent(
          id: market.id,
          marketId: market.id,
          marketName: market.name,
          eventDate: market.eventDate,
          startTime: market.startTime,
          endTime: market.endTime,
          timeRange: market.timeRange,
        ));
      }
    }
    
    // Sort by event date
    events.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    
    return events;
  }

  /// Get market events for a specific date
  static Future<List<MarketEvent>> getMarketEventsForDate(
    List<Market> markets,
    DateTime date,
  ) {
    return getMarketEventsForDateRange(markets, date, date);
  }

  /// Get all upcoming market events
  static Future<List<MarketEvent>> getUpcomingMarketEvents(
    List<Market> markets, {
    int daysAhead = 30,
  }) {
    final today = DateTime.now();
    final endDate = today.add(Duration(days: daysAhead));
    return getMarketEventsForDateRange(markets, today, endDate);
  }

  /// Check if a market event is happening today
  static bool isMarketHappeningToday(Market market) {
    final today = DateTime.now();
    return market.eventDate.year == today.year &&
           market.eventDate.month == today.month &&
           market.eventDate.day == today.day;
  }

  /// Check if a market event is in the future
  static bool isMarketUpcoming(Market market) {
    return market.eventDate.isAfter(DateTime.now());
  }

  /// Check if a market event is in the past
  static bool isMarketPast(Market market) {
    return market.eventDate.isBefore(DateTime.now());
  }

  /// Group market events by date
  static Map<DateTime, List<MarketEvent>> groupEventsByDate(List<MarketEvent> events) {
    final Map<DateTime, List<MarketEvent>> groupedEvents = {};
    
    for (final event in events) {
      final dateKey = DateTime(event.eventDate.year, event.eventDate.month, event.eventDate.day);
      if (!groupedEvents.containsKey(dateKey)) {
        groupedEvents[dateKey] = [];
      }
      groupedEvents[dateKey]!.add(event);
    }
    
    return groupedEvents;
  }

  /// Get events for a specific day
  static List<MarketEvent> getEventsForDay(List<MarketEvent> events, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    return events.where((event) {
      final eventDay = DateTime(event.eventDate.year, event.eventDate.month, event.eventDate.day);
      return eventDay.isAtSameMomentAs(dayStart);
    }).toList();
  }

  /// Check if a market is currently open (happening right now)
  static bool isMarketCurrentlyOpen(Market market) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final marketDay = DateTime(market.eventDate.year, market.eventDate.month, market.eventDate.day);
    
    // Check if it's the right day
    if (!marketDay.isAtSameMomentAs(today)) {
      return false;
    }
    
    // Parse start and end times and check if current time is within range
    try {
      final startHour = _parseTime(market.startTime);
      final endHour = _parseTime(market.endTime);
      final currentHour = now.hour + (now.minute / 60.0);
      
      return currentHour >= startHour && currentHour <= endHour;
    } catch (e) {
      return false;
    }
  }

  /// Get formatted day name
  static String getDayName(DateTime date) {
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return dayNames[date.weekday - 1];
  }

  /// Format time range for display
  static String formatTimeRange(String startTime, String endTime) {
    return '$startTime - $endTime';
  }

  /// Parse time string to hour (e.g., "9:00 AM" -> 9.0, "2:30 PM" -> 14.5)
  static double _parseTime(String timeString) {
    final timeParts = timeString.toLowerCase().replaceAll(' ', '').split(':');
    if (timeParts.length != 2) throw FormatException('Invalid time format');
    
    final hourPart = timeParts[0];
    final minuteAndPeriod = timeParts[1];
    
    final hour = int.parse(hourPart);
    final isPM = minuteAndPeriod.contains('pm');
    final minute = int.parse(minuteAndPeriod.replaceAll(RegExp(r'[apm]'), ''));
    
    double adjustedHour = hour.toDouble();
    if (isPM && hour != 12) {
      adjustedHour += 12;
    } else if (!isPM && hour == 12) {
      adjustedHour = 0;
    }
    
    return adjustedHour + (minute / 60.0);
  }
}