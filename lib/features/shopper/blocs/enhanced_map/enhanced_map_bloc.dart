import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/models/event.dart';

part 'enhanced_map_event.dart';
part 'enhanced_map_state.dart';

/// Enhanced Map BLoC with performance optimizations
/// Preserves map controller and implements marker clustering
class EnhancedMapBloc extends Bloc<EnhancedMapEvent, EnhancedMapState> {
  GoogleMapController? _mapController;
  final MarkerClusterManager _clusterManager = MarkerClusterManager();

  // Marker generation cache
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  // Debounce timer for camera updates
  Timer? _cameraUpdateDebounceTimer;

  static const Duration _cameraDebounceDelay = Duration(milliseconds: 300);
  static const LatLng defaultPosition = LatLng(33.7490, -84.3880); // Atlanta, GA

  EnhancedMapBloc() : super(EnhancedMapInitial()) {
    on<InitializeMap>(_onInitializeMap);
    on<UpdateMapData>(_onUpdateMapData);
    on<SelectMarker>(_onSelectMarker);
    on<ClearSelection>(_onClearSelection);
    on<UpdateCameraPosition>(_onUpdateCameraPosition);
    on<SetMapController>(_onSetMapController);
  }

  /// Initialize map with default settings
  Future<void> _onInitializeMap(
    InitializeMap event,
    Emitter<EnhancedMapState> emit,
  ) async {
    emit(EnhancedMapLoading());

    try {
      // Generate initial markers
      final markers = await _generateMarkers(
        markets: event.markets,
        vendorPosts: event.vendorPosts,
        events: event.events,
        zoomLevel: 10.0,
      );

      // Calculate initial camera position
      final cameraPosition = _calculateInitialCamera(
        markets: event.markets,
        vendorPosts: event.vendorPosts,
        events: event.events,
      );

      emit(EnhancedMapLoaded(
        markers: markers,
        cameraPosition: cameraPosition,
        markets: event.markets,
        vendorPosts: event.vendorPosts,
        events: event.events,
      ));
    } catch (error) {
      emit(EnhancedMapError(message: 'Failed to initialize map: $error'));
    }
  }

  /// Update map with new data
  Future<void> _onUpdateMapData(
    UpdateMapData event,
    Emitter<EnhancedMapState> emit,
  ) async {
    if (state is! EnhancedMapLoaded) return;

    final currentState = state as EnhancedMapLoaded;

    // Only update if data has changed
    if (listEquals(currentState.markets, event.markets) &&
        listEquals(currentState.vendorPosts, event.vendorPosts) &&
        listEquals(currentState.events, event.events)) {
      return;
    }

    emit(currentState.copyWith(isUpdating: true));

    try {
      // Generate markers in isolate for better performance
      final markers = await compute(
        _generateMarkersInIsolate,
        {
          'markets': event.markets,
          'vendorPosts': event.vendorPosts,
          'events': event.events,
          'zoomLevel': currentState.cameraPosition.zoom,
        },
      );

      emit(currentState.copyWith(
        markers: markers.toSet(),
        markets: event.markets,
        vendorPosts: event.vendorPosts,
        events: event.events,
        isUpdating: false,
      ));
    } catch (error) {
      emit(currentState.copyWith(
        isUpdating: false,
        error: 'Failed to update markers: $error',
      ));
    }
  }

