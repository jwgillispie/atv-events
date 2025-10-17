import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../../shared/widgets/common/loading_widget.dart';

/// Organizer Earnings Dashboard
/// Displays ticket sales revenue and statistics for market organizers
class OrganizerEarningsScreen extends StatefulWidget {
  const OrganizerEarningsScreen({super.key});

  @override
  State<OrganizerEarningsScreen> createState() => _OrganizerEarningsScreenState();
}

class _OrganizerEarningsScreenState extends State<OrganizerEarningsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _organizerId = FirebaseAuth.instance.currentUser?.uid;

  // Revenue tracking
  double _totalRevenue = 0.0;
  double _totalPlatformFees = 0.0;
  int _totalTicketsSold = 0;
  int _totalEvents = 0;

  // Period selection
  String _selectedPeriod = 'month'; // month, week, all
  bool _isLoading = true;

  // Event-specific stats
  List<EventStats> _eventStats = [];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    if (_organizerId == null) return;

    setState(() => _isLoading = true);

    try {
      // Get date range based on selected period
      DateTime startDate;
      final now = DateTime.now();

      switch (_selectedPeriod) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(2020); // All time
      }

      // Get all events for this organizer
      final eventsQuery = await _firestore
          .collection('events')
          .where('organizerId', isEqualTo: _organizerId)
          .get();

      double totalRevenue = 0.0;
      double totalActualRevenue = 0.0;
      double totalFees = 0.0;
      int totalTickets = 0;
      int totalAttendees = 0;
      List<EventStats> eventStatsList = [];

      for (var eventDoc in eventsQuery.docs) {
        final eventData = eventDoc.data();
        final eventName = eventData['name'] ?? 'Unnamed Event';
        final eventDate = (eventData['startDateTime'] as Timestamp).toDate();

        // Filter by date range
        if (eventDate.isBefore(startDate)) continue;

        final ticketsSold = (eventData['totalTicketsSold'] ?? 0) as int;
        final revenue = (eventData['totalRevenue'] ?? 0.0).toDouble();
        final attendees = (eventData['totalAttendees'] ?? 0) as int;
        final actualRevenue = (eventData['actualRevenue'] ?? 0.0).toDouble();

        // Only include events with ticket sales
        if (ticketsSold == 0 && revenue == 0) continue;

        // Platform fee is 6%
        final platformFees = revenue * 0.06;

        eventStatsList.add(EventStats(
          eventId: eventDoc.id,
          eventName: eventName,
          eventDate: eventDate,
          ticketsSold: ticketsSold,
          revenue: revenue,
          platformFees: platformFees,
          attendees: attendees,
          actualRevenue: actualRevenue,
        ));

        totalRevenue += revenue;
        totalActualRevenue += actualRevenue;
        totalFees += platformFees;
        totalTickets += ticketsSold;
        totalAttendees += attendees;
      }

      // Sort events by date (most recent first)
      eventStatsList.sort((a, b) => b.eventDate.compareTo(a.eventDate));

      setState(() {
        _totalRevenue = totalRevenue;
        _totalPlatformFees = totalFees;
        _totalTicketsSold = totalTickets;
        _totalEvents = eventStatsList.length;
        _eventStats = eventStatsList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading earnings: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_organizerId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view earnings'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Ticket Sales & Earnings'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : RefreshIndicator(
              onRefresh: _loadEarnings,
              color: HiPopColors.organizerAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Period Selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: HiPopColors.darkSurface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPeriodChip('Week', 'week'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('Month', 'month'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('All Time', 'all'),
                        ],
                      ),
                    ),

                    // Revenue Dashboard - Horizontal Cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildHorizontalStatCard(
                            title: 'Gross Revenue',
                            value: '\$${_totalRevenue.toStringAsFixed(2)}',
                            icon: Icons.attach_money,
                            color: HiPopColors.successGreen,
                          ),
                          const SizedBox(height: 12),
                          _buildHorizontalStatCard(
                            title: 'Platform Fees',
                            value: '\$${_totalPlatformFees.toStringAsFixed(2)}',
                            subtitle: '6% fee',
                            icon: Icons.account_balance,
                            color: HiPopColors.warningAmber,
                          ),
                          const SizedBox(height: 12),
                          _buildHorizontalStatCard(
                            title: 'Net Earnings',
                            value: '\$${(_totalRevenue - _totalPlatformFees).toStringAsFixed(2)}',
                            icon: Icons.wallet,
                            color: HiPopColors.organizerAccent,
                          ),
                          const SizedBox(height: 12),
                          _buildHorizontalStatCard(
                            title: 'Tickets Sold',
                            value: _totalTicketsSold.toString(),
                            subtitle: '${_totalEvents} events',
                            icon: Icons.confirmation_number,
                            color: HiPopColors.primaryDeepSage,
                          ),
                        ],
                      ),
                    ),

                    // Average Metrics
                    if (_totalEvents > 0) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Average Metrics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              color: HiPopColors.darkSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: HiPopColors.darkBorder.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildMetric(
                                      'Avg per Event',
                                      '\$${(_totalRevenue / _totalEvents).toStringAsFixed(2)}',
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                                    ),
                                    _buildMetric(
                                      'Avg Ticket',
                                      '\$${(_totalRevenue / _totalTicketsSold).toStringAsFixed(2)}',
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                                    ),
                                    _buildMetric(
                                      'Avg Attendance',
                                      '${(_totalTicketsSold / _totalEvents).round()}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Event Breakdown
                    if (_eventStats.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Event Breakdown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._eventStats.map((event) => _buildEventCard(event)),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: HiPopColors.darkSurface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.event_busy,
                                size: 48,
                                color: HiPopColors.darkTextTertiary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No ticket sales in this period',
                              style: TextStyle(
                                fontSize: 16,
                                color: HiPopColors.darkTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create events with tickets to start earning',
                              style: TextStyle(
                                fontSize: 14,
                                color: HiPopColors.darkTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = value;
          });
          _loadEarnings();
        }
      },
      selectedColor: HiPopColors.organizerAccent,
      backgroundColor: HiPopColors.darkSurface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : HiPopColors.darkTextSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildHorizontalStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.darkTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: HiPopColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventStats event) {
    final netEarnings = event.revenue - event.platformFees;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.eventName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, y').format(event.eventDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HiPopColors.organizerAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${event.ticketsSold} tickets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.organizerAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Attendance Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.darkBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${event.ticketsSold}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.primaryDeepSage,
                        ),
                      ),
                      Text(
                        'Sold',
                        style: TextStyle(
                          fontSize: 11,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        '${event.attendees}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.successGreen,
                        ),
                      ),
                      Text(
                        'Checked In',
                        style: TextStyle(
                          fontSize: 11,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        '${event.ticketsSold > 0 ? ((event.attendees / event.ticketsSold * 100).toStringAsFixed(0)) : 0}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.warningAmber,
                        ),
                      ),
                      Text(
                        'Show Rate',
                        style: TextStyle(
                          fontSize: 11,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Revenue Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.darkBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gross Revenue',
                        style: TextStyle(
                          fontSize: 11,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                      Text(
                        '\$${event.revenue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform Fee',
                        style: TextStyle(
                          fontSize: 11,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                      Text(
                        '-\$${event.platformFees.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Net Earnings',
                        style: TextStyle(
                          fontSize: 11,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                      Text(
                        '\$${netEarnings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventStats {
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final int ticketsSold;
  final double revenue;
  final double platformFees;
  final int attendees;
  final double actualRevenue;

  EventStats({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.ticketsSold,
    required this.revenue,
    required this.platformFees,
    required this.attendees,
    required this.actualRevenue,
  });
}