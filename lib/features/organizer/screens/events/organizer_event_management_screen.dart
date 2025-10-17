import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/models/event.dart';
import 'package:hipop/features/shared/services/data/event_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'create_event_screen.dart';
import 'edit_event_screen.dart';
import 'ticket_scanner_screen.dart';
import '../../../premium/screens/subscription_management_screen.dart';

class OrganizerEventManagementScreen extends StatefulWidget {
  const OrganizerEventManagementScreen({super.key});

  @override
  State<OrganizerEventManagementScreen> createState() => _OrganizerEventManagementScreenState();
}

class _OrganizerEventManagementScreenState extends State<OrganizerEventManagementScreen> {
  Stream<List<Event>>? _eventsStream;
  StreamSubscription<List<Event>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeEvents();
  }

  @override
  void dispose() {
    // Cancel stream subscription to prevent memory leaks
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    
    // Clear stream reference
    _eventsStream = null;
    
    super.dispose();
  }

  void _initializeEvents() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      setState(() {
        _eventsStream = EventService.getEventsByOrganizerStream(authState.user.uid);
      });
    }
  }

Future<void> _checkAndCreateEvent() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    // Check if organizer can create event
    final canCreate = await EventService.canOrganizerCreateEvent(authState.user.uid);
    if (!mounted) return;
    
    if (!canCreate) {
      _showEventLimitDialog();
    } else {
      _showCreateEventDialog(context);
    }
  }

  void _showEventLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkBackground,
        title: Row(
          children: [
            Icon(Icons.warning, color: HiPopColors.warningAmber),
            const SizedBox(width: 8),
            const Text(
              'Event Limit Reached',
              style: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached your monthly limit of 1 event.',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HiPopColors.primaryDeepSage),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: HiPopColors.primaryDeepSage, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Unlimited events per month\n'
                    '• Advanced event features\n'
                    '• Priority support\n'
                    '• Analytics & insights',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SubscriptionManagementScreen(
                      userId: authState.user.uid,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is! Authenticated) {
            return Center(
              child: Text(
                'Not authenticated',
                style: TextStyle(color: HiPopColors.darkTextSecondary),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Create Event Button - Full width with consistent margins
                    _buildCreateEventButton(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage and monitor your active events',
                        style: TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              StreamBuilder<List<Event>>(
                stream: _eventsStream,
                builder: (context, snapshot) {
                  // Add mounted check to prevent disposal issues
                  if (!mounted) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(60),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.organizerAccent),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: HiPopColors.darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: HiPopColors.errorPlum.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: HiPopColors.errorPlum.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  size: 32,
                                  color: HiPopColors.errorPlum,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading events',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: HiPopColors.darkTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final events = snapshot.data ?? [];

                  if (events.isEmpty) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: HiPopColors.darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: HiPopColors.darkBorder.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: HiPopColors.organizerAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.event_note_rounded,
                                  size: 40,
                                  color: HiPopColors.organizerAccent.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No events yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: HiPopColors.darkTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first event to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _showCreateEventDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Create Event'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: HiPopColors.organizerAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = events[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildEventCard(event),
                          );
                        },
                        childCount: events.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }


  void _showCreateEventDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEventScreen()),
    );
  }

  Widget _buildCreateEventButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HiPopColors.organizerAccent,
            HiPopColors.organizerAccentDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.organizerAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _checkAndCreateEvent,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_circle_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Event',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Start a special event for your markets',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Determine event status and colors
    IconData eventIcon;
    Color iconColor;
    Color statusColor;

    if (event.isCurrentlyActive) {
      eventIcon = Icons.event_available_rounded;
      iconColor = HiPopColors.successGreen;
      statusColor = HiPopColors.successGreen;
    } else if (event.isUpcoming) {
      eventIcon = Icons.schedule_rounded;
      iconColor = HiPopColors.infoBlueGray;
      statusColor = HiPopColors.infoBlueGray;
    } else {
      eventIcon = Icons.event_busy_rounded;
      iconColor = HiPopColors.darkTextTertiary;
      statusColor = HiPopColors.darkTextTertiary;
    }

    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: event.isCurrentlyActive
            ? statusColor.withValues(alpha: 0.3)
            : HiPopColors.darkBorder.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: event.isCurrentlyActive
              ? statusColor.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEventDetails(event),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with title having full width, menu on right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon container
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            iconColor.withValues(alpha: 0.2),
                            iconColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        eventIcon,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title with full width
                    Expanded(
                      child: Text(
                        event.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Options menu
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleEventAction(event, value),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: HiPopColors.darkTextTertiary,
                      ),
                      itemBuilder: (context) => [
                        if (event.isCurrentlyActive || event.isUpcoming)
                          const PopupMenuItem(
                            value: 'checkin',
                            child: Row(
                              children: [
                                Icon(Icons.qr_code_scanner, size: 18),
                                SizedBox(width: 12),
                                Text('Check-in'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: event.isActive ? 'deactivate' : 'activate',
                          child: Row(
                            children: [
                              Icon(
                                event.isActive ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(event.isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: HiPopColors.errorPlum),
                              SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: HiPopColors.errorPlum)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Date and time info
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      dateFormat.format(event.startDateTime),
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 13,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      timeFormat.format(event.startDateTime),
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
                // Ticket info and analytics
                if (event.hasTicketing) ...[
                  const SizedBox(height: 12),
                  // Ticket sales analytics
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HiPopColors.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tickets Sold',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: HiPopColors.darkTextTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${event.totalTicketsSold ?? 0}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: HiPopColors.darkTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Checked In',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: HiPopColors.darkTextTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${event.totalAttendees ?? 0}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: HiPopColors.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Revenue',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: HiPopColors.darkTextTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '\$${(event.totalRevenue ?? 0).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: HiPopColors.organizerAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // QR Scanner button - full width
                  if (event.isCurrentlyActive || event.isUpcoming)
                    GestureDetector(
                      onTap: () => _navigateToScanner(event),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              HiPopColors.organizerAccent,
                              HiPopColors.organizerAccentDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Scan Tickets',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleEventAction(Event event, String action) {
    switch (action) {
      case 'checkin':
        _navigateToScanner(event);
        break;
      case 'edit':
        _showEditEventDialog(event);
        break;
      case 'activate':
      case 'deactivate':
        _toggleEventStatus(event);
        break;
      case 'delete':
        _showDeleteConfirmation(event);
        break;
    }
  }

  void _navigateToScanner(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TicketScannerScreen(
          eventId: event.id,
          eventTitle: event.name,
        ),
      ),
    );
  }

  void _showEditEventDialog(Event event) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditEventScreen(event: event),
      ),
    );
  }

  void _showEventDetails(Event event) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Event header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: HiPopColors.warningAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      event.isCurrentlyActive ? Icons.event_available :
                      event.isUpcoming ? Icons.schedule : Icons.event_busy,
                      color: HiPopColors.warningAmber,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: event.isCurrentlyActive ? HiPopColors.successGreen :
                                   event.isUpcoming ? HiPopColors.infoBlueGray : Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            event.isCurrentlyActive ? 'Active' :
                            event.isUpcoming ? 'Upcoming' : 'Ended',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Event details
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.description.isNotEmpty) ...[
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      Text(
                        'Event Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(
                        Icons.schedule,
                        'Date & Time',
                        '${dateFormat.format(event.startDateTime)} at ${timeFormat.format(event.startDateTime)}',
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(
                        Icons.location_on,
                        'Location',
                        event.address,
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(
                        Icons.visibility,
                        'Status',
                        event.isActive ? 'Active' : 'Inactive',
                      ),

                      // Ticket Analytics
                      if (event.hasTicketing) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Ticket Sales',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: HiPopColors.darkSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTicketStat(
                                      'Sold',
                                      '${event.totalTicketsSold ?? 0}',
                                      HiPopColors.primaryDeepSage,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                                  ),
                                  Expanded(
                                    child: _buildTicketStat(
                                      'Checked In',
                                      '${event.totalAttendees ?? 0}',
                                      HiPopColors.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTicketStat(
                                      'Total Revenue',
                                      '\$${(event.totalRevenue ?? 0).toStringAsFixed(0)}',
                                      HiPopColors.organizerAccent,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                                  ),
                                  Expanded(
                                    child: _buildTicketStat(
                                      'Scanned Revenue',
                                      '\$${(event.actualRevenue ?? 0).toStringAsFixed(0)}',
                                      HiPopColors.warningAmber,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditEventDialog(event);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleEventStatus(event);
                      },
                      icon: Icon(event.isActive ? Icons.visibility_off : Icons.visibility),
                      label: Text(event.isActive ? 'Deactivate' : 'Activate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: event.isActive ? Colors.grey : HiPopColors.successGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: HiPopColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  void _toggleEventStatus(Event event) async {
    try {
      await EventService.updateEvent(event.id, {'isActive': !event.isActive});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.isActive ? 'Event deactivated' : 'Event activated'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Event'),
          content: Text('Are you sure you want to delete "${event.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEvent(event);
              },
              style: TextButton.styleFrom(foregroundColor: HiPopColors.errorPlum),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteEvent(Event event) async {
    try {
      await EventService.deleteEvent(event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting event: $e')),
        );
      }
    }
  }
}