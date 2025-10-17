/// Shared date range utility for analytics services
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  factory DateRange.lastDays(int days) {
    final now = DateTime.now();
    return DateRange(
      start: now.subtract(Duration(days: days)),
      end: now,
    );
  }

  factory DateRange.thisMonth() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  factory DateRange.lastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    return DateRange(
      start: lastMonth,
      end: DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59),
    );
  }
  
  factory DateRange.thisWeek() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfWeek = now.subtract(Duration(days: weekday - 1));
    return DateRange(
      start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }
  
  factory DateRange.lastWeek() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfLastWeek = now.subtract(Duration(days: weekday + 6));
    final endOfLastWeek = startOfLastWeek.add(const Duration(days: 6));
    return DateRange(
      start: DateTime(startOfLastWeek.year, startOfLastWeek.month, startOfLastWeek.day),
      end: DateTime(endOfLastWeek.year, endOfLastWeek.month, endOfLastWeek.day, 23, 59, 59),
    );
  }
  
  factory DateRange.thisYear() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, 1, 1),
      end: DateTime(now.year, 12, 31, 23, 59, 59),
    );
  }
  
  factory DateRange.custom(DateTime start, DateTime end) {
    return DateRange(start: start, end: end);
  }
  
  int get daysInRange => end.difference(start).inDays;
  
  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }
  
  bool overlaps(DateRange other) {
    return start.isBefore(other.end) && end.isAfter(other.start);
  }
}