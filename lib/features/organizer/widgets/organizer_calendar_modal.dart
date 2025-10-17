import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/shared/models/event.dart';
import 'package:hipop/features/shared/services/data/event_service.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';

/// OrganizerCalendarModal - Premium calendar view for market organizers
/// Displays both markets and events in an elegant Material Design 3 interface
/// Provides comprehensive scheduling overview with interactive date selection
class OrganizerCalendarModal extends StatefulWidget {
  const OrganizerCalendarModal({super.key});

  @override
  State<OrganizerCalendarModal> createState() => _OrganizerCalendarModalState();
}

class _OrganizerCalendarModalState extends State<OrganizerCalendarModal> {
  // Calendar state
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Data state
  final String? _organizerId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = true;
  List<Market> _markets = [];
  List<Event> _events = [];
  final Map<DateTime, List<dynamic>> _eventMap = {};

  // Selected day events
  List<dynamic> _selectedDayItems = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadOrganizerData();
  }

  Future<void> _loadOrganizerData() async {
    if (_organizerId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load markets
      final marketsSnapshot = await FirebaseFirestore.instance
          .collection('markets')
          .where('organizerId', isEqualTo: _organizerId)
          .orderBy('eventDate')
          .get();

      _markets = marketsSnapshot.docs
          .map((doc) => Market.fromFirestore(doc))
          .toList();

      // Load events using EventService stream
      EventService.getEventsByOrganizerStream(_organizerId!).listen((events) {
        if (mounted) {
          setState(() {
            _events = events;
            _buildEventMap();
            _updateSelectedDayItems();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _buildEventMap() {
    _eventMap.clear();

    // Add markets to event map
    for (final market in _markets) {
      final date = _normalizeDate(market.eventDate);
      _eventMap[date] ??= [];
      _eventMap[date]!.add(market);
    }

    // Add events to event map
    for (final event in _events) {
      final date = _normalizeDate(event.startDateTime);
      _eventMap[date] ??= [];
      _eventMap[date]!.add(event);

      // If event spans multiple days, add to each day
      if (event.endDateTime != null &&
          !_isSameDay(event.startDateTime, event.endDateTime!)) {
        DateTime currentDate = event.startDateTime.add(const Duration(days: 1));
        while (currentDate.isBefore(event.endDateTime!) ||
               _isSameDay(currentDate, event.endDateTime!)) {
          final normalizedDate = _normalizeDate(currentDate);
          _eventMap[normalizedDate] ??= [];
          _eventMap[normalizedDate]!.add(event);
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _updateSelectedDayItems() {
    final normalizedSelected = _normalizeDate(_selectedDay);
    _selectedDayItems = _eventMap[normalizedSelected] ?? [];
    _selectedDayItems.sort((a, b) {
      final aDate = a is Market ? a.eventDate : (a as Event).startDateTime;
      final bDate = b is Market ? b.eventDate : (b as Event).startDateTime;
      return aDate.compareTo(bDate);
    });
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _eventMap[_normalizeDate(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: HiPopColors.darkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: HiPopColors.darkTextTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        HiPopColors.organizerAccent,
                        HiPopColors.accentMauve,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Event Calendar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    Text(
                      'Markets & Events Overview',
                      style: TextStyle(
                        fontSize: 14,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: HiPopColors.darkTextTertiary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Markets', HiPopColors.organizerAccent),
                const SizedBox(width: 24),
                _buildLegendItem('Events', HiPopColors.successGreen),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content area
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingWidget(message: 'Loading calendar...'))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Calendar
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: HiPopColors.darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                            ),
                          ),
                          child: TableCalendar(
                            firstDay: DateTime.now().subtract(const Duration(days: 365)),
                            lastDay: DateTime.now().add(const Duration(days: 365)),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            eventLoader: _getEventsForDay,
                            startingDayOfWeek: StartingDayOfWeek.sunday,
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              weekendTextStyle: const TextStyle(
                                color: HiPopColors.darkTextSecondary,
                              ),
                              defaultTextStyle: const TextStyle(
                                color: HiPopColors.darkTextPrimary,
                              ),
                              selectedDecoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    HiPopColors.organizerAccent,
                                    HiPopColors.accentMauve,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              selectedTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              todayDecoration: BoxDecoration(
                                color: HiPopColors.organizerAccent.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: TextStyle(
                                color: HiPopColors.organizerAccent,
                                fontWeight: FontWeight.bold,
                              ),
                              markerDecoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              markersMaxCount: 3,
                              markersAlignment: Alignment.bottomCenter,
                              markerMargin: const EdgeInsets.only(top: 5),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: true,
                              titleCentered: true,
                              formatButtonShowsNext: false,
                              formatButtonDecoration: BoxDecoration(
                                color: HiPopColors.organizerAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              formatButtonTextStyle: TextStyle(
                                color: HiPopColors.organizerAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              titleTextStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                              leftChevronIcon: Icon(
                                Icons.chevron_left,
                                color: HiPopColors.organizerAccent,
                              ),
                              rightChevronIcon: Icon(
                                Icons.chevron_right,
                                color: HiPopColors.organizerAccent,
                              ),
                            ),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                                _updateSelectedDayItems();
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              _focusedDay = focusedDay;
                            },
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, events) {
                                if (events.isEmpty) return null;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int i = 0; i < events.length && i < 3; i++)
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: events[i] is Market
                                              ? HiPopColors.organizerAccent
                                              : HiPopColors.successGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Selected day events
                        if (_selectedDayItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event,
                                      color: HiPopColors.organizerAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, MMMM d').format(_selectedDay),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: HiPopColors.darkTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: HiPopColors.organizerAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_selectedDayItems.length} ${_selectedDayItems.length == 1 ? 'item' : 'items'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: HiPopColors.organizerAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._selectedDayItems.map((item) => _buildEventItem(item)),
                              ],
                            ),
                          ),
                        ] else if (!_isLoading) ...[
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 48,
                                  color: HiPopColors.darkTextTertiary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No events on ${DateFormat('MMM d').format(_selectedDay)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: HiPopColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: HiPopColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEventItem(dynamic item) {
    final bool isMarket = item is Market;
    final String title = isMarket ? item.name : (item as Event).name;
    final String time = isMarket
        ? item.timeRange
        : DateFormat('h:mm a').format(item.startDateTime);
    final IconData icon = isMarket ? Icons.storefront : Icons.celebration;
    final Color color = isMarket ? HiPopColors.organizerAccent : HiPopColors.successGreen;
    final String? location = isMarket
        ? item.fullAddress
        : item.address;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            if (isMarket) {
              context.push('/organizer/edit-market/${item.id}');
            } else {
              context.push('/organizer/edit-event/${item.id}');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: HiPopColors.darkTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 13,
                              color: HiPopColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (location != null && location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: HiPopColors.darkTextTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: HiPopColors.darkTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}