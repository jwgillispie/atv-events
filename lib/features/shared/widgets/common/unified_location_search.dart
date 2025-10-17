import 'package:flutter/material.dart';
import 'package:atv_events/features/shared/services/location/places_service.dart';
import '../../../../core/constants/constants.dart';

/// Unified location search widget that consolidates the functionality
/// of GooglePlacesWidget, SimplePlacesWidget, and LocationSearchWidget
class UnifiedLocationSearch extends StatefulWidget {
  /// Callback when a place is selected from Google Places API
  final Function(PlaceDetails)? onPlaceSelected;
  
  /// Callback for simple location selection (can be null)
  final Function(PlaceDetails?)? onLocationSelected;
  
  /// Callback for text-based search without place details
  final Function(String)? onTextSearch;
  
  /// Callback when the search is cleared
  final Function()? onCleared;
  
  /// Initial location text to display
  final String? initialLocation;
  
  /// Whether to show the clear button
  final bool showClearButton;
  
  /// Hint text for the search field
  final String? hintText;
  
  /// Custom decoration for the search field
  final InputDecoration? decoration;
  
  /// Whether to enable Google Places API search
  final bool enablePlacesAPI;
  
  /// Minimum characters required before searching
  final int minSearchLength;
  
  /// Whether to automatically focus the field
  final bool autoFocus;
  
  /// Text style for the input field
  final TextStyle? textStyle;

  const UnifiedLocationSearch({
    super.key,
    this.onPlaceSelected,
    this.onLocationSelected,
    this.onTextSearch,
    this.onCleared,
    this.initialLocation,
    this.showClearButton = true,
    this.hintText,
    this.decoration,
    this.enablePlacesAPI = true,
    this.minSearchLength = 3,
    this.autoFocus = false,
    this.textStyle,
  });

  @override
  State<UnifiedLocationSearch> createState() => _UnifiedLocationSearchState();
}

