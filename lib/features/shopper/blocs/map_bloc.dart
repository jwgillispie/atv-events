import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/shared/models/event.dart';

// Events
abstract class MapEvent {}

class LoadMapData extends MapEvent {
  final List<Market> markets;
  final List<VendorPost> vendorPosts;
  final List<Event> events;
  
  LoadMapData({
    required this.markets,
    required this.vendorPosts,
    required this.events,
  });
}

class SelectMarker extends MapEvent {
  final String markerId;
  final MarkerType type;
  
  SelectMarker({required this.markerId, required this.type});
}

class ToggleMapView extends MapEvent {}

class UpdateMapCamera extends MapEvent {
  final CameraPosition position;
  
  UpdateMapCamera({required this.position});
}

// States
abstract class MapState {}

class MapInitial extends MapState {}

class MapLoading extends MapState {}

class MapLoaded extends MapState {
  final Set<Marker> markers;
  final bool isMapView;
  final CameraPosition currentPosition;
  final String? selectedMarkerId;
  final MarkerType? selectedMarkerType;
  
  MapLoaded({
    required this.markers,
    required this.isMapView,
    required this.currentPosition,
    this.selectedMarkerId,
    this.selectedMarkerType,
  });
  
  MapLoaded copyWith({
    Set<Marker>? markers,
    bool? isMapView,
    CameraPosition? currentPosition,
    String? selectedMarkerId,
    MarkerType? selectedMarkerType,
  }) {
    return MapLoaded(
      markers: markers ?? this.markers,
      isMapView: isMapView ?? this.isMapView,
      currentPosition: currentPosition ?? this.currentPosition,
      selectedMarkerId: selectedMarkerId ?? this.selectedMarkerId,
      selectedMarkerType: selectedMarkerType ?? this.selectedMarkerType,
    );
  }
}

class MapError extends MapState {
  final String message;
  
  MapError({required this.message});
}

// Marker types
enum MarkerType {
  market,
  vendor,
  event,
}

// Bloc
class MapBloc extends Bloc<MapEvent, MapState> {
  static const LatLng defaultPosition = LatLng(33.7490, -84.3880); // Atlanta, GA
  
  MapBloc() : super(MapInitial()) {
    on<LoadMapData>(_onLoadMapData);
    on<SelectMarker>(_onSelectMarker);
    on<ToggleMapView>(_onToggleMapView);
    on<UpdateMapCamera>(_onUpdateMapCamera);
  }
  
  Future<void> _onLoadMapData(LoadMapData event, Emitter<MapState> emit) async {
    emit(MapLoading());
    
    try {
      final Set<Marker> markers = {};
      
      // Add market markers
      for (final market in event.markets) {
        markers.add(
          Marker(
            markerId: MarkerId('market_${market.id}'),
            position: LatLng(market.latitude, market.longitude),
            infoWindow: InfoWindow(
              title: market.name,
              snippet: market.eventDisplayInfo,
              onTap: () {
                // Handle marker tap
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
            }
      
      // Add vendor post markers
      for (final post in event.vendorPosts) {
        if (post.latitude != null && post.longitude != null) {
          markers.add(
            Marker(
              markerId: MarkerId('vendor_${post.id}'),
              position: LatLng(post.latitude!, post.longitude!),
              infoWindow: InfoWindow(
                title: post.vendorName,
                snippet: post.locationName ?? post.location,
                onTap: () {
                  // Handle marker tap
                },
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          );
        }
      }
      
      // Add event markers
      for (final evt in event.events) {
        markers.add(
          Marker(
            markerId: MarkerId('event_${evt.id}'),
            position: LatLng(evt.latitude, evt.longitude),
            infoWindow: InfoWindow(
              title: evt.name,
              snippet: evt.formattedDateTime,
              onTap: () {
                // Handle marker tap
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
            }
      
      // Calculate center position based on markers
      LatLng centerPosition = defaultPosition;
      if (markers.isNotEmpty) {
        double avgLat = 0;
        double avgLng = 0;
        for (final marker in markers) {
          avgLat += marker.position.latitude;
          avgLng += marker.position.longitude;
        }
        avgLat /= markers.length;
        avgLng /= markers.length;
        centerPosition = LatLng(avgLat, avgLng);
      }
      
      emit(MapLoaded(
        markers: markers,
        isMapView: false, // Start with list view
        currentPosition: CameraPosition(
          target: centerPosition,
          zoom: 10.0,
        ),
      ));
    } catch (e) {
      emit(MapError(message: 'Failed to load map data: $e'));
    }
  }
  
  void _onSelectMarker(SelectMarker event, Emitter<MapState> emit) {
    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      emit(currentState.copyWith(
        selectedMarkerId: event.markerId,
        selectedMarkerType: event.type,
      ));
    }
  }
  
  void _onToggleMapView(ToggleMapView event, Emitter<MapState> emit) {
    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      emit(currentState.copyWith(
        isMapView: !currentState.isMapView,
      ));
    }
  }
  
  void _onUpdateMapCamera(UpdateMapCamera event, Emitter<MapState> emit) {
    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      emit(currentState.copyWith(
        currentPosition: event.position,
      ));
    }
  }
}