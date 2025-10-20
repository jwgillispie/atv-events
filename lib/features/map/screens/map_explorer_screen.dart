import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/vendor/models/vendor_post.dart';
import 'package:atv_events/features/shared/models/event.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/core/constants/ui_constants.dart';
import 'package:atv_events/features/shopper/widgets/custom_map_markers.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';
import 'package:atv_events/core/utils/date_time_utils.dart';

/// Full-screen map explorer with advanced features
class MapExplorerScreen extends StatefulWidget {
  final List<Market> markets;
  final List<VendorPost> vendorPosts;
  final List<Event> events;
  final String? selectedFilter;
  
  const MapExplorerScreen({
    super.key,
    required this.markets,
    required this.vendorPosts,
    required this.events,
    this.selectedFilter,
  });
  
  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoadingMarkers = true;
  
  // Selected item tracking
  Market? _selectedMarket;
  VendorPost? _selectedVendorPost;
  Event? _selectedEvent;
  
  // User location
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  
  // Filter state
  late String _activeFilter;
  final Set<String> _visibleCategories = {'markets', 'vendors', 'events'};
  
  // Animation controllers
  late AnimationController _cardAnimationController;
  late Animation<double> _cardAnimation;
  
  // Clustering settings for performance
  static const double _clusterZoomThreshold = 12.0;
  bool _shouldCluster = false;
  
  @override
  void initState() {
    super.initState();
    _activeFilter = widget.selectedFilter ?? 'all';
    
    // Initialize animation controller
    _cardAnimationController = AnimationController(
      duration: UIConstants.defaultAnimation,
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    // Load markers and location
    _initializeMap();
  }
  
  Future<void> _initializeMap() async {
    await Future.wait([
      _createMarkers(),
      _getUserLocation(),
    ]);
  }
  
  Future<void> _getUserLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        );
        
        // Animate to user location
        if (_mapController != null && _currentPosition != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              13.0,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }
  
