part of 'enhanced_map_bloc.dart';

/// Marker type enumeration
enum MarkerType { market, vendor, event }

/// Base event for enhanced map
abstract class EnhancedMapEvent extends Equatable {
  const EnhancedMapEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize map with data
class InitializeMap extends EnhancedMapEvent {
  final List<Market> markets;
  final List<VendorPost> vendorPosts;
  final List<Event> events;

  const InitializeMap({
    required this.markets,
    required this.vendorPosts,
    required this.events,
  });

  @override
  List<Object> get props => [markets, vendorPosts, events];
}

/// Update map with new data
class UpdateMapData extends EnhancedMapEvent {
  final List<Market> markets;
  final List<VendorPost> vendorPosts;
  final List<Event> events;

  const UpdateMapData({
    required this.markets,
    required this.vendorPosts,
    required this.events,
  });

  @override
  List<Object> get props => [markets, vendorPosts, events];
}

/// Select a marker on the map
class SelectMarker extends EnhancedMapEvent {
  final String markerId;
  final MarkerType type;

  const SelectMarker(this.markerId, this.type);

  @override
  List<Object> get props => [markerId, type];
}

/// Clear marker selection
class ClearSelection extends EnhancedMapEvent {
  const ClearSelection();
}

/// Update camera position
class UpdateCameraPosition extends EnhancedMapEvent {
  final CameraPosition position;

  const UpdateCameraPosition(this.position);

  @override
  List<Object> get props => [position];
}

/// Set the map controller
class SetMapController extends EnhancedMapEvent {
  final GoogleMapController controller;

  const SetMapController(this.controller);

  @override
  List<Object> get props => [controller];
}