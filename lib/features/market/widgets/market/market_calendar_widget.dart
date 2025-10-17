import 'package:flutter/material.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';

class MarketCalendarWidget extends StatefulWidget {
  final List<VendorPost> posts;
  final Function(DateTime date, List<VendorPost> postsForDay)? onDateSelected;

  const MarketCalendarWidget({
    super.key,
    required this.posts,
    this.onDateSelected,
  });

  @override
  State<MarketCalendarWidget> createState() => _MarketCalendarWidgetState();
}

class _MarketCalendarWidgetState extends State<MarketCalendarWidget> {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;
  late Map<DateTime, List<VendorPost>> _postsByDate;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
    _buildPostsByDate();
  }

  @override
  void didUpdateWidget(MarketCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posts != widget.posts) {
      _buildPostsByDate();
    }
  }

  void _buildPostsByDate() {
    _postsByDate = <DateTime, List<VendorPost>>{};
    
    for (final post in widget.posts) {
      final startDate = DateTime(
        post.popUpStartDateTime.year,
        post.popUpStartDateTime.month,
        post.popUpStartDateTime.day,
      );
      
      // If it's a multi-day event, add it to all days
      final endDate = DateTime(
        post.popUpEndDateTime.year,
        post.popUpEndDateTime.month,
        post.popUpEndDateTime.day,
      );
      
      DateTime currentDate = startDate;
      while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
        _postsByDate[currentDate] = _postsByDate[currentDate] ?? [];
        _postsByDate[currentDate]!.add(post);
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCalendarHeader(),
        _buildCalendarGrid(),
        if (_selectedDate != null) _buildSelectedDateEvents(),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month - 1,
                );
              });
            },
            icon: const Icon(Icons.arrow_back_ios),
          ),
          Text(
            '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month + 1,
                );
              });
            },
            icon: const Icon(Icons.arrow_forward_ios),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startOfCalendar = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));
    final endOfCalendar = lastDayOfMonth.add(Duration(days: 6 - lastDayOfMonth.weekday % 7));

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Days of week header
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // Calendar grid
          ...List.generate(
            ((endOfCalendar.difference(startOfCalendar).inDays + 1) / 7).ceil(),
            (weekIndex) {
              return Row(
                children: List.generate(7, (dayIndex) {
                  final date = startOfCalendar.add(Duration(days: weekIndex * 7 + dayIndex));
                  final isCurrentMonth = date.month == _focusedMonth.month;
                  final isToday = _isSameDay(date, DateTime.now());
                  final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
                  final hasEvents = _postsByDate[date] != null && _postsByDate[date]!.isNotEmpty;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                        if (widget.onDateSelected != null) {
                          widget.onDateSelected!(date, _postsByDate[date] ?? []);
                        }
                      },
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.orange
                              : isToday
                                  ? Colors.orange.shade100
                                  : hasEvents
                                      ? Colors.green.shade50
                                      : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !isSelected
                              ? Border.all(color: Colors.orange, width: 2)
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : isCurrentMonth
                                          ? Colors.black87
                                          : Colors.grey[400],
                                  fontWeight: isToday || hasEvents
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (hasEvents && !isSelected)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            if (hasEvents && !isSelected && _postsByDate[date]!.length > 1)
                              Positioned(
                                bottom: 4,
                                right: 12,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade300,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateEvents() {
    final selectedPosts = _postsByDate[_selectedDate!] ?? [];
    
    if (selectedPosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No events on ${_formatDate(_selectedDate!)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Events on ${_formatDate(_selectedDate!)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...selectedPosts.map((post) => _buildEventTile(post)),
        ],
      ),
    );
  }

  Widget _buildEventTile(VendorPost post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.vendorName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: post.isHappening
                      ? Colors.green.shade100
                      : post.isUpcoming
                          ? Colors.orange.shade100
                          : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  post.isHappening
                      ? 'LIVE NOW'
                      : post.isUpcoming
                          ? 'UPCOMING'
                          : 'ENDED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: post.isHappening
                        ? Colors.green.shade700
                        : post.isUpcoming
                            ? Colors.orange.shade700
                            : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            post.formattedTimeRange,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (post.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              post.description,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}