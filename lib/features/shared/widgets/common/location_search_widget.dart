import 'package:flutter/material.dart';

class LocationSearchWidget extends StatefulWidget {
  final Function(String) onLocationChanged;
  final String? initialLocation;

  const LocationSearchWidget({
    super.key,
    required this.onLocationChanged,
    this.initialLocation,
  });

  @override
  State<LocationSearchWidget> createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;
  List<String> _suggestions = [];

  final List<String> _popularLocations = [
    'Atlanta, GA',
    'Midtown Atlanta',
    'Buckhead',
    'Virginia-Highland',
    'Little Five Points',
    'Inman Park',
    'Decatur',
    'Alpharetta',
    'Sandy Springs',
    'Roswell',
    'Marietta',
    'Smyrna',
    'East Atlanta',
    'West End',
    'Grant Park',
    'Old Fourth Ward',
    'Poncey-Highland',
    'Candler Park',
    'Reynoldstown',
    'Cabbagetown',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _controller.text = widget.initialLocation!;
    }
    
    _focusNode.addListener(() {
      setState(() {
        _isExpanded = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filterSuggestions(String query) {
    setState(() {
      if (query.isEmpty) {
        _suggestions = _popularLocations.take(5).toList();
      } else {
        _suggestions = _popularLocations
            .where((location) =>
                location.toLowerCase().contains(query.toLowerCase()))
            .take(5)
            .toList();
      }
    });
  }

  void _selectLocation(String location) {
    _controller.text = location;
    widget.onLocationChanged(location);
    _focusNode.unfocus();
    setState(() {
      _isExpanded = false;
      _suggestions.clear();
    });
  }

  void _clearLocation() {
    _controller.clear();
    widget.onLocationChanged('');
    _filterSuggestions('');
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
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Search by location...',
              prefixIcon: const Icon(Icons.location_on, color: Colors.orange),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: _clearLocation,
                    )
                  : const Icon(Icons.search, color: Colors.grey),
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
            onChanged: (value) {
              widget.onLocationChanged(value);
              _filterSuggestions(value);
            },
            onTap: () {
              _filterSuggestions(_controller.text);
            },
          ),
        ),
        if (_isExpanded && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
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
            child: Column(
              children: [
                if (_controller.text.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.location_city, 
                             color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Popular Locations',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ..._suggestions.map((location) => InkWell(
                  onTap: () => _selectLocation(location),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity( 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, 
                             color: Colors.grey, size: 16),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.north_west, 
                             color: Colors.grey, size: 16),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}