class _UnifiedLocationSearchState extends State<UnifiedLocationSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showPredictions = false;
  String _lastQuery = '';
  bool _hasSearched = false;
  String? _selectedPlaceId;

  @override
  void initState() {
    super.initState();
    
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _controller.text = widget.initialLocation!;
    }
    
    _focusNode.addListener(() {
      setState(() {
        _showPredictions = _focusNode.hasFocus && _predictions.isNotEmpty;
      });
    });

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (!widget.enablePlacesAPI) {
      // If Places API is disabled, just use text search
      widget.onTextSearch?.call(query);
      return;
    }

    if (query.length < widget.minSearchLength) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _isLoading = false;
      });
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    setState(() => _isLoading = true);

    try {
      final predictions = await PlacesService.getPlacePredictions(query);
      
      if (mounted) {
        setState(() {
          _predictions = predictions;
          _showPredictions = predictions.isNotEmpty && _focusNode.hasFocus;
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictions = [];
          _showPredictions = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    if (_selectedPlaceId == prediction.placeId) return;
    
    setState(() {
      _isLoading = true;
      _selectedPlaceId = prediction.placeId;
    });

    try {
      final placeDetails = await PlacesService.getPlaceDetails(prediction.placeId);
      
      if (mounted) {
        setState(() {
          _controller.text = prediction.description;
          _showPredictions = false;
          _isLoading = false;
          _selectedPlaceId = null;
        });
        
        _focusNode.unfocus();
        
        // Call appropriate callback
        if (placeDetails != null) {
          if (widget.onPlaceSelected != null) {
            widget.onPlaceSelected!(placeDetails);
          } else if (widget.onLocationSelected != null) {
            widget.onLocationSelected!(placeDetails);
          }
        } else {
          // Handle case where place details couldn't be fetched - create fallback
          final fallbackDetails = PlaceDetails(
            placeId: prediction.placeId,
            name: prediction.mainText,
            formattedAddress: prediction.description,
            latitude: 0.0,
            longitude: 0.0,
          );
          if (widget.onPlaceSelected != null) {
            widget.onPlaceSelected!(fallbackDetails);
          } else if (widget.onLocationSelected != null) {
            widget.onLocationSelected!(fallbackDetails);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedPlaceId = null;
        });
        
        // Create fallback details for error case
        final fallbackDetails = PlaceDetails(
          placeId: prediction.placeId,
          name: prediction.mainText,
          formattedAddress: prediction.description,
          latitude: 0.0,
          longitude: 0.0,
        );
        if (widget.onPlaceSelected != null) {
          widget.onPlaceSelected!(fallbackDetails);
        } else if (widget.onLocationSelected != null) {
          widget.onLocationSelected!(fallbackDetails);
        }
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _predictions = [];
      _showPredictions = false;
      _selectedPlaceId = null;
      _lastQuery = '';
      _hasSearched = false;
    });
    
    widget.onCleared?.call();
    widget.onLocationSelected?.call(null);
  }

  void _handleDirectSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      widget.onTextSearch?.call(query);
      _focusNode.unfocus();
      setState(() => _showPredictions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search field
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          style: widget.textStyle ?? const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          decoration: widget.decoration ?? InputDecoration(
            hintText: widget.hintText ?? 'Search for a location...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: _isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(AppConstants.mediumSpacing),
                    child: SizedBox(
                      width: AppConstants.smallIconSize,
                      height: AppConstants.smallIconSize,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
            suffixIcon: widget.showClearButton && _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() {}); // Rebuild to show/hide clear button
            if (widget.enablePlacesAPI) {
              _searchPlaces(value);
            } else {
              widget.onTextSearch?.call(value);
            }
          },
          onFieldSubmitted: (_) => _handleDirectSearch(),
        ),
        
        // Predictions dropdown
        if (_showPredictions && _predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppConstants.smallSpacing),
            decoration: BoxDecoration(
              color: Colors.grey[800], // Dark surface for dropdown
              borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity( 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _predictions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey[700],
              ),
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                final isSelected = _selectedPlaceId == prediction.placeId;
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    size: AppConstants.mediumIconSize,
                    color: isSelected ? Colors.orange : Colors.grey[400],
                  ),
                  title: Text(
                    prediction.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected ? Colors.orange : Colors.white,
                    ),
                  ),
                  trailing: isSelected
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        )
                      : null,
                  onTap: isSelected ? null : () => _selectPlace(prediction),
                );
              },
            ),
          ),
        
        // Direct search button (when Places API is enabled)
        if (widget.enablePlacesAPI && widget.onTextSearch != null && _hasSearched && _predictions.isEmpty && _controller.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppConstants.smallSpacing),
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleDirectSearch,
              icon: const Icon(Icons.search),
              label: Text('Search for "${_controller.text}"'),
            ),
          ),
      ],
    );
  }
}

/// Static convenience methods for common use cases
class LocationSearchWidgets {
  LocationSearchWidgets._(); // Private constructor

  /// Create a simple location picker (replaces SimplePlacesWidget)
  static Widget simple({
    Key? key,
    required Function(PlaceDetails?) onLocationSelected,
    String? initialLocation,
    String? hintText,
  }) {
    return UnifiedLocationSearch(
      key: key,
      onLocationSelected: onLocationSelected,
      initialLocation: initialLocation,
      hintText: hintText ?? 'Enter location',
    );
  }

  /// Create a Google Places search (replaces GooglePlacesWidget)
  static Widget googlePlaces({
    Key? key,
    required Function(PlaceDetails) onPlaceSelected,
    Function(String)? onTextSearch,
    Function()? onCleared,
    String? initialLocation,
  }) {
    return UnifiedLocationSearch(
      key: key,
      onPlaceSelected: onPlaceSelected,
      onTextSearch: onTextSearch,
      onCleared: onCleared,
      initialLocation: initialLocation,
    );
  }

  /// Create a text-only search (no Places API)
  static Widget textOnly({
    Key? key,
    required Function(String) onTextSearch,
    String? initialLocation,
    String? hintText,
  }) {
    return UnifiedLocationSearch(
      key: key,
      onTextSearch: onTextSearch,
      initialLocation: initialLocation,
      hintText: hintText ?? 'Search...',
      enablePlacesAPI: false,
      showClearButton: false,
    );
  }
}