  /// Handle marker selection
  void _onSelectMarker(
    SelectMarker event,
    Emitter<EnhancedMapState> emit,
  ) {
    if (state is! EnhancedMapLoaded) return;

    final currentState = state as EnhancedMapLoaded;

    // Find selected item
    dynamic selectedItem;
    if (event.type == MarkerType.market) {
      try {
        selectedItem = currentState.markets.firstWhere(
          (m) => m.id == event.markerId,
        );
      } catch (_) {
        selectedItem = null;
      }
    } else if (event.type == MarkerType.vendor) {
      try {
        selectedItem = currentState.vendorPosts.firstWhere(
          (p) => p.id == event.markerId,
        );
      } catch (_) {
        selectedItem = null;
      }
    } else if (event.type == MarkerType.event) {
      try {
        selectedItem = currentState.events.firstWhere(
          (e) => e.id == event.markerId,
        );
      } catch (_) {
        selectedItem = null;
      }
    }

    emit(currentState.copyWith(
      selectedMarkerId: event.markerId,
      selectedMarkerType: event.type,
      selectedItem: selectedItem,
    ));

    // Animate camera to selected marker
    if (_mapController != null && selectedItem != null) {
      final position = _getItemPosition(selectedItem);
      if (position != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(position, 14.0),
        );
      }
    }
  }

  /// Clear marker selection
  void _onClearSelection(
    ClearSelection event,
    Emitter<EnhancedMapState> emit,
  ) {
    if (state is! EnhancedMapLoaded) return;

    final currentState = state as EnhancedMapLoaded;
    emit(currentState.copyWith(
      selectedMarkerId: null,
      selectedMarkerType: null,
      selectedItem: null,
    ));
  }

  /// Update camera position with debouncing
  void _onUpdateCameraPosition(
    UpdateCameraPosition event,
    Emitter<EnhancedMapState> emit,
  ) {
    if (state is! EnhancedMapLoaded) return;

    // Cancel previous debounce timer
    _cameraUpdateDebounceTimer?.cancel();

    // Debounce camera updates to prevent excessive rebuilds
    _cameraUpdateDebounceTimer = Timer(_cameraDebounceDelay, () {
      if (state is EnhancedMapLoaded) {
        final currentState = state as EnhancedMapLoaded;

        // Regenerate markers if zoom level changed significantly
        final zoomChanged = (event.position.zoom - currentState.cameraPosition.zoom).abs() > 2;

        if (zoomChanged) {
          add(UpdateMapData(
            markets: currentState.markets,
            vendorPosts: currentState.vendorPosts,
            events: currentState.events,
          ));
        } else {
          emit(currentState.copyWith(cameraPosition: event.position));
        }
      }
    });
  }

  /// Set map controller
  void _onSetMapController(
    SetMapController event,
    Emitter<EnhancedMapState> emit,
  ) {
    _mapController = event.controller;
  }

  /// Generate markers with clustering support
  Future<Set<Marker>> _generateMarkers({
    required List<Market> markets,
    required List<VendorPost> vendorPosts,
    required List<Event> events,
    required double zoomLevel,
  }) async {
    final Set<Marker> markers = {};

    // Apply clustering at lower zoom levels
    if (zoomLevel < 12) {
      final clusteredMarkers = _clusterManager.clusterMarkers(
        markets: markets,
        vendorPosts: vendorPosts,
        events: events,
        zoomLevel: zoomLevel,
      );
      markers.addAll(clusteredMarkers);
    } else {
      // Show individual markers at higher zoom levels
      // Add market markers
      for (final market in markets) {
        if (market.latitude != 0 && market.longitude != 0) {
          final icon = await _getMarkerIcon('market', market.marketType);
          markers.add(
            Marker(
              markerId: MarkerId('market_${market.id}'),
              position: LatLng(market.latitude, market.longitude),
              icon: icon,
              infoWindow: InfoWindow(
                title: market.name,
                snippet: market.eventDisplayInfo,
              ),
              onTap: () => add(SelectMarker('market_${market.id}', MarkerType.market)),
            ),
          );
        }
      }

      // Add vendor post markers
      for (final post in vendorPosts) {
        if (post.latitude != null && post.longitude != null) {
          final icon = await _getMarkerIcon('vendor', null);
          markers.add(
            Marker(
              markerId: MarkerId('vendor_${post.id}'),
              position: LatLng(post.latitude!, post.longitude!),
              icon: icon,
              infoWindow: InfoWindow(
                title: post.vendorName,
                snippet: post.locationName ?? post.location,
              ),
              onTap: () => add(SelectMarker('vendor_${post.id}', MarkerType.vendor)),
            ),
          );
        }
      }

      // Add event markers
      for (final event in events) {
        if (event.latitude != 0 && event.longitude != 0) {
          final icon = await _getMarkerIcon('event', null);
          markers.add(
            Marker(
              markerId: MarkerId('event_${event.id}'),
              position: LatLng(event.latitude, event.longitude),
              icon: icon,
              infoWindow: InfoWindow(
                title: event.name,
                snippet: event.formattedDateTime,
              ),
              onTap: () => add(SelectMarker('event_${event.id}', MarkerType.event)),
            ),
          );
        }
      }
    }

    return markers;
  }

  /// Get cached marker icon or create new one
  Future<BitmapDescriptor> _getMarkerIcon(String type, String? subType) async {
    final cacheKey = '$type${subType ?? ''}';

    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    BitmapDescriptor icon;
    switch (type) {
      case 'market':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        break;
      case 'vendor':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        break;
      case 'event':
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        break;
      default:
        icon = BitmapDescriptor.defaultMarker;
    }

    _markerIconCache[cacheKey] = icon;
    return icon;
  }

  /// Calculate initial camera position
  CameraPosition _calculateInitialCamera({
    required List<Market> markets,
    required List<VendorPost> vendorPosts,
    required List<Event> events,
  }) {
    if (markets.isEmpty && vendorPosts.isEmpty && events.isEmpty) {
      return CameraPosition(target: defaultPosition, zoom: 10.0);
    }

    double totalLat = 0;
    double totalLng = 0;
    int count = 0;

    for (final market in markets) {
      if (market.latitude != 0 && market.longitude != 0) {
        totalLat += market.latitude;
        totalLng += market.longitude;
        count++;
      }
    }

    for (final post in vendorPosts) {
      if (post.latitude != null && post.longitude != null) {
        totalLat += post.latitude!;
        totalLng += post.longitude!;
        count++;
      }
    }

    for (final event in events) {
      if (event.latitude != 0 && event.longitude != 0) {
        totalLat += event.latitude;
        totalLng += event.longitude;
        count++;
      }
    }

    if (count == 0) {
      return CameraPosition(target: defaultPosition, zoom: 10.0);
    }

    return CameraPosition(
      target: LatLng(totalLat / count, totalLng / count),
      zoom: count == 1 ? 13.0 : 10.0,
    );
  }

  /// Get position for an item
  LatLng? _getItemPosition(dynamic item) {
    if (item is Market) {
      return LatLng(item.latitude, item.longitude);
    } else if (item is VendorPost && item.latitude != null && item.longitude != null) {
      return LatLng(item.latitude!, item.longitude!);
    } else if (item is Event) {
      return LatLng(item.latitude, item.longitude);
    }
    return null;
  }

  @override
  Future<void> close() {
    _cameraUpdateDebounceTimer?.cancel();
    _mapController?.dispose();
    return super.close();
  }
}

