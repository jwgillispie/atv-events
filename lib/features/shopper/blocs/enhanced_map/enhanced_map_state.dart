part of 'enhanced_map_bloc.dart';

/// Base state for enhanced map
abstract class EnhancedMapState extends Equatable {
  const EnhancedMapState();

  @override
  List<Object?> get props => [];
}

/// Initial state before map is loaded
class EnhancedMapInitial extends EnhancedMapState {}

/// Loading state while initializing map
class EnhancedMapLoading extends EnhancedMapState {}

/// Loaded state with map data
class EnhancedMapLoaded extends EnhancedMapState {
  final Set<Marker> markers;
  final CameraPosition cameraPosition;
  final String? selectedMarkerId;
  final MarkerType? selectedMarkerType;
  final dynamic selectedItem;
  final List<Market> markets;
  final List<Event> events;
  final bool isUpdating;
  final String? error;

  const EnhancedMapLoaded({
    required this.markers,
    required this.cameraPosition,
    this.selectedMarkerId,
    this.selectedMarkerType,
    this.selectedItem,
    required this.markets,
    required this.events,
    this.isUpdating = false,
    this.error,
  });

  /// Check if a marker is selected
  bool get hasSelection => selectedMarkerId != null;

  /// Get total marker count
  int get markerCount => markers.length;

  /// Create a copy with updated values
  EnhancedMapLoaded copyWith({
    Set<Marker>? markers,
    CameraPosition? cameraPosition,
    String? selectedMarkerId,
    MarkerType? selectedMarkerType,
    dynamic selectedItem,
    List<Market>? markets,
    List<Event>? events,
    bool? isUpdating,
    String? error,
  }) {
    return EnhancedMapLoaded(
      markers: markers ?? this.markers,
      cameraPosition: cameraPosition ?? this.cameraPosition,
      selectedMarkerId: selectedMarkerId,
      selectedMarkerType: selectedMarkerType,
      selectedItem: selectedItem,
      markets: markets ?? this.markets,
      events: events ?? this.events,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        markers,
        cameraPosition,
        selectedMarkerId,
        selectedMarkerType,
        selectedItem,
        markets,
        events,
        isUpdating,
        error,
      ];
}

/// Error state when map operations fail
class EnhancedMapError extends EnhancedMapState {
  final String message;

  const EnhancedMapError({required this.message});

  @override
  List<Object> get props => [message];
}