import 'package:flutter/material.dart';
import 'package:atv_events/features/shared/services/user/search_history_service.dart';
import 'dart:async';
import '../../shopper/services/enhanced_search_service.dart';

/// Smart search field with real-time suggestions and auto-complete
class SmartSearchField extends StatefulWidget {
  final String? shopperId;
  final String hintText;
  final Function(String)? onSearchSubmitted;
  final Function(String)? onSuggestionSelected;
  final TextEditingController? controller;
  final bool showPopularSearches;
  final bool showSearchHistory;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final InputDecoration? decoration;

  const SmartSearchField({
    super.key,
    this.shopperId,
    this.hintText = 'Search for products, vendors, categories...',
    this.onSearchSubmitted,
    this.onSuggestionSelected,
    this.controller,
    this.showPopularSearches = true,
    this.showSearchHistory = true,
    this.prefixIcon,
    this.suffixIcon,
    this.decoration,
  });

  @override
  State<SmartSearchField> createState() => _SmartSearchFieldState();
}

class _SmartSearchFieldState extends State<SmartSearchField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  
  List<String> _suggestions = [];
  List<String> _popularSearches = [];
  List<String> _recentSearches = [];
  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _showSuggestionsOverlay();
    } else {
      // Delay hiding to allow for suggestion selection
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = true;
      });
      _updateOverlay();
      return;
    }

    // Debounce search suggestions
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _loadInitialData() async {
    try {
      // Load popular searches
      final popular = await EnhancedSearchService.getPersonalizedRecommendations(
        shopperId: widget.shopperId ?? '',
        limit: 5,
      );
      
      // Extract common product/category terms from recommendations
      final popularTerms = <String>{};
      for (final rec in popular) {
        final categories = List<String>.from(rec['categories'] ?? []);
        popularTerms.addAll(categories);
        
        final businessName = rec['businessName'] as String?;
        if (businessName != null && businessName.isNotEmpty) {
          // Extract meaningful terms from business names
          final words = businessName.toLowerCase().split(' ');
          for (final word in words) {
            if (word.length > 3 && !_isCommonWord(word)) {
              popularTerms.add(word);
            }
          }
        }
      }

      // Load recent searches if available
      if (widget.shopperId != null) {
        final recentSearches = await SearchHistoryService.getSearchHistory(
          shopperId: widget.shopperId!,
          limit: 10,
        );
        
        _recentSearches = recentSearches
            .map((search) => search['query'] as String)
            .where((query) => query.isNotEmpty)
            .toSet()
            .toList();
      }

      if (mounted) {
        setState(() {
          _popularSearches = popularTerms.take(8).toList();
        });
      }
    } catch (e) {
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> suggestions = [];

      // Get suggestions from search history if available
      if (widget.shopperId != null) {
        suggestions = await EnhancedSearchService.getSearchSuggestions(
          shopperId: widget.shopperId!,
          partialQuery: query,
          limit: 8,
        );
      }

      // Add common product suggestions if not enough from history
      if (suggestions.length < 5) {
        final commonSuggestions = _getCommonProductSuggestions(query);
        suggestions.addAll(commonSuggestions);
        
        // Remove duplicates and limit
        suggestions = suggestions.toSet().take(8).toList();
      }

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
          _showSuggestions = true;
        });
        _updateOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<String> _getCommonProductSuggestions(String query) {
    final common = [
      // Food items
      'honey', 'raw honey', 'local honey', 'wildflower honey',
      'bread', 'sourdough bread', 'artisan bread', 'whole grain bread',
      'vegetables', 'organic vegetables', 'fresh vegetables', 'seasonal vegetables',
      'tomatoes', 'cherry tomatoes', 'heirloom tomatoes',
      'lettuce', 'mixed greens', 'spinach', 'kale',
      'carrots', 'baby carrots', 'rainbow carrots',
      'onions', 'sweet onions', 'red onions',
      'potatoes', 'sweet potatoes', 'fingerling potatoes',
      'herbs', 'fresh herbs', 'basil', 'thyme', 'rosemary', 'cilantro',
      'fruits', 'seasonal fruits', 'berries', 'strawberries', 'blueberries',
      'apples', 'organic apples', 'local apples',
      'citrus', 'oranges', 'lemons', 'limes',
      'cheese', 'artisan cheese', 'goat cheese', 'local cheese',
      'milk', 'fresh milk', 'organic milk', 'goat milk',
      'eggs', 'free range eggs', 'farm fresh eggs', 'duck eggs',
      'meat', 'grass fed beef', 'free range chicken', 'local pork',
      'coffee', 'local coffee', 'roasted coffee', 'coffee beans',
      'tea', 'herbal tea', 'loose leaf tea', 'specialty tea',
      
      // Crafts and goods
      'flowers', 'fresh flowers', 'cut flowers', 'seasonal flowers',
      'plants', 'potted plants', 'succulents', 'herbs plants',
      'jewelry', 'handmade jewelry', 'silver jewelry', 'beaded jewelry',
      'pottery', 'handmade pottery', 'ceramic bowls', 'clay pots',
      'soap', 'handmade soap', 'natural soap', 'goat milk soap',
      'candles', 'soy candles', 'beeswax candles', 'scented candles',
      'woodworking', 'cutting boards', 'wooden bowls', 'handcrafted wood',
      'textiles', 'scarves', 'blankets', 'handwoven goods',
      'art', 'paintings', 'prints', 'handmade art',
      
      // Specialty items
      'preserves', 'jam', 'jelly', 'fruit preserves',
      'pickles', 'pickled vegetables', 'fermented foods',
      'spices', 'local spices', 'spice blends', 'seasonings',
      'sauces', 'hot sauce', 'salsa', 'marinades',
      'baked goods', 'pastries', 'cookies', 'muffins', 'pies',
    ];

    final queryLower = query.toLowerCase();
    return common
        .where((term) => term.toLowerCase().contains(queryLower))
        .toList();
  }

  bool _isCommonWord(String word) {
    const commonWords = {
      'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'had',
      'her', 'was', 'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his',
      'how', 'man', 'new', 'now', 'old', 'see', 'two', 'way', 'who', 'boy',
      'did', 'its', 'let', 'put', 'say', 'she', 'too', 'use', 'farm', 'local'
    };
    return commonWords.contains(word.toLowerCase());
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getSuggestionBoxWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, _getSuggestionBoxOffset()),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: _buildSuggestionsBox(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _showSuggestions = true;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showSuggestions = false;
  }

  void _updateOverlay() {
    if (_showSuggestions && _overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  double _getSuggestionBoxWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  double _getSuggestionBoxOffset() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return (renderBox?.size.height ?? 56) + 4;
  }

  Widget _buildSuggestionsBox() {
    if (_isLoading) {
      return Container(
        height: 80,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final query = _controller.text.trim();
    final showDefaultSuggestions = query.isEmpty;
    
    List<Widget> suggestionWidgets = [];

    if (showDefaultSuggestions) {
      // Show recent searches and popular searches when no query
      if (widget.showSearchHistory && _recentSearches.isNotEmpty) {
        suggestionWidgets.add(
          _buildSectionHeader('Recent Searches', Icons.history),
        );
        for (final search in _recentSearches.take(5)) {
          suggestionWidgets.add(_buildSuggestionItem(search, isRecent: true));
        }
      }

      if (widget.showPopularSearches && _popularSearches.isNotEmpty) {
        if (suggestionWidgets.isNotEmpty) {
          suggestionWidgets.add(const Divider(height: 1));
        }
        suggestionWidgets.add(
          _buildSectionHeader('Popular Searches', Icons.trending_up),
        );
        for (final search in _popularSearches.take(5)) {
          suggestionWidgets.add(_buildSuggestionItem(search, isPopular: true));
        }
      }
    } else {
      // Show query-based suggestions
      if (_suggestions.isNotEmpty) {
        suggestionWidgets.add(
          _buildSectionHeader('Suggestions', Icons.auto_awesome),
        );
        for (final suggestion in _suggestions) {
          suggestionWidgets.add(_buildSuggestionItem(suggestion, query: query));
        }
      }
    }

    if (suggestionWidgets.isEmpty) {
      return Container(
        height: 60,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'Start typing to see suggestions...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: suggestionWidgets,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(
    String suggestion, {
    String? query,
    bool isRecent = false,
    bool isPopular = false,
  }) {
    Widget leadingIcon;
    
    if (isRecent) {
      leadingIcon = Icon(Icons.history, size: 16, color: Colors.grey[600]);
    } else if (isPopular) {
      leadingIcon = Icon(Icons.trending_up, size: 16, color: Colors.orange[600]);
    } else {
      leadingIcon = Icon(Icons.search, size: 16, color: Colors.blue[600]);
    }

    Widget titleWidget;
    if (query != null && query.isNotEmpty) {
      // Highlight matching text
      titleWidget = _buildHighlightedText(suggestion, query);
    } else {
      titleWidget = Text(suggestion);
    }

    return InkWell(
      onTap: () => _onSuggestionTap(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leadingIcon,
            const SizedBox(width: 12),
            Expanded(child: titleWidget),
            if (isRecent)
              InkWell(
                onTap: () => _removeFromHistory(suggestion),
                child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final index = textLower.indexOf(queryLower);
    
    if (index == -1) {
      return Text(text);
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.yellow,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _removeOverlay();
    _focusNode.unfocus();
    
    if (widget.onSuggestionSelected != null) {
      widget.onSuggestionSelected!(suggestion);
    } else if (widget.onSearchSubmitted != null) {
      widget.onSearchSubmitted!(suggestion);
    }
  }

  void _removeFromHistory(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
    _updateOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: widget.decoration ?? InputDecoration(
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon ?? const Icon(Icons.search),
          suffixIcon: widget.suffixIcon ?? (
            _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _suggestions = [];
                      });
                    },
                  )
                : null
          ),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          _removeOverlay();
          if (widget.onSearchSubmitted != null) {
            widget.onSearchSubmitted!(value);
          }
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }
}