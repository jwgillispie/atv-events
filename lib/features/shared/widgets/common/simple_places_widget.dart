import 'package:flutter/material.dart';
import '../../services/location/places_service.dart';
import '../../../../core/theme/hipop_colors.dart';

class SimplePlacesWidget extends StatefulWidget {
  final Function(PlaceDetails?) onLocationSelected;
  final String? initialLocation;

  const SimplePlacesWidget({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
  });

  @override
  State<SimplePlacesWidget> createState() => _SimplePlacesWidgetState();
}

class _SimplePlacesWidgetState extends State<SimplePlacesWidget> {
  final TextEditingController _controller = TextEditingController();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showPredictions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _controller.text = widget.initialLocation!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final predictions = await PlacesService.getPlacePredictions(query);
      setState(() {
        _predictions = predictions;
        _showPredictions = predictions.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    setState(() {
      _controller.text = prediction.description;
      _predictions = [];
      _showPredictions = false;
      _isLoading = true;
    });
    
    try {
      // Get place details including coordinates
      final placeDetails = await PlacesService.getPlaceDetails(prediction.placeId);
      
      setState(() => _isLoading = false);
      
      if (placeDetails != null) {
        // Notify parent with full place details
        widget.onLocationSelected(placeDetails);
      } else {
        // Fallback: create basic PlaceDetails from prediction
        final fallbackDetails = PlaceDetails(
          placeId: prediction.placeId,
          name: prediction.mainText,
          formattedAddress: prediction.description,
          latitude: 0, // Will trigger text-only search
          longitude: 0,
        );
        widget.onLocationSelected(fallbackDetails);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      // Fallback: create basic PlaceDetails from prediction
      final fallbackDetails = PlaceDetails(
        placeId: prediction.placeId,
        name: prediction.mainText,
        formattedAddress: prediction.description,
        latitude: 0, // Will trigger text-only search
        longitude: 0,
      );
      widget.onLocationSelected(fallbackDetails);
    }
  }

  void _performDirectSearch() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
      });
      
      // Create a PlaceDetails for the typed text
      final directPlaceDetails = PlaceDetails(
        placeId: 'direct_search_${_controller.text}',
        name: _controller.text.trim(),
        formattedAddress: _controller.text.trim(),
        latitude: 0.0, // Will trigger text-only search
        longitude: 0.0,
      );
      
      widget.onLocationSelected(directPlaceDetails);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search for a location...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.location_on, color: HiPopColors.primaryDeepSage),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _predictions = [];
                                _showPredictions = false;
                              });
                              widget.onLocationSelected(null);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    _searchPlaces(value);
                    setState(() {
                      _showPredictions = value.isNotEmpty;
                    });
                  },
                  onSubmitted: (value) => _performDirectSearch(),
                ),
              ),
              // Search Button
              if (_controller.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _performDirectSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.primaryDeepSage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 16),
                              SizedBox(width: 4),
                              Text('Search', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
        if (_showPredictions && (_predictions.isNotEmpty || _controller.text.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(1.0), // Force full opacity
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // Use black with opacity instead of withValues
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _getSearchItems().length,
                    itemBuilder: (context, index) {
                      final item = _getSearchItems()[index];
                      return ListTile(
                        leading: Icon(
                          item['icon'] as IconData,
                          color: item['isDirect'] ? HiPopColors.infoBlueGray : HiPopColors.primaryDeepSage,
                        ),
                        title: Text(
                          item['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: item['isDirect'] ? HiPopColors.infoBlueGrayDark : Colors.black,
                          ),
                        ),
                        subtitle: item['subtitle'] != null && item['subtitle'].isNotEmpty
                            ? Text(
                                item['subtitle'],
                                style: TextStyle(
                                  color: item['isDirect'] ? HiPopColors.infoBlueGray : Colors.grey[700],
                                ),
                              )
                            : null,
                        onTap: item['onTap'],
                        dense: true,
                        trailing: Icon(
                          item['isDirect'] ? Icons.search : Icons.north_west,
                          size: 16,
                          color: item['isDirect'] ? HiPopColors.infoBlueGrayLight : Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
                // Add a small attribution footer to avoid Google Places watermark overlay
                if (_predictions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Powered by Google',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  List<Map<String, dynamic>> _getSearchItems() {
    final items = <Map<String, dynamic>>[];
    
    // Add direct search option as first item if user has typed something
    if (_controller.text.trim().isNotEmpty) {
      items.add({
        'title': 'Search for "${_controller.text.trim()}"',
        'subtitle': 'Use exactly what you typed',
        'icon': Icons.search,
        'isDirect': true,
        'onTap': () => _performDirectSearch(),
      });
    }
    
    // Add Google Places predictions
    for (final prediction in _predictions) {
      items.add({
        'title': prediction.mainText,
        'subtitle': prediction.secondaryText,
        'icon': Icons.location_on,
        'isDirect': false,
        'onTap': () => _selectPlace(prediction),
      });
    }
    
    return items;
  }
}