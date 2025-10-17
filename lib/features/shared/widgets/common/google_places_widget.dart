import 'package:flutter/material.dart';
import 'package:atv_events/features/shared/services/location/places_service.dart';

class GooglePlacesWidget extends StatefulWidget {
  final Function(PlaceDetails) onPlaceSelected;
  final Function(String)? onTextSearch;
  final Function()? onCleared;
  final String? initialLocation;

  const GooglePlacesWidget({
    super.key,
    required this.onPlaceSelected,
    this.onTextSearch,
    this.onCleared,
    this.initialLocation,
  });

  @override
  State<GooglePlacesWidget> createState() => _GooglePlacesWidgetState();
}

class _GooglePlacesWidgetState extends State<GooglePlacesWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showPredictions = false;
  // Removed _isTyping field as it's no longer used
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
  }

  // Commented out didUpdateWidget to test if it's causing issues
  // @override
  // void didUpdateWidget(GooglePlacesWidget oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   // This might be interfering with place selection
  // }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _lastQuery = query;
    });

    // Add a small delay to avoid too many API calls while typing
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Check if query changed while we were waiting
    if (_lastQuery != query) {
      return;
    }

    if (query.length < 3) {
      setState(() {
        _predictions = [];
        _showPredictions = false;
        _isLoading = false;
        _hasSearched = query.isNotEmpty;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final predictions = await PlacesService.getPlacePredictions(query);
      
      // Only update if this is still the current query
      if (_lastQuery == query) {
        setState(() {
          _predictions = predictions;
          _showPredictions = _focusNode.hasFocus && predictions.isNotEmpty;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (_lastQuery == query) {
        setState(() {
          _predictions = [];
          _showPredictions = false;
          _hasSearched = true;
        });
      }
    } finally {
      if (_lastQuery == query) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    setState(() {
      _isLoading = true;
      _selectedPlaceId = placeId;
    });

    try {
      final placeDetails = await PlacesService.getPlaceDetails(placeId);
      
      if (placeDetails != null) {
        setState(() {
          _controller.text = placeDetails.formattedAddress;
          _predictions = [];
          _showPredictions = false;
          _selectedPlaceId = null;
        });
        
        _focusNode.unfocus();
        
        widget.onPlaceSelected(placeDetails);
      }
    } catch (e) {
      setState(() => _selectedPlaceId = null);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _performDirectSearch() {
    if (_controller.text.trim().isNotEmpty) {
      _focusNode.unfocus();
      setState(() {
        _predictions = [];
        _showPredictions = false;
      });
      
      // Create a fake PlaceDetails for the typed text
      final directPlaceDetails = PlaceDetails(
        placeId: 'direct_search_${_controller.text}',
        name: _controller.text.trim(),
        formattedAddress: _controller.text.trim(),
        latitude: 0.0, // Will be handled by the parent
        longitude: 0.0,
      );
      
      widget.onPlaceSelected(directPlaceDetails);
    }
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
        'placeId': null,
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
        'placeId': prediction.placeId,
        'onTap': () => _getPlaceDetails(prediction.placeId),
      });
    }
    
    return items;
  }

  // Removed _buildSuffixIcon method as we now use inline search button

  Widget _buildSearchFeedback() {
    if (_isLoading && _controller.text.length >= 3) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity( 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Searching for locations...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_hasSearched && _predictions.isEmpty && _controller.text.length >= 3 && !_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity( 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_off, color: Colors.grey[400], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No locations found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Try "Atlanta", "ATL", or a neighborhood name',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_controller.text.isNotEmpty && _controller.text.length < 3) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity( 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Type at least 3 characters to search',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Show helpful hint when field is focused but empty
    if (_focusNode.hasFocus && _controller.text.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity( 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Text(
                  'Search Tips',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Search by city, neighborhood, or address\n• Try "Atlanta", "ATL", "Buckhead", or "Decatur"\n• Use abbreviations like "ATL" for Atlanta',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity( 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: _isLoading ? 'Searching...' : 'Search for a location...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.location_on, color: Colors.orange),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _predictions = [];
                                _showPredictions = false;
                                _hasSearched = false;
                                _isLoading = false;
                                _selectedPlaceId = null;
                                _lastQuery = '';
                              });
                              if (widget.onCleared != null) {
                                widget.onCleared!();
                              }
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: _searchPlaces,
                  onSubmitted: (value) => _performDirectSearch(),
                  onTap: () {
                    if (_controller.text.isNotEmpty) {
                      setState(() => _showPredictions = true);
                    }
                  },
                ),
              ),
              // Search Button
              if (_controller.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _performDirectSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                              Icon(Icons.search, size: 18),
                              SizedBox(width: 4),
                              Text('Search'),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSearchFeedback(),
        if (_showPredictions && (_predictions.isNotEmpty || _controller.text.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity( 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _getSearchItems().length,
              itemBuilder: (context, index) {
                final item = _getSearchItems()[index];
                final isSelected = _selectedPlaceId == item['placeId'];
                
                return ListTile(
                  leading: Icon(
                    item['icon'] as IconData,
                    color: isSelected ? Colors.orange : (item['isDirect'] ? Colors.blue : Colors.grey),
                    size: 20,
                  ),
                  title: Text(
                    item['title'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected 
                          ? Colors.orange[700] 
                          : (item['isDirect'] ? Colors.blue[700] : Colors.black),
                    ),
                  ),
                  subtitle: item['subtitle'] != null && item['subtitle'].isNotEmpty
                      ? Text(
                          item['subtitle'],
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected 
                                ? Colors.orange[600] 
                                : (item['isDirect'] ? Colors.blue[600] : Colors.grey[700]),
                          ),
                        )
                      : null,
                  trailing: isSelected
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        )
                      : Icon(
                          item['isDirect'] ? Icons.search : Icons.north_west,
                          color: item['isDirect'] ? Colors.blue[400] : Colors.grey[400],
                          size: 16,
                        ),
                  onTap: isSelected ? null : item['onTap'],
                  dense: true,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}