import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/shared/models/event.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/core/utils/date_time_utils.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';
import 'package:atv_events/features/shopper/widgets/custom_map_markers.dart';

class ShopperMapView extends StatefulWidget {
  final List<Market> markets;
  final List<Event> events;
  final String selectedFilter;

  const ShopperMapView({
    super.key,
    required this.markets,
    required this.events,
    required this.selectedFilter,
  });
  
  @override
  State<ShopperMapView> createState() => _ShopperMapViewState();
}

class _ShopperMapViewState extends State<ShopperMapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Market? _selectedMarket;
  Event? _selectedEvent;
  bool _isLoadingMarkers = true;
  
  @override
  void initState() {
    super.initState();
    _createMarkersAsync();
  }
  
  @override
  void didUpdateWidget(ShopperMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markets != widget.markets ||
        oldWidget.events != widget.events ||
        oldWidget.selectedFilter != widget.selectedFilter) {
      _createMarkersAsync();
    }
  }
  
  Future<void> _createMarkersAsync() async {
    setState(() {
      _isLoadingMarkers = true;
    });
    
    final Set<Marker> newMarkers = {};
    
    try {
      // Add a small delay on web to ensure map is ready
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Filter based on selected filter type
      if (widget.selectedFilter == 'all' || widget.selectedFilter == 'markets') {
        // Add market markers with type-specific enhanced icons
        for (final market in widget.markets) {
          if (market.latitude != 0 && market.longitude != 0) {
            // Get market-type specific icon
            final marketIcon = await CustomMapMarkers.getEnhancedMarketIcon(
              marketType: market.marketType,
            );
            
            newMarkers.add(
              Marker(
                markerId: MarkerId('market_${market.id}'),
                position: LatLng(market.latitude, market.longitude),
                onTap: () => _showMarketInfo(market),
                icon: marketIcon,
                infoWindow: InfoWindow(
                  title: market.name,
                  snippet: market.eventDisplayInfo,
                ),
                // Add zIndex to ensure markers appear on top
                zIndex: 1,
              ),
            );
          }
        }
      }
      
      // No vendor posts in ATV Events
      
      if (widget.selectedFilter == 'all' || widget.selectedFilter == 'events') {
        // Add event markers with enhanced icons
        final eventIcon = await CustomMapMarkers.getEnhancedEventIcon();
        for (final event in widget.events) {
          if (event.latitude != 0 && event.longitude != 0) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('event_${event.id}'),
                position: LatLng(event.latitude, event.longitude),
                onTap: () => _showEventInfo(event),
                icon: eventIcon,
                infoWindow: InfoWindow(
                  title: event.name,
                  snippet: event.formattedDateTime,
                ),
                // Add zIndex to ensure markers appear on top
                zIndex: 0.8,
              ),
            );
          }
        }
      }
      
      setState(() {
        _markers = newMarkers;
        _isLoadingMarkers = false;
      });
      
      // Fit bounds after markers are created
      if (_markers.isNotEmpty && _mapController != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _mapController != null) {
            _fitBoundsToMarkers();
          }
        });
      }
    } catch (e) {
      debugPrint('Error creating markers: $e');
      setState(() {
        _isLoadingMarkers = false;
      });
    }
  }
  
  void _fitBoundsToMarkers() {
    if (_markers.isEmpty || _mapController == null || !mounted) return;
    
    final bounds = _calculateBounds();
    if (bounds != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }
  
  void _showMarketInfo(Market market) {
    setState(() {
      _selectedMarket = market;
      _selectedEvent = null;
    });
    
    // Animate camera to the selected marker
    if (_mapController != null && mounted && market.latitude != 0 && market.longitude != 0) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(market.latitude, market.longitude),
          14.0,
        ),
      );
    }
  }
  
  // [DEPRECATED] No vendor posts in ATV Events
  void _showVendorPostInfo(dynamic post) {
    // No vendor posts in ATV Events
  }
  
  void _showEventInfo(Event event) {
    setState(() {
      _selectedMarket = null;
      _selectedEvent = event;
    });
    
    // Animate camera to the selected marker
    if (_mapController != null && mounted && event.latitude != 0 && event.longitude != 0) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(event.latitude, event.longitude),
          14.0,
        ),
      );
    }
  }
  
  // Calculate appropriate bounds for all markers
  LatLngBounds? _calculateBounds() {
    if (_markers.isEmpty) return null;
    
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;
    
    for (final marker in _markers) {
      minLat = marker.position.latitude < minLat ? marker.position.latitude : minLat;
      maxLat = marker.position.latitude > maxLat ? marker.position.latitude : maxLat;
      minLng = marker.position.longitude < minLng ? marker.position.longitude : minLng;
      maxLng = marker.position.longitude > maxLng ? marker.position.longitude : maxLng;
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Default to Atlanta, GA if no markers
    final defaultPosition = const LatLng(33.7490, -84.3880);
    
    // Calculate center from markers
    LatLng centerPosition = defaultPosition;
    if (_markers.isNotEmpty) {
      double avgLat = 0;
      double avgLng = 0;
      for (final marker in _markers) {
        avgLat += marker.position.latitude;
        avgLng += marker.position.longitude;
      }
      avgLat /= _markers.length;
      avgLng /= _markers.length;
      centerPosition = LatLng(avgLat, avgLng);
    }
    
    return Stack(
      children: [
        // Show loading overlay while markers are being generated
        if (_isLoadingMarkers)
          Container(
            color: HiPopColors.darkBackground.withOpacity( 0.8),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.shopperAccent),
              ),
            ),
          ),
        
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: centerPosition,
            zoom: _markers.length > 1 ? 10.0 : 13.0,
          ),
          markers: _markers,
          onMapCreated: (controller) {
            _mapController = controller;
            // Custom map style for better visuals (skip on web as it might cause issues)
            if (!kIsWeb) {
              _setMapStyle();
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: true,
          zoomControlsEnabled: true,
          compassEnabled: true,
          mapType: MapType.normal,
        ),
        
        // Legend/Filter indicator
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface.withOpacity( 0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity( 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.selectedFilter == 'all' || widget.selectedFilter == 'markets') ...[
                  Icon(Icons.location_on, color: Colors.green[400], size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Markets',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (widget.selectedFilter == 'all' || widget.selectedFilter == 'vendors') ...[
                  Icon(Icons.location_on, color: Colors.blue[400], size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Vendors',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (widget.selectedFilter == 'all' || widget.selectedFilter == 'events') ...[
                  Icon(Icons.location_on, color: Colors.orange[400], size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Events',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Info card for selected item
        if (_selectedMarket != null || _selectedEvent != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildInfoCard(context),
          ),
      ],
    );
  }
  
  Widget _buildInfoCard(BuildContext context) {
    if (_selectedMarket != null) {
      return _buildMarketInfoCard(context, _selectedMarket!);
    } else if (_selectedEvent != null) {
      return _buildEventInfoCard(context, _selectedEvent!);
    }
    return const SizedBox.shrink();
  }
  
  Widget _buildMarketInfoCard(BuildContext context, Market market) {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 8,
      child: InkWell(
        onTap: () => context.pushNamed('marketDetail', extra: market),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.successGreen.withOpacity( 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'MARKET',
                      style: TextStyle(
                        color: HiPopColors.successGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedMarket = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                market.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                market.eventDisplayInfo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      market.address,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await UrlLauncherService.launchMaps(
                          market.address,
                          context: context,
                        );
                      },
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HiPopColors.shopperAccent,
                        side: BorderSide(color: HiPopColors.shopperAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.pushNamed('marketDetail', extra: market),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.shopperAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // [DEPRECATED] No vendor posts in ATV Events
  Widget _buildVendorPostInfoCard(BuildContext context, dynamic post) {
    return const SizedBox.shrink();
  }
  
  Widget _buildEventInfoCard(BuildContext context, Event event) {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 8,
      child: InkWell(
        onTap: () => context.goNamed(
          'eventDetail',
          pathParameters: {'eventId': event.id},
          extra: event,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.warningAmber.withOpacity( 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'EVENT',
                      style: TextStyle(
                        color: HiPopColors.warningAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedEvent = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.formattedDateTime,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await UrlLauncherService.launchMaps(
                          event.location,
                          context: context,
                        );
                      },
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HiPopColors.shopperAccent,
                        side: BorderSide(color: HiPopColors.shopperAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.goNamed(
                        'eventDetail',
                        pathParameters: {'eventId': event.id},
                        extra: event,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.shopperAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _setMapStyle() async {
    if (_mapController == null || !mounted) return;
    
    // Subtle, professional map style
    const String mapStyle = '''[
      {
        "elementType": "geometry",
        "stylers": [{"color": "#f5f5f5"}]
      },
      {
        "elementType": "labels.icon",
        "stylers": [{"visibility": "off"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#f5f5f5"}]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [{"color": "#eeeeee"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [{"color": "#e5e5e5"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [{"color": "#ffffff"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#c9c9c9"}]
      }
    ]''';
    
    try {
      await _mapController!.setMapStyle(mapStyle);
    } catch (e) {
      debugPrint('Error setting map style: $e');
    }
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}