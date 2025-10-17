import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/blocs/event_detail/event_detail_bloc.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shared/widgets/common/error_widget.dart' as common_error;
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import 'package:atv_events/features/tickets/widgets/event_tickets_section.dart';
import 'package:share_plus/share_plus.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;
import '../../../shared/models/event.dart';


class EventDetailScreen extends StatelessWidget {
  final String eventId;
  final Event? event; // Optional: if event data is already available

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.event,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EventDetailBloc()..add(LoadEventDetail(eventId)),
      child: EventDetailView(initialEvent: event),
    );
  }
}

class EventDetailView extends StatefulWidget {
  final Event? initialEvent;

  const EventDetailView({super.key, this.initialEvent});

  @override
  State<EventDetailView> createState() => _EventDetailViewState();
}

class _EventDetailViewState extends State<EventDetailView> {
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userProfileService = UserProfileService();
      final profile = await userProfileService.getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _currentUser = profile;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: BlocBuilder<EventDetailBloc, EventDetailState>(
        builder: (context, state) {
          switch (state.status) {
            case EventDetailStatus.initial:
            case EventDetailStatus.loading:
              if (widget.initialEvent != null) {
                // Show initial event data while loading fresh data
                return _buildEventContent(context, widget.initialEvent!, state.isFavorite, true);
              }
              return const Center(child: LoadingWidget());

            case EventDetailStatus.loaded:
              return _buildEventContent(context, state.event!, state.isFavorite, false);

            case EventDetailStatus.error:
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Event Details'),
                  backgroundColor: HiPopColors.darkSurface,
                  foregroundColor: HiPopColors.darkTextPrimary,
                  elevation: 0,
                ),
                body: Center(
                  child: common_error.ErrorDisplayWidget(
                    title: 'Error',
                    message: state.errorMessage ?? 'Failed to load event details',
                    onRetry: () => context.read<EventDetailBloc>().add(const RefreshEventDetail()),
                  ),
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildEventContent(BuildContext context, Event event, bool isFavorite, bool isLoading) {
    return CustomScrollView(
      slivers: [
        // App Bar with Flyer Backdrop
        SliverAppBar(
          expandedHeight: event.imageUrl != null ? 300 : 0,
          pinned: true,
          backgroundColor: HiPopColors.darkSurface,
          foregroundColor: HiPopColors.darkTextPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                // Fallback to go back in GoRouter if Navigator can't pop
                context.go('/shopper');
              }
            },
          ),
          flexibleSpace: event.imageUrl != null
              ? FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: HiPopColors.darkSurface,
                          child: Icon(
                            Icons.event,
                            size: 80,
                            color: HiPopColors.darkTextTertiary,
                          ),
                        ),
                      ),
                      // Gradient overlay for better text visibility
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              HiPopColors.darkBackground.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          actions: [
            // Favorite Button
            Semantics(
              label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              child: IconButton(
                onPressed: isLoading ? null : () {
                  context.read<EventDetailBloc>().add(const ToggleEventFavorite());
                },
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? HiPopColors.errorPlum : HiPopColors.darkTextSecondary,
                ),
              ),
            ),
            // Share Button
            Semantics(
              label: 'Share event',
              child: IconButton(
                onPressed: () => _shareEvent(context, event),
                icon: const Icon(Icons.share),
              ),
            ),
          ],
        ),
        // Event Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Title
                Semantics(
                  header: true,
                  child: Text(
                    event.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Event Status Badge
                _buildStatusBadge(context, event),
                const SizedBox(height: 24),

                // Date and Time Card
                _buildInfoCard(
                  context,
                  icon: Icons.schedule,
                  title: 'Date & Time',
                  content: _formatEventDateTime(event),
                  semanticLabel: 'Event date and time: ${_formatEventDateTime(event)}',
                ),
                const SizedBox(height: 16),

                // Location Card
                _buildInfoCard(
                  context,
                  icon: Icons.location_on,
                  title: 'Location',
                  content: '${event.location}\n${event.address}\n${event.city}, ${event.state}',
                  semanticLabel: 'Event location: ${event.location}, ${event.address}, ${event.city}, ${event.state}',
                  onTap: () => _openMaps(context, event),
                ),
                const SizedBox(height: 16),

                // Organizer Card (if available)
                if (event.organizerName != null)
                  _buildInfoCard(
                    context,
                    icon: Icons.person,
                    title: 'Organizer',
                    content: event.organizerName!,
                    semanticLabel: 'Event organizer: ${event.organizerName}',
                  ),
                if (event.organizerName != null) const SizedBox(height: 16),

                // Description Card
                if (event.description.isNotEmpty)
                  _buildDescriptionCard(context, event.description),
                if (event.description.isNotEmpty) const SizedBox(height: 16),

                // Tags
                if (event.tags.isNotEmpty)
                  _buildTagsSection(context, event.tags),
                if (event.tags.isNotEmpty) const SizedBox(height: 16),

                // Event Links Section
                if (_hasEventLinks(event))
                  _buildEventLinksSection(context, event),
                if (_hasEventLinks(event)) const SizedBox(height: 24),

                // Tickets Section
                if (event.hasTicketing) ...[
                  EventTicketsSection(
                    event: event,
                    currentUser: _currentUser,
                  ),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                _buildActionButtons(context, event),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, Event event) {
    String statusText;
    Color backgroundColor;
    Color textColor;

    if (event.isCurrentlyActive) {
      statusText = 'Happening Now';
      backgroundColor = Colors.green;
      textColor = Colors.white;
    } else if (event.isUpcoming) {
      statusText = 'Upcoming';
      backgroundColor = Colors.blue;
      textColor = Colors.white;
    } else {
      statusText = 'Ended';
      backgroundColor = Colors.grey;
      textColor = Colors.white;
    }

    return Semantics(
      label: 'Event status: $statusText',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    String? semanticLabel,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: semanticLabel ?? '$title: $content',
      button: onTap != null,
      child: Card(
        elevation: 2,
        color: HiPopColors.darkSurface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HiPopColors.shopperAccent.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: HiPopColors.shopperAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HiPopColors.darkTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: HiPopColors.darkBorder,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, String description) {
    return Card(
      elevation: 2,
      color: HiPopColors.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HiPopColors.shopperAccent.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: HiPopColors.shopperAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'About This Event',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Event description: $description',
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HiPopColors.darkTextSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Event tags: ${tags.join(', ')}',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: HiPopColors.shopperAccent.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HiPopColors.shopperAccent.withOpacity( 0.3)),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: HiPopColors.primaryDeepSage,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  bool _hasEventLinks(Event event) {
    return (event.eventWebsite != null && event.eventWebsite!.isNotEmpty) ||
           (event.instagramUrl != null && event.instagramUrl!.isNotEmpty) ||
           (event.facebookUrl != null && event.facebookUrl!.isNotEmpty) ||
           (event.ticketUrl != null && event.ticketUrl!.isNotEmpty) ||
           event.links.isNotEmpty;
  }

  Widget _buildEventLinksSection(BuildContext context, Event event) {
    return Card(
      elevation: 2,
      color: HiPopColors.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HiPopColors.shopperAccent.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.link,
                    color: HiPopColors.shopperAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Event Links',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Event Website
            if (event.eventWebsite != null && event.eventWebsite!.isNotEmpty)
              _buildLinkTile(
                context,
                icon: Icons.language,
                label: 'Event Website',
                url: event.eventWebsite!,
              ),
            
            // Instagram
            if (event.instagramUrl != null && event.instagramUrl!.isNotEmpty)
              _buildLinkTile(
                context,
                icon: Icons.camera_alt,
                label: 'Instagram',
                url: event.instagramUrl!,
                isInstagram: true,
              ),
            
            // Facebook
            if (event.facebookUrl != null && event.facebookUrl!.isNotEmpty)
              _buildLinkTile(
                context,
                icon: Icons.facebook,
                label: 'Facebook Event',
                url: event.facebookUrl!,
              ),
            
            // Ticket/Registration
            if (event.ticketUrl != null && event.ticketUrl!.isNotEmpty)
              _buildLinkTile(
                context,
                icon: Icons.confirmation_number,
                label: 'Get Tickets',
                url: event.ticketUrl!,
                isPrimary: true,
              ),
            
            // Legacy event links (if any)
            ...event.links.map((link) => _buildLinkTile(
              context,
              icon: _getIconForLinkType(link.type),
              label: link.label,
              url: link.url,
            )),
            
            // Additional links (if any)
            if (event.additionalLinks != null)
              ...event.additionalLinks!.entries.map((entry) => _buildLinkTile(
                context,
                icon: Icons.link,
                label: entry.key,
                url: entry.value,
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
    bool isPrimary = false,
    bool isInstagram = false,
  }) {
    final backgroundColor = isPrimary 
        ? HiPopColors.shopperAccent.withOpacity( 0.1)
        : HiPopColors.darkSurfaceVariant;
    final iconColor = isPrimary 
        ? HiPopColors.shopperAccent 
        : HiPopColors.darkTextSecondary;
    final textColor = isPrimary
        ? HiPopColors.shopperAccent
        : HiPopColors.darkTextPrimary;

    // For Instagram, extract username from URL if it's a full URL
    String displayText = label;
    if (isInstagram && url.contains('instagram.com')) {
      final username = url.split('/').last;
      displayText = '@$username';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => UrlLauncherService.launchWebsite(url),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.open_in_new,
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

  IconData _getIconForLinkType(EventLinkType type) {
    switch (type) {
      case EventLinkType.tickets:
        return Icons.confirmation_number;
      case EventLinkType.registration:
        return Icons.how_to_reg;
      case EventLinkType.website:
        return Icons.language;
      case EventLinkType.facebook:
        return Icons.facebook;
      case EventLinkType.instagram:
        return Icons.camera_alt;
      case EventLinkType.other:
        return Icons.link;
    }
  }

  Widget _buildActionButtons(BuildContext context, Event event) {
    return Column(
      children: [
        // Get Directions Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openMaps(context, event),
            icon: const Icon(Icons.directions),
            label: const Text('Get Directions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.shopperAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Secondary Actions Row
        Row(
          children: [
            // Add to Calendar Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addToCalendar(context, event),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Add to Calendar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HiPopColors.shopperAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Share Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareEvent(context, event),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HiPopColors.shopperAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatEventDateTime(Event event) {
    final startDate = event.startDateTime;
    final endDate = event.endDateTime;
    
    // Simple date/time formatting without intl package
    final startDateStr = _formatDate(startDate);
    final endDateStr = _formatDate(endDate);
    final startTimeStr = _formatTime(startDate);
    final endTimeStr = _formatTime(endDate);
    
    if (startDate.day == endDate.day &&
        startDate.month == endDate.month &&
        startDate.year == endDate.year) {
      // Same day event
      return '$startDateStr\n$startTimeStr - $endTimeStr';
    } else {
      // Multi-day event
      return '$startDateStr $startTimeStr\nto\n$endDateStr $endTimeStr';
    }
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    
    return '$hour:$minute $period';
  }

  void _openMaps(BuildContext context, Event event) async {
    try {
      // Use coordinates for precise location
      final locationString = '${event.latitude},${event.longitude}';
      
      await UrlLauncherService.launchMaps(locationString, context: context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToCalendar(BuildContext context, Event event) async {
    try {
      // Create a calendar event from our Event model
      final calendarEvent = calendar.Event(
        title: event.name,
        description: _buildCalendarDescription(event),
        location: _buildFullAddress(event),
        startDate: event.startDateTime,
        endDate: event.endDateTime,
        iosParams: const calendar.IOSParams(
          reminder: Duration(hours: 1), // Reminder 1 hour before event
          url: 'https://hipop-markets.web.app', // App URL
        ),
        androidParams: const calendar.AndroidParams(
          emailInvites: [], // No email invites needed
        ),
      );

      // Add the event to the calendar
      final result = await calendar.Add2Calendar.addEvent2Cal(calendarEvent);
      
      // Show success feedback with HiPop brand colors
      if (context.mounted && result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle, 
                  color: HiPopColors.lightTextPrimary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Event added to your calendar!',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: HiPopColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Handle permission errors and other exceptions gracefully
      if (context.mounted) {
        String errorMessage = 'Failed to add event to calendar';
        
        // Check for common error types
        if (e.toString().contains('permission')) {
          errorMessage = 'Calendar permission denied. Please enable calendar access in settings.';
        } else if (e.toString().contains('cancelled')) {
          // User cancelled - no need to show error
          return;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline, 
                  color: HiPopColors.lightTextPrimary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: HiPopColors.errorPlum,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: errorMessage.contains('permission') 
              ? SnackBarAction(
                  label: 'SETTINGS',
                  textColor: HiPopColors.surfacePalePink,
                  onPressed: () {
                    // Open app settings for permission management
                    // Note: Users need to manually enable calendar permissions in settings
                    UrlLauncherService.launchWebsite('app-settings:');
                  },
                )
              : null,
          ),
        );
      }
    }
  }
  
  String _buildCalendarDescription(Event event) {
    final buffer = StringBuffer();
    
    // Add market name if available
    if (event.organizerName != null) {
      buffer.writeln('Organized by: ${event.organizerName}');
      buffer.writeln();
    }
    
    // Add event description
    if (event.description.isNotEmpty) {
      buffer.writeln(event.description);
      buffer.writeln();
    }
    
    // Add location details
    buffer.writeln('Location: ${event.location}');
    buffer.writeln('Address: ${event.address}');
    buffer.writeln('${event.city}, ${event.state}');
    buffer.writeln();
    
    // Add tags if available
    if (event.tags.isNotEmpty) {
      buffer.writeln('Tags: ${event.tags.join(', ')}');
      buffer.writeln();
    }
    
    // Add links if available
    if (event.eventWebsite != null && event.eventWebsite!.isNotEmpty) {
      buffer.writeln('Website: ${event.eventWebsite}');
    }
    if (event.ticketUrl != null && event.ticketUrl!.isNotEmpty) {
      buffer.writeln('Tickets: ${event.ticketUrl}');
    }
    
    buffer.writeln();
    buffer.writeln('Discovered on HiPop Markets');
    buffer.writeln('https://hipop-markets.web.app');
    
    return buffer.toString();
  }
  
  String _buildFullAddress(Event event) {
    return '${event.address}, ${event.city}, ${event.state}';
  }

  Future<void> _shareEvent(BuildContext context, Event event) async {
    try {
      final content = _buildEventShareContent(event);
      
      final result = await Share.share(
        content,
        subject: 'Check out this event on HiPop!',
      );

      // Show success message if sharing was successful
      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Event shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to share event: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _buildEventShareContent(Event event) {
    final buffer = StringBuffer();
    
    buffer.writeln('Event Alert!');
    buffer.writeln();
    buffer.writeln(event.name);
    if (event.description.isNotEmpty) {
      buffer.writeln(event.description);
    }
    buffer.writeln();
    buffer.writeln('Location: ${event.location}');
    buffer.writeln('When: ${_formatDateTime(event.startDateTime, event.endDateTime)}');
    buffer.writeln();
    buffer.writeln('Discovered on HiPop - Discover local pop-ups and markets');
    buffer.writeln('Download: https://apps.apple.com/us/app/hipop-markets/id6749876075');
    buffer.writeln();
    buffer.writeln('#Event #LocalEvents #${event.location.replaceAll(' ', '')} #HiPop');
    
    return buffer.toString();
  }

  String _formatDateTime(DateTime start, DateTime end) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    String formatDate(DateTime date) {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    
    String formatTime(DateTime time) {
      final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    }
    
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      // Same day
      return '${formatDate(start)} • ${formatTime(start)} - ${formatTime(end)}';
    } else {
      // Multi-day
      return '${formatDate(start)} ${formatTime(start)} - ${formatDate(end)} ${formatTime(end)}';
    }
  }
}