  Future<void> _createMarkers() async {
    setState(() => _isLoadingMarkers = true);
    
    final Set<Marker> newMarkers = {};
    
    try {
      // Create markets markers with type-specific icons
      if (_visibleCategories.contains('markets')) {
        for (final market in widget.markets) {
          if (_isValidLocation(market.latitude, market.longitude)) {
            // Get market-type specific icon
            final marketIcon = await CustomMapMarkers.getEnhancedMarketIcon(
              marketType: market.marketType,
            );
            
            newMarkers.add(
              Marker(
                markerId: MarkerId('market_${market.id}'),
                position: LatLng(market.latitude, market.longitude),
                onTap: () => _selectMarket(market),
                icon: marketIcon,
                zIndexInt: 2, // Markets have higher priority
              ),
            );
          }
        }
      }
      
      // Create vendor markers with category icons
      if (_visibleCategories.contains('vendors')) {
        for (final post in widget.vendorPosts) {
          if (_isValidLocation(post.latitude, post.longitude)) {
            // Determine vendor category
            List<String> vendorItems = [
              if (post.description != null) post.description!,
              post.vendorName,
              if (post.locationName != null) post.locationName!,
            ];
            
            final vendorIcon = await CustomMapMarkers.getVendorIcon(
              vendorItems: vendorItems,
            );
            
            newMarkers.add(
              Marker(
                markerId: MarkerId('vendor_${post.id}'),
                position: LatLng(post.latitude!, post.longitude!),
                onTap: () => _selectVendorPost(post),
                icon: vendorIcon,
                zIndexInt: 1,
              ),
            );
          }
        }
      }
      
      // Create event markers
      if (_visibleCategories.contains('events')) {
        final eventIcon = await CustomMapMarkers.getEnhancedEventIcon();
        for (final event in widget.events) {
          if (_isValidLocation(event.latitude, event.longitude)) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('event_${event.id}'),
                position: LatLng(event.latitude, event.longitude),
                onTap: () => _selectEvent(event),
                icon: eventIcon,
                zIndexInt: 2,
              ),
            );
          }
        }
      }
      
      setState(() {
        _markers = newMarkers;
        _isLoadingMarkers = false;
      });
      
      // Fit map to show all markers
      _fitMapToMarkers();
    } catch (e) {
      debugPrint('Error creating markers: $e');
      setState(() => _isLoadingMarkers = false);
    }
  }
  
  bool _isValidLocation(double? lat, double? lng) {
    return lat != null && lng != null && lat != 0 && lng != 0 &&
           lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
  
  void _fitMapToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;
    
    // Calculate bounds
    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;
    
    for (final marker in _markers) {
      minLat = marker.position.latitude < minLat ? marker.position.latitude : minLat;
      maxLat = marker.position.latitude > maxLat ? marker.position.latitude : maxLat;
      minLng = marker.position.longitude < minLng ? marker.position.longitude : minLng;
      maxLng = marker.position.longitude > maxLng ? marker.position.longitude : maxLng;
    }
    
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    });
  }
  
  void _selectMarket(Market market) {
    setState(() {
      _selectedMarket = market;
      _selectedVendorPost = null;
      _selectedEvent = null;
    });
    
    _cardAnimationController.forward();
    
    // Animate to selected marker
    if (_isValidLocation(market.latitude, market.longitude)) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(market.latitude, market.longitude),
          15.0,
        ),
      );
    }
  }
  
  void _selectVendorPost(VendorPost post) {
    setState(() {
      _selectedMarket = null;
      _selectedVendorPost = post;
      _selectedEvent = null;
    });
    
    _cardAnimationController.forward();
    
    // Animate to selected marker
    if (_isValidLocation(post.latitude, post.longitude)) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(post.latitude!, post.longitude!),
          15.0,
        ),
      );
    }
  }
  
  void _selectEvent(Event event) {
    setState(() {
      _selectedMarket = null;
      _selectedVendorPost = null;
      _selectedEvent = event;
    });
    
    _cardAnimationController.forward();
    
    // Animate to selected marker
    if (_isValidLocation(event.latitude, event.longitude)) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(event.latitude, event.longitude),
          15.0,
        ),
      );
    }
  }
  
  void _clearSelection() {
    _cardAnimationController.reverse().then((_) {
      setState(() {
        _selectedMarket = null;
        _selectedVendorPost = null;
        _selectedEvent = null;
      });
    });
  }
  
  Future<void> _toggleCategory(String category) async {
    setState(() {
      if (_visibleCategories.contains(category)) {
        _visibleCategories.remove(category);
      } else {
        _visibleCategories.add(category);
      }
    });
    
    await _createMarkers();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(33.7490, -84.3880), // Atlanta default
              zoom: 10,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              _setMapStyle();
            },
            onCameraMove: (position) {
              // Update clustering based on zoom level
              final shouldCluster = position.zoom < _clusterZoomThreshold;
              if (shouldCluster != _shouldCluster) {
                setState(() => _shouldCluster = shouldCluster);
              }
            },
            onTap: (_) => _clearSelection(),
            myLocationEnabled: _currentPosition != null,
            myLocationButtonEnabled: false, // Custom button instead
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          
          // Loading overlay
          if (_isLoadingMarkers)
            Container(
              color: Colors.black.withOpacity( 0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.shopperAccent),
                ),
              ),
            ),
          
          // Top controls
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header bar
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface.withOpacity( 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity( 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                        color: HiPopColors.darkTextPrimary,
                      ),
                      Expanded(
                        child: Text(
                          'Map Explorer',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: HiPopColors.darkTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_markers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: HiPopColors.shopperAccent.withOpacity( 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_markers.length} locations',
                            style: TextStyle(
                              color: HiPopColors.shopperAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Filter chips
                Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(
                        label: 'Locations',
                        icon: Icons.place,
                        color: HiPopColors.successGreen,
                        isSelected: _visibleCategories.contains('markets'),
                        onTap: () => _toggleCategory('markets'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Pop-ups',
                        icon: Icons.storefront,
                        color: HiPopColors.infoBlueGray,
                        isSelected: _visibleCategories.contains('vendors'),
                        onTap: () => _toggleCategory('vendors'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Events',
                        icon: Icons.event,
                        color: HiPopColors.warningAmber,
                        isSelected: _visibleCategories.contains('events'),
                        onTap: () => _toggleCategory('events'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom info card
          if (_selectedMarket != null || _selectedVendorPost != null || _selectedEvent != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _cardAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - _cardAnimation.value) * 300),
                    child: Opacity(
                      opacity: _cardAnimation.value,
                      child: _buildInfoCard(),
                    ),
                  );
                },
              ),
            ),
          
          // Floating action buttons
          Positioned(
            right: 16,
            bottom: _selectedMarket != null || _selectedVendorPost != null || _selectedEvent != null
                ? 320
                : 100,
            child: Column(
              children: [
                // My location button
                FloatingActionButton.small(
                  heroTag: 'location',
                  onPressed: _isLoadingLocation ? null : _getUserLocation,
                  backgroundColor: HiPopColors.darkSurface,
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.shopperAccent),
                          ),
                        )
                      : Icon(
                          _currentPosition != null ? Icons.my_location : Icons.location_searching,
                          color: HiPopColors.shopperAccent,
                        ),
                ),
                const SizedBox(height: 8),
                // Fit all button
                FloatingActionButton.small(
                  heroTag: 'fit',
                  onPressed: _fitMapToMarkers,
                  backgroundColor: HiPopColors.darkSurface,
                  child: const Icon(
                    Icons.zoom_out_map,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: UIConstants.fastAnimation,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity( 0.2) : HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : HiPopColors.darkBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? color : HiPopColors.darkTextTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : HiPopColors.darkTextSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard() {
    if (_selectedMarket != null) {
      return _buildMarketCard(_selectedMarket!);
    } else if (_selectedVendorPost != null) {
      return _buildVendorCard(_selectedVendorPost!);
    } else if (_selectedEvent != null) {
      return _buildEventCard(_selectedEvent!);
    }
    return const SizedBox.shrink();
  }
  
  Widget _buildMarketCard(Market market) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkTextTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HiPopColors.successGreen.withOpacity( 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.store_mall_directory,
                      color: HiPopColors.successGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MARKET',
                          style: TextStyle(
                            color: HiPopColors.successGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          market.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: HiPopColors.darkTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                    color: HiPopColors.darkTextTertiary,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Date and time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 8),
                  Text(
                    market.eventDisplayInfo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      market.address,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
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
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HiPopColors.shopperAccent,
                        side: BorderSide(color: HiPopColors.shopperAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.pushNamed('marketDetail', extra: market);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.shopperAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
  
  Widget _buildVendorCard(VendorPost post) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkTextTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HiPopColors.vendorAccent.withOpacity( 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.store,
                      color: HiPopColors.vendorAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VENDOR POP-UP',
                          style: TextStyle(
                            color: HiPopColors.vendorAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.vendorName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: HiPopColors.darkTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                    color: HiPopColors.darkTextTertiary,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Description
              if (post.description != null && post.description!.isNotEmpty) ...[
                Text(
                  post.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HiPopColors.darkTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              
              // Date and time
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 8),
                  Text(
                    DateTimeUtils.formatPostDateTime(post.popUpStartDateTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.locationName ?? 'Location unavailable',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await UrlLauncherService.launchMaps(
                          post.locationName ?? 'Location unavailable',
                          context: context,
                        );
                      },
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HiPopColors.shopperAccent,
                        side: BorderSide(color: HiPopColors.shopperAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.pushNamed('vendorPostDetail', extra: post);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.shopperAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
  
  Widget _buildEventCard(Event event) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkTextTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HiPopColors.warningAmber.withOpacity( 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event,
                      color: HiPopColors.warningAmber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EVENT',
                          style: TextStyle(
                            color: HiPopColors.warningAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: HiPopColors.darkTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                    color: HiPopColors.darkTextTertiary,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Date and time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 8),
                  Text(
                    event.formattedDateTime,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: HiPopColors.darkTextTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.location,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
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
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HiPopColors.shopperAccent,
                        side: BorderSide(color: HiPopColors.shopperAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.goNamed(
                          'eventDetail',
                          pathParameters: {'eventId': event.id},
                          extra: event,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.shopperAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
    if (_mapController == null) return;
    
    // Clean, modern map style
    const String mapStyle = '''[
      {
        "elementType": "geometry",
        "stylers": [{"color": "#242f3e"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#746855"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#242f3e"}]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#d59563"}]
      },
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [{"visibility": "off"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [{"color": "#263c3f"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#6b9a76"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [{"color": "#38414e"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.stroke",
        "stylers": [{"color": "#212a37"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#9ca5b3"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [{"color": "#746855"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry.stroke",
        "stylers": [{"color": "#1f2835"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#f3d19c"}]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [{"color": "#2f3948"}]
      },
      {
        "featureType": "transit.station",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#d59563"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#17263c"}]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#515c6d"}]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#17263c"}]
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
    _cardAnimationController.dispose();
    _mapController?.dispose();
    CustomMapMarkers.clearCache();
    super.dispose();
  }
}