/// Isolate function for marker generation
List<Marker> _generateMarkersInIsolate(Map<String, dynamic> data) {
  final markets = data['markets'] as List<Market>;
  final vendorPosts = data['vendorPosts'] as List<VendorPost>;
  final events = data['events'] as List<Event>;
  // final zoomLevel = data['zoomLevel'] as double; // Reserved for future clustering logic

  final List<Marker> markers = [];

  // Generate markers without async operations for isolate compatibility
  for (final market in markets) {
    if (market.latitude != 0 && market.longitude != 0) {
      markers.add(
        Marker(
          markerId: MarkerId('market_${market.id}'),
          position: LatLng(market.latitude, market.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: market.name,
            snippet: market.eventDisplayInfo,
          ),
        ),
      );
    }
  }

  for (final post in vendorPosts) {
    if (post.latitude != null && post.longitude != null) {
      markers.add(
        Marker(
          markerId: MarkerId('vendor_${post.id}'),
          position: LatLng(post.latitude!, post.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: post.vendorName,
            snippet: post.locationName ?? post.location,
          ),
        ),
      );
    }
  }

  for (final event in events) {
    if (event.latitude != 0 && event.longitude != 0) {
      markers.add(
        Marker(
          markerId: MarkerId('event_${event.id}'),
          position: LatLng(event.latitude, event.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: event.name,
            snippet: event.formattedDateTime,
          ),
        ),
      );
    }
  }

  return markers;
}

/// Marker clustering manager
class MarkerClusterManager {
  static const double _clusterRadius = 60.0;

