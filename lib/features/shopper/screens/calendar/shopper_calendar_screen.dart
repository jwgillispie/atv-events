import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/blocs/favorites/favorites_bloc.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/market/services/market_batch_service.dart';
import 'package:atv_events/features/market/services/market_calendar_service.dart';
import 'package:atv_events/features/market/services/market_service.dart';
import 'package:atv_events/features/shared/models/event.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/features/shared/services/data/event_service.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/features/shared/widgets/common/error_widget.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';
import 'package:atv_events/features/vendor/models/vendor_market_relationship.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:cloud_firestore/cloud_firestore.dart';


class ShopperCalendarScreen extends StatefulWidget {
  const ShopperCalendarScreen({super.key});

  @override
  State<ShopperCalendarScreen> createState() => _ShopperCalendarScreenState();
}

// Enhanced event class to support multiple types
class CalendarEvent {
  final String id;
  final String name;
  final String type; // 'market', 'vendor', 'event'
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? marketId;
  final String? vendorId;
  final String? eventId;
  final Color accentColor;
  final IconData icon;
  final String? description;
  final Map<String, dynamic> metadata;

  CalendarEvent({
    required this.id,
    required this.name,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.location,
    this.marketId,
    this.vendorId,
    this.eventId,
    required this.accentColor,
    required this.icon,
    this.description,
    this.metadata = const {},
  });
}

