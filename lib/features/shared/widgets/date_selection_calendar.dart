import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class DateSelectionCalendar extends StatefulWidget {
  final List<DateTime> initialSelectedDates;
  final Function(List<DateTime>) onDatesChanged;
  final DateTime? firstDay;
  final DateTime? lastDay;
  final String title;

  const DateSelectionCalendar({
    super.key,
    required this.initialSelectedDates,
    required this.onDatesChanged,
    this.firstDay,
    this.lastDay,
    this.title = 'Select Dates',
  });

  @override
  State<DateSelectionCalendar> createState() => _DateSelectionCalendarState();
}

class _DateSelectionCalendarState extends State<DateSelectionCalendar> {
  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;
  late Set<DateTime> _selectedDates;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _firstDay = widget.firstDay ?? DateTime.now();
    _lastDay = widget.lastDay ?? DateTime.now().add(const Duration(days: 365));
    
    // Convert initial dates to normalized dates (without time)
    _selectedDates = widget.initialSelectedDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSelected(DateTime day) {
    return _selectedDates.any((selectedDate) => _isSameDay(selectedDate, day));
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final normalizedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    
    setState(() {
      _focusedDay = focusedDay;
      
      if (_isSelected(selectedDay)) {
        // Remove the date if it's already selected
        _selectedDates.removeWhere((date) => _isSameDay(date, selectedDay));
      } else {
        // Add the date if it's not selected
        _selectedDates.add(normalizedDay);
      }
    });
    
    // Notify parent of the change
    final sortedDates = _selectedDates.toList()..sort();
    widget.onDatesChanged(sortedDates);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TableCalendar<DateTime>(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            rangeSelectionMode: RangeSelectionMode.disabled,
            eventLoader: (day) {
              return _isSelected(day) ? [day] : [];
            },
            startingDayOfWeek: StartingDayOfWeek.sunday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: Colors.red),
              holidayTextStyle: const TextStyle(color: Colors.red),
              selectedDecoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.green.shade200,
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              markersMaxCount: 1,
              markerDecoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            selectedDayPredicate: (day) => _isSelected(day),
          ),
        ),
        if (_selectedDates.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Dates (${_selectedDates.length}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedDates.map((date) {
                    return Chip(
                      label: Text(
                        '${date.month}/${date.day}/${date.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.green.shade100,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedDates.remove(date);
                        });
                        final updatedDates = _selectedDates.toList()..sort();
                        widget.onDatesChanged(updatedDates);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}