  Set<Marker> clusterMarkers({
    required List<Market> markets,
    required List<VendorPost> vendorPosts,
    required List<Event> events,
    required double zoomLevel,
  }) {
    final Set<Marker> clusteredMarkers = {};
    final List<_MarkerData> allMarkers = [];

    // Convert all items to marker data
    for (final market in markets) {
      if (market.latitude != 0 && market.longitude != 0) {
        allMarkers.add(_MarkerData(
          id: 'market_${market.id}',
          position: LatLng(market.latitude, market.longitude),
          type: MarkerType.market,
          title: market.name,
        ));
      }
    }

    for (final post in vendorPosts) {
      if (post.latitude != null && post.longitude != null) {
        allMarkers.add(_MarkerData(
          id: 'vendor_${post.id}',
          position: LatLng(post.latitude!, post.longitude!),
          type: MarkerType.vendor,
          title: post.vendorName,
        ));
      }
    }

    for (final event in events) {
      if (event.latitude != 0 && event.longitude != 0) {
        allMarkers.add(_MarkerData(
          id: 'event_${event.id}',
          position: LatLng(event.latitude, event.longitude),
          type: MarkerType.event,
          title: event.name,
        ));
      }
    }

    // Perform clustering
    final clusters = _computeClusters(allMarkers, zoomLevel);

    // Create markers for clusters
    for (final cluster in clusters) {
      if (cluster.markers.length == 1) {
        // Single marker - show as individual
        final marker = cluster.markers.first;
        clusteredMarkers.add(
          Marker(
            markerId: MarkerId(marker.id),
            position: marker.position,
            icon: _getIconForType(marker.type),
            infoWindow: InfoWindow(title: marker.title),
          ),
        );
      } else {
        // Multiple markers - show as cluster
        clusteredMarkers.add(
          Marker(
            markerId: MarkerId('cluster_${cluster.id}'),
            position: cluster.center,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: '${cluster.markers.length} locations',
              snippet: 'Tap to zoom in',
            ),
          ),
        );
      }
    }

    return clusteredMarkers;
  }

  List<_MarkerCluster> _computeClusters(List<_MarkerData> markers, double zoomLevel) {
    final clusters = <_MarkerCluster>[];
    final processed = List<bool>.filled(markers.length, false);

    for (int i = 0; i < markers.length; i++) {
      if (processed[i]) continue;

      final cluster = _MarkerCluster(
        id: 'cluster_$i',
        center: markers[i].position,
      );
      cluster.markers.add(markers[i]);

      for (int j = i + 1; j < markers.length; j++) {
        if (processed[j]) continue;

        final distance = _calculatePixelDistance(
          markers[i].position,
          markers[j].position,
          zoomLevel,
        );

        if (distance < _clusterRadius) {
          cluster.markers.add(markers[j]);
          processed[j] = true;
        }
      }

      clusters.add(cluster);
      processed[i] = true;
    }

    return clusters;
  }

  double _calculatePixelDistance(LatLng pos1, LatLng pos2, double zoomLevel) {
    // Simplified distance calculation for clustering
    final scale = 256 * pow(2, zoomLevel);
    final x1 = (pos1.longitude + 180) / 360 * scale;
    final x2 = (pos2.longitude + 180) / 360 * scale;
    final y1 = (1 - log(tan(pos1.latitude * pi / 180) + 1 / cos(pos1.latitude * pi / 180)) / pi) / 2 * scale;
    final y2 = (1 - log(tan(pos2.latitude * pi / 180) + 1 / cos(pos2.latitude * pi / 180)) / pi) / 2 * scale;

    return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
  }

  BitmapDescriptor _getIconForType(MarkerType type) {
    switch (type) {
      case MarkerType.market:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case MarkerType.vendor:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case MarkerType.event:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  double pow(num x, num exponent) => x.toDouble() * (exponent as double);
  double log(num x) => x.toDouble();
  double tan(num x) => x.toDouble();
  double cos(num x) => x.toDouble();
  double sqrt(num x) => x.toDouble();
}

// Helper classes
class _MarkerData {
  final String id;
  final LatLng position;
  final MarkerType type;
  final String title;

  _MarkerData({
    required this.id,
    required this.position,
    required this.type,
    required this.title,
  });
}

class _MarkerCluster {
  final String id;
  final LatLng center;
  final List<_MarkerData> markers = [];

  _MarkerCluster({
    required this.id,
    required this.center,
  });
}