class _ShopperCalendarScreenState extends State<ShopperCalendarScreen>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<List<CalendarEvent>> _selectedEvents;
  late TabController _tabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Markets
  List<Market> _favoriteMarkets = [];
  List<Market> _nearbyMarkets = [];
  
  // Vendors
  List<UserProfile> _favoriteVendors = [];
  
  // Events
  List<Event> _favoriteEvents = [];
  List<Event> _nearbyEvents = [];
  
  // Calendar events grouped by date
  Map<DateTime, List<CalendarEvent>> _favoriteCalendarEvents = {};
  Map<DateTime, List<CalendarEvent>> _nearbyCalendarEvents = {};
  
  bool _isLoading = true;
  String? _error;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadAllData();
    
    // Favorites are now automatically loaded when auth state changes in main.dart
  }

  @override
  void dispose() {
    // Remove listener before disposing controller
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    
    // Dispose ValueNotifier
    _selectedEvents.dispose();
    
    // Clear data collections
    _favoriteMarkets.clear();
    _nearbyMarkets.clear();
    _favoriteVendors.clear();
    _favoriteEvents.clear();
    _nearbyEvents.clear();
    _favoriteCalendarEvents.clear();
    _nearbyCalendarEvents.clear();
    
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    
    if (_tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user from auth bloc
      final authState = context.read<AuthBloc>().state;
      
      // Load all favorite data from BLoC state
      List<Market> favoriteMarkets = [];
      List<UserProfile> favoriteVendors = [];
      List<Event> favoriteEventsList = [];
      Map<String, List<VendorMarketRelationship>> vendorRelationships = {};
      
      if (authState is Authenticated) {
        // Ensure favorites are loaded in BLoC
        context.read<FavoritesBloc>().add(LoadFavorites(userId: authState.user.uid));
        
        // Get favorites from BLoC state
        final favoritesState = context.read<FavoritesBloc>().state;
        
        // Load favorite markets using batch query
        // This reduces Firebase reads by up to 90%
        try {
          final markets = await MarketBatchService.batchLoadMarkets(
            favoritesState.favoriteMarketIds,
          );
          favoriteMarkets.addAll(markets);
        } catch (e) {
        }
        
        // Load favorite vendors and their market relationships
        for (final vendorId in favoritesState.favoriteVendorIds) {
          try {
            final vendorProfile = await UserProfileService().getUserProfile(vendorId);
            if (vendorProfile != null && vendorProfile.userType == 'vendor') {
              favoriteVendors.add(vendorProfile);
              
              // Load vendor's market relationships to get their schedules
              try {
                final querySnapshot = await FirebaseFirestore.instance
                    .collection('vendor_market_relationships')
                    .where('vendorId', isEqualTo: vendorId)
                    .where('status', whereIn: ['active', 'approved'])
                    .get();
                
                final relationships = querySnapshot.docs
                    .map((doc) => VendorMarketRelationship.fromFirestore(doc))
                    .toList();
                
                vendorRelationships[vendorId] = relationships;
              } catch (e) {
                vendorRelationships[vendorId] = [];
              }
            }
          } catch (e) {
          }
        }
        
        // Load favorite events
        for (final eventId in favoritesState.favoriteEventIds) {
          try {
            final event = await EventService.getEvent(eventId);
            if (event != null && event.isActive) {
              favoriteEventsList.add(event);
            }
          } catch (e) {
          }
        }
      }

      // Load nearby markets and events (using Atlanta as default if no user city)
      String userCity = 'Atlanta'; // Default
      
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated && authState.userProfile != null) {
          // Try to get user's city from profile or use a default
          userCity = 'Atlanta'; // You could add city to user profile later
        }
      }
      
      final nearbyMarkets = await MarketService.getMarketsByCity(userCity);
      
      // Load nearby events
      List<Event> nearbyEventsList = [];
      try {
        final eventsSnapshot = await EventService.getEventsByCityStream(userCity).first;
        nearbyEventsList = eventsSnapshot.where((e) => 
          e.isActive && e.endDateTime.isAfter(DateTime.now())
        ).toList();
      } catch (e) {
      }
      
      // Generate calendar events for the next 3 months
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now().add(const Duration(days: 90));
      
      // Convert all data to calendar events
      final favoriteCalendarEvents = await _generateCalendarEvents(
        markets: favoriteMarkets,
        vendors: favoriteVendors,
        vendorRelationships: vendorRelationships,
        events: favoriteEventsList,
        startDate: startDate,
        endDate: endDate,
      );
      
      final nearbyCalendarEvents = await _generateCalendarEvents(
        markets: nearbyMarkets,
        vendors: [],
        vendorRelationships: {},
        events: nearbyEventsList,
        startDate: startDate,
        endDate: endDate,
      );
      
      final groupedFavoriteEvents = _groupCalendarEventsByDate(favoriteCalendarEvents);
      final groupedNearbyEvents = _groupCalendarEventsByDate(nearbyCalendarEvents);

      if (mounted) {
        setState(() {
          _favoriteMarkets = favoriteMarkets;
          _nearbyMarkets = nearbyMarkets;
          _favoriteVendors = favoriteVendors;
          _favoriteEvents = favoriteEventsList;
          _nearbyEvents = nearbyEventsList;
          _favoriteCalendarEvents = groupedFavoriteEvents;
          _nearbyCalendarEvents = groupedNearbyEvents;
          _isLoading = false;
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final eventsMap = _currentTabIndex == 0 ? _favoriteCalendarEvents : _nearbyCalendarEvents;
    final dayKey = DateTime(day.year, day.month, day.day);
    return eventsMap[dayKey] ?? [];
  }
  
  Future<List<CalendarEvent>> _generateCalendarEvents({
    required List<Market> markets,
    required List<UserProfile> vendors,
    required Map<String, List<VendorMarketRelationship>> vendorRelationships,
    required List<Event> events,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    List<CalendarEvent> calendarEvents = [];
    
    // Generate market events
    final marketEvents = await MarketCalendarService.getMarketEventsForDateRange(
      markets,
      startDate,
      endDate,
    );
    
    for (final marketEvent in marketEvents) {
      final market = markets.firstWhere((m) => m.id == marketEvent.marketId);
      calendarEvents.add(CalendarEvent(
        id: '${marketEvent.marketId}_${marketEvent.eventDate.millisecondsSinceEpoch}',
        name: marketEvent.marketName,
        type: 'market',
        startTime: _parseTimeString(marketEvent.eventDate, marketEvent.startTime),
        endTime: _parseTimeString(marketEvent.eventDate, marketEvent.endTime),
        location: market.address,
        marketId: marketEvent.marketId,
        accentColor: HiPopColors.shopperAccent,
        icon: Icons.storefront,
        description: market.description,
        metadata: {
          'timeRange': marketEvent.timeRange,
        },
      ));
    }
    
    // Generate vendor popup events based on their market relationships
    for (final vendor in vendors) {
      final relationships = vendorRelationships[vendor.userId] ?? [];
      
      for (final relationship in relationships) {
        if (relationship.isActive || relationship.isApproved) {
          // Get the market for this relationship
          try {
            final market = await MarketService.getMarket(relationship.marketId);
            if (market != null) {
              // Generate events for this vendor at this market
              final vendorMarketEvents = await MarketCalendarService.getMarketEventsForDateRange(
                [market],
                startDate,
                endDate,
              );
              
              for (final marketEvent in vendorMarketEvents) {
                // Check if vendor operates on this day
                final dayOfWeek = ['sunday', 'monday', 'tuesday', 'wednesday',
                                  'thursday', 'friday', 'saturday'][marketEvent.eventDate.weekday % 7];
                if (relationship.operatingDays == null ||
                    relationship.operatingDays!.isEmpty ||
                    relationship.operatingDays!.contains(dayOfWeek)) {
                  calendarEvents.add(CalendarEvent(
                    id: '${vendor.userId}_${marketEvent.marketId}_${marketEvent.eventDate.millisecondsSinceEpoch}',
                    name: '${vendor.businessName ?? vendor.displayName} at ${market.name}',
                    type: 'vendor',
                    startTime: _parseTimeString(marketEvent.eventDate, marketEvent.startTime),
                    endTime: _parseTimeString(marketEvent.eventDate, marketEvent.endTime),
                    location: market.address,
                    vendorId: vendor.userId,
                    marketId: relationship.marketId,
                    accentColor: HiPopColors.vendorAccent,
                    icon: Icons.store,
                    description: vendor.bio ?? 'Visit ${vendor.businessName} at ${market.name}',
                    metadata: {
                      'boothNumber': relationship.boothNumber,
                      'categories': vendor.categories,
                      'instagramHandle': vendor.instagramHandle,
                    },
                  ));
                }
              }
            }
          } catch (e) {
          }
        }
      }
    }
    
    // Add standalone events
    for (final event in events) {
      if (event.startDateTime.isAfter(startDate) && event.startDateTime.isBefore(endDate)) {
        calendarEvents.add(CalendarEvent(
          id: event.id,
          name: event.name,
          type: 'event',
          startTime: event.startDateTime,
          endTime: event.endDateTime,
          location: event.address,
          eventId: event.id,
          marketId: event.marketId,
          accentColor: HiPopColors.organizerAccent,
          icon: Icons.event,
          description: event.description,
          metadata: {
            'organizerName': event.organizerName,
            'tags': event.tags,
          },
        ));
      }
    }
    
    // Sort events by date and time
    calendarEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    return calendarEvents;
  }
  
  Map<DateTime, List<CalendarEvent>> _groupCalendarEventsByDate(List<CalendarEvent> events) {
    Map<DateTime, List<CalendarEvent>> groupedEvents = {};
    
    for (final event in events) {
      final dateKey = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      
      if (!groupedEvents.containsKey(dateKey)) {
        groupedEvents[dateKey] = [];
      }
      groupedEvents[dateKey]!.add(event);
    }
    
    return groupedEvents;
  }
  
  DateTime _parseTimeString(DateTime date, String timeString) {
    // Parse time strings like "9:00 AM" or "5:00 PM"
    try {
      final parts = timeString.split(' ');
      if (parts.length != 2) {
        // Default to noon if parsing fails
        return DateTime(date.year, date.month, date.day, 12, 0);
      }
      
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) {
        return DateTime(date.year, date.month, date.day, 12, 0);
      }
      
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1].toUpperCase() == 'PM';
      
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }
      
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      // Default to noon if parsing fails
      return DateTime(date.year, date.month, date.day, 12, 0);
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!mounted) return;
    
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Event Calendar'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HiPopColors.shopperAccent,
                HiPopColors.primaryDeepSage,
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh calendar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: HiPopColors.darkTextSecondary,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.favorite),
              text: 'Favorites',
            ),
            Tab(
              icon: Icon(Icons.location_on),
              text: 'Nearby',
            ),
          ],
        ),
      ),
      body: BlocListener<FavoritesBloc, FavoritesState>(
        listener: (context, state) {
          // Reload all data when favorites change
          if (state.favoriteMarketIds.isNotEmpty || 
              state.favoriteMarketIds.isEmpty ||
              state.favoriteVendorIds.isNotEmpty ||
              state.favoriteVendorIds.isEmpty ||
              state.favoriteEventIds.isNotEmpty ||
              state.favoriteEventIds.isEmpty) {
            _loadAllData();
          }
        },
        child: Column(
          children: [
            if (_isLoading)
              const Expanded(
                child: LoadingWidget(message: 'Loading event schedules...'),
              )
            else if (_error != null)
              Expanded(
                child: ErrorDisplayWidget.network(
                  onRetry: _loadAllData,
                ),
              )
            else ...[
            // Market summary
            Container(
              padding: const EdgeInsets.all(16),
              color: HiPopColors.shopperAccent.withOpacity( 0.1),
              child: _buildMarketSummary(),
            ),
            
            // Calendar
            TableCalendar<CalendarEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format && mounted) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                if (mounted) {
                  _focusedDay = focusedDay;
                }
              },
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                markerDecoration: BoxDecoration(
                  color: HiPopColors.shopperAccent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: HiPopColors.primaryDeepSage,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: HiPopColors.secondarySoftSage,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: HiPopColors.shopperAccent,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                formatButtonTextStyle: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Events list
            Expanded(
              child: ValueListenableBuilder<List<CalendarEvent>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  if (value.isEmpty && !_isLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: HiPopColors.darkTextTertiary.withOpacity( 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events on this day',
                            style: TextStyle(
                              fontSize: 18,
                              color: HiPopColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: value.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildDayHeader(value);
                      }
                      
                      final event = value[index - 1];
                      return _buildEnhancedEventCard(event);
                    },
                  );
                },
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarketSummary() {
    if (_currentTabIndex == 0) {
      // Favorites tab - show breakdown of different types
      final totalFavorites = _favoriteMarkets.length + 
                            _favoriteVendors.length + 
                            _favoriteEvents.length;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Favorites',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  '${_favoriteMarkets.length}',
                  'Locations',
                  Icons.place,
                  HiPopColors.shopperAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  '${_favoriteVendors.length}',
                  'Vendors',
                  Icons.store,
                  HiPopColors.vendorAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  '${_favoriteEvents.length}',
                  'Events',
                  Icons.event,
                  HiPopColors.organizerAccent,
                ),
              ),
            ],
          ),
          if (totalFavorites == 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.infoBlueGray.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: HiPopColors.infoBlueGray.withOpacity( 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: HiPopColors.infoBlueGray,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add favorites to see them in your calendar',
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      // Nearby tab
      final currentMarkets = _nearbyMarkets;
      final openMarkets = currentMarkets.where((market) => 
          MarketCalendarService.isMarketCurrentlyOpen(market)).length;
      final upcomingEvents = _nearbyEvents.where((event) => 
          event.startDateTime.isAfter(DateTime.now())).length;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nearby Activities',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  '${currentMarkets.length}',
                  'Locations',
                  Icons.place,
                  HiPopColors.shopperAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  '$upcomingEvents',
                  'Events',
                  Icons.event,
                  HiPopColors.organizerAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  '$openMarkets',
                  'Open Now',
                  Icons.schedule,
                  HiPopColors.successGreen,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildSummaryCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HiPopColors.darkBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(List<CalendarEvent> events) {
    final selectedDate = _selectedDay!;
    final dayName = MarketCalendarService.getDayName(selectedDate);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dayName.toUpperCase()}, ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            events.isEmpty 
              ? 'No events scheduled today'
              : '${events.length} event${events.length == 1 ? '' : 's'} scheduled',
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedEventCard(CalendarEvent event) {
    final isToday = isSameDay(event.startTime, DateTime.now());
    final isCurrentlyOpen = isToday && 
        DateTime.now().isAfter(event.startTime) && 
        DateTime.now().isBefore(event.endTime);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: event.accentColor.withOpacity( 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: event.accentColor.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleEventTap(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon with colored background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: event.accentColor.withOpacity( 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  event.icon,
                  color: event.accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentlyOpen) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HiPopColors.successGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'OPEN NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Event type badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: event.accentColor.withOpacity( 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getEventTypeLabel(event.type),
                            style: TextStyle(
                              color: event.accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Time
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: HiPopColors.darkTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeRange(event.startTime, event.endTime),
                          style: TextStyle(
                            color: HiPopColors.darkTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    // Location if available
                    if (event.location != null && event.location!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: HiPopColors.darkTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: TextStyle(
                                color: HiPopColors.darkTextSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Additional metadata
                    if (event.type == 'vendor' && event.metadata['categories'] != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: (event.metadata['categories'] as List<String>)
                            .take(3)
                            .map((category) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HiPopColors.backgroundMutedGray.withOpacity( 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: HiPopColors.darkTextSecondary,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Favorite indicator
              if (_currentTabIndex == 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.favorite,
                  color: HiPopColors.errorPlum,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  String _getEventTypeLabel(String type) {
    switch (type) {
      case 'market':
        return 'LOCATION';
      case 'vendor':
        return 'POP-UP';
      case 'event':
        return 'EVENT';
      default:
        return type.toUpperCase();
    }
  }
  
  String _formatTimeRange(DateTime start, DateTime end) {
    final startHour = start.hour > 12 ? start.hour - 12 : (start.hour == 0 ? 12 : start.hour);
    final startPeriod = start.hour >= 12 ? 'PM' : 'AM';
    final endHour = end.hour > 12 ? end.hour - 12 : (end.hour == 0 ? 12 : end.hour);
    final endPeriod = end.hour >= 12 ? 'PM' : 'AM';
    
    String startMinute = start.minute.toString().padLeft(2, '0');
    String endMinute = end.minute.toString().padLeft(2, '0');
    
    return '$startHour:$startMinute $startPeriod - $endHour:$endMinute $endPeriod';
  }
  
  void _handleEventTap(CalendarEvent event) {
    // Navigate to appropriate detail screen based on event type
    switch (event.type) {
      case 'market':
        if (event.marketId != null) {
          Navigator.pushNamed(
            context,
            '/market_detail',
            arguments: event.marketId,
          );
        }
        break;
      case 'vendor':
        if (event.vendorId != null) {
          Navigator.pushNamed(
            context,
            '/vendor_detail',
            arguments: event.vendorId,
          );
        }
        break;
      case 'event':
        if (event.eventId != null) {
          Navigator.pushNamed(
            context,
            '/event_detail',
            arguments: event.eventId,
          );
        }
        break;
    }
  }
}