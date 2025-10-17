import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Custom marker icons for different types of locations
/// Implements product-category-based icons for enhanced user experience
class CustomMapMarkers {
  // Cache for generated bitmap descriptors
  static final Map<String, BitmapDescriptor> _markerCache = {};
  // Marker colors based on HiPop theme
  static const double marketHue = BitmapDescriptor.hueGreen;  // Green for markets
  static const double vendorHue = 240.0; // Blue for vendors (was purple at 200)
  static const double eventHue = 280.0; // Purple for events (was orange)
  
  // Product category hues for vendor markers (Phase 2)
  static const double vegetableHue = BitmapDescriptor.hueGreen;
  static const double bakedGoodsHue = 30.0; // Brown/Orange
  static const double craftsHue = BitmapDescriptor.hueMagenta;
  static const double flowerHue = BitmapDescriptor.hueRose;
  static const double meatHue = BitmapDescriptor.hueRed;
  static const double dairyHue = 60.0; // Yellow
  static const double beverageHue = BitmapDescriptor.hueAzure;
  static const double preparedFoodHue = BitmapDescriptor.hueOrange;
  
  /// Get marker icon for markets based on market type
  static Future<BitmapDescriptor> getMarketIcon({String? marketType}) async {
    // On web, use simple colored markers
    if (kIsWeb) {
      return Future.value(_getWebMarketTypeIcon(marketType));
    }
    
    // On mobile, use custom bitmap markers
    final cacheKey = 'market_${marketType ?? 'default'}';
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }
    
    // For iOS: Use HiPop sage color with storefront icon for all markets
    final color = HiPopColors.primaryDeepSage; // HiPop sage for all markets
    final icon = Icons.storefront; // Storefront icon for all markets
    
    final bitmap = await _createCustomMarkerBitmap(
      icon: icon,
      color: color,
      size: 60,
    );
    
    _markerCache[cacheKey] = bitmap;
    return bitmap;
  }
  
  /// Get marker icon for vendor posts with product-specific icons
  static Future<BitmapDescriptor> getVendorIcon({List<String>? vendorItems}) async {
    // On web, use simple colored markers instead of custom bitmaps
    if (kIsWeb) {
      if (vendorItems != null && vendorItems.isNotEmpty) {
        final primaryCategory = _determineVendorCategory(vendorItems);
        return Future.value(_getWebVendorCategoryIcon(primaryCategory));
      }
      return Future.value(BitmapDescriptor.defaultMarkerWithHue(vendorHue));
    }
    
    // On mobile, use custom bitmap markers
    if (vendorItems != null && vendorItems.isNotEmpty) {
      final primaryCategory = _determineVendorCategory(vendorItems);
      return await _getVendorCategoryIcon(primaryCategory);
    }
    return BitmapDescriptor.defaultMarkerWithHue(vendorHue);
  }
  
  /// Get marker icon for events
  static Future<BitmapDescriptor> getEventIcon() async {
    // On web, use simple colored markers
    if (kIsWeb) {
      return Future.value(BitmapDescriptor.defaultMarkerWithHue(eventHue));
    }
    
    // On mobile, use custom bitmap markers with plum color
    final cacheKey = 'event_standard';
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }
    
    final bitmap = await _createCustomMarkerBitmap(
      icon: Icons.event,
      color: HiPopColors.errorPlum,  // Plum color for events
      size: 60,
    );
    
    _markerCache[cacheKey] = bitmap;
    return bitmap;
  }
  
  // Enhanced helper method to determine vendor category based on items
  static String _determineVendorCategory(List<String> items) {
    // Expanded keywords for all 23 categories
    const Map<String, List<String>> categoryKeywords = {
      'vegetables': ['vegetable', 'veggie', 'produce', 'organic', 'farm fresh', 'greens', 'salad', 'tomato', 'lettuce', 'carrot', 'broccoli', 'spinach', 'kale', 'cucumber', 'pepper', 'onion', 'potato', 'corn', 'beans', 'peas'],
      'fruits': ['fruit', 'apple', 'orange', 'banana', 'berry', 'strawberry', 'blueberry', 'grape', 'melon', 'peach', 'pear', 'citrus', 'tropical', 'mango', 'pineapple'],
      'baked': ['baked', 'bread', 'pastry', 'cake', 'cookie', 'muffin', 'croissant', 'donut', 'bagel', 'sourdough', 'baguette', 'rolls', 'pie', 'tart'],
      'prepared': ['prepared', 'ready', 'meal', 'sandwich', 'wrap', 'salad', 'soup', 'hot food', 'lunch', 'dinner', 'entree', 'dish', 'bowl', 'plate'],
      'jewelry': ['jewelry', 'jewellery', 'necklace', 'bracelet', 'ring', 'earring', 'pendant', 'chain', 'gem', 'stone', 'silver', 'gold'],
      'crafts': ['craft', 'handmade', 'art', 'pottery', 'painting', 'sculpture', 'woodwork', 'leather', 'knit', 'crochet', 'quilt', 'embroidery'],
      'flowers': ['flower', 'bouquet', 'rose', 'lily', 'tulip', 'daisy', 'sunflower', 'orchid', 'arrangement', 'floral', 'bloom'],
      'plants': ['plant', 'succulent', 'cactus', 'herb', 'garden', 'seed', 'nursery', 'tree', 'shrub', 'potted'],
      'meat': ['meat', 'beef', 'pork', 'chicken', 'turkey', 'lamb', 'sausage', 'bacon', 'bbq', 'steak', 'ribs', 'ham', 'poultry'],
      'seafood': ['fish', 'seafood', 'salmon', 'tuna', 'shrimp', 'crab', 'lobster', 'oyster', 'sushi', 'marine'],
      'dairy': ['cheese', 'milk', 'yogurt', 'dairy', 'cream', 'butter', 'ice cream', 'cottage', 'mozzarella', 'cheddar'],
      'beverage': ['coffee', 'tea', 'juice', 'smoothie', 'drink', 'kombucha', 'lemonade', 'soda', 'water', 'latte', 'espresso', 'chai'],
      'spices': ['spice', 'seasoning', 'salt', 'pepper', 'herb', 'sauce', 'condiment', 'oil', 'vinegar', 'marinade', 'rub'],
      'sweets': ['sweet', 'candy', 'chocolate', 'dessert', 'sugar', 'honey', 'jam', 'jelly', 'fudge', 'caramel', 'truffle'],
      'organic': ['organic', 'natural', 'non-gmo', 'pesticide-free', 'sustainable', 'eco', 'green', 'farm', 'local'],
      'international': ['asian', 'mexican', 'italian', 'indian', 'thai', 'japanese', 'chinese', 'mediterranean', 'ethnic', 'import'],
      'health': ['health', 'wellness', 'vitamin', 'supplement', 'protein', 'vegan', 'gluten-free', 'keto', 'paleo', 'superfood'],
      'clothing': ['clothing', 'shirt', 'dress', 'pants', 'jacket', 'accessories', 'fashion', 'apparel', 'wear', 'outfit'],
      'home': ['home', 'decor', 'furniture', 'kitchen', 'bath', 'candle', 'soap', 'towel', 'pillow', 'blanket'],
      'beauty': ['beauty', 'cosmetic', 'makeup', 'skincare', 'lotion', 'cream', 'perfume', 'essential oil', 'bath bomb'],
      'books': ['book', 'magazine', 'comic', 'novel', 'reading', 'literature', 'author', 'publish', 'story'],
      'toys': ['toy', 'game', 'puzzle', 'doll', 'action figure', 'board game', 'educational', 'kids', 'children'],
      'pets': ['pet', 'dog', 'cat', 'animal', 'treat', 'food', 'collar', 'leash', 'bird', 'fish']
    };
    
    // Initialize scores for all categories
    Map<String, int> categoryScores = {};
    categoryKeywords.forEach((category, _) {
      categoryScores[category] = 0;
    });
    
    // Score each item against all categories
    for (String item in items) {
      final lowerItem = item.toLowerCase();
      
      categoryKeywords.forEach((category, keywords) {
        for (String keyword in keywords) {
          if (lowerItem.contains(keyword)) {
            categoryScores[category] = categoryScores[category]! + 1;
            break; // Only count once per item per category
          }
        }
      });
    }
    
    // Find the category with the highest score
    String primaryCategory = 'general';
    int highestScore = 0;
    
    categoryScores.forEach((category, score) {
      if (score > highestScore) {
        highestScore = score;
        primaryCategory = category;
      }
    });
    
    return primaryCategory;
  }
  
  // Get icon based on vendor category with custom rendering
  static Future<BitmapDescriptor> _getVendorCategoryIcon(String category) async {
    // Check cache first
    final cacheKey = 'vendor_$category';
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }
    
    // Get category-specific icon and color
    final iconData = _getCategoryIcon(category);
    final color = _getCategoryColor(category);
    
    // Generate custom marker with smaller size
    final bitmap = await _createCustomMarkerBitmap(
      icon: iconData,
      color: color,
      size: 60,  // Reduced from 120 to 60 for smaller markers
    );
    
    // Cache and return
    _markerCache[cacheKey] = bitmap;
    return bitmap;
  }
  
  /// Get icon for specific product category
  static IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'vegetables':
        return Icons.eco; // Green/organic icon
      case 'baked':
        return Icons.bakery_dining; // Bakery icon
      case 'crafts':
        return Icons.palette; // Arts & crafts
      case 'flowers':
        return Icons.local_florist; // Flower icon
      case 'meat':
        return Icons.lunch_dining; // Meat/protein icon
      case 'dairy':
        return Icons.egg; // Dairy products
      case 'beverage':
        return Icons.local_cafe; // Coffee/drinks
      case 'prepared':
        return Icons.restaurant; // Prepared foods
      case 'fruits':
        return Icons.apple; // Fruits
      case 'seafood':
        return Icons.set_meal; // Seafood
      case 'spices':
        return Icons.grain; // Spices & grains
      case 'sweets':
        return Icons.cake; // Desserts & sweets
      case 'organic':
        return Icons.verified; // Organic/certified
      case 'international':
        return Icons.public; // International foods
      case 'health':
        return Icons.spa; // Health & wellness
      case 'jewelry':
        return Icons.diamond; // Jewelry
      case 'clothing':
        return Icons.checkroom; // Clothing
      case 'home':
        return Icons.home; // Home goods
      case 'beauty':
        return Icons.face; // Beauty products
      case 'books':
        return Icons.menu_book; // Books & media
      case 'toys':
        return Icons.toys; // Toys & games
      case 'pets':
        return Icons.pets; // Pet products
      case 'plants':
        return Icons.park; // Plants & garden
      default:
        return Icons.store; // Default vendor icon
    }
  }
  
  /// Get color for specific product category
  static Color _getCategoryColor(String category) {
    switch (category) {
      case 'vegetables':
        return const Color(0xFF4CAF50); // Green
      case 'baked':
        return const Color(0xFF8D6E63); // Brown
      case 'crafts':
        return const Color(0xFF9C27B0); // Purple
      case 'flowers':
        return const Color(0xFFE91E63); // Pink
      case 'meat':
        return const Color(0xFFD32F2F); // Red
      case 'dairy':
        return const Color(0xFFFFC107); // Amber
      case 'beverage':
        return const Color(0xFF795548); // Coffee brown
      case 'prepared':
        return const Color(0xFFFF6F00); // Deep orange
      case 'fruits':
        return const Color(0xFFFF5722); // Orange-red
      case 'seafood':
        return const Color(0xFF0288D1); // Light blue
      case 'spices':
        return const Color(0xFFBF360C); // Deep orange
      case 'sweets':
        return const Color(0xFFAD1457); // Pink
      case 'organic':
        return const Color(0xFF2E7D32); // Dark green
      case 'international':
        return const Color(0xFF1565C0); // Blue
      case 'health':
        return const Color(0xFF00897B); // Teal
      case 'jewelry':
        return const Color(0xFF6A1B9A); // Deep purple
      case 'clothing':
        return const Color(0xFF5E35B1); // Deep purple
      case 'home':
        return const Color(0xFF6D4C41); // Brown
      case 'beauty':
        return const Color(0xFFEC407A); // Pink
      case 'books':
        return const Color(0xFF37474F); // Blue grey
      case 'toys':
        return const Color(0xFFFDD835); // Yellow
      case 'pets':
        return const Color(0xFF8BC34A); // Light green
      case 'plants':
        return const Color(0xFF388E3C); // Green
      default:
        return HiPopColors.vendorAccent; // Default vendor color
    }
  }
  
  /// Create custom marker bitmap from icon
  static Future<BitmapDescriptor> _createCustomMarkerBitmap({
    required IconData icon,
    required Color color,
    required int size,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();
    
    // Draw outer circle (white border)
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      paint,
    );
    
    // Draw inner circle (colored background)
    paint.color = color;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      (size / 2) - 3,
      paint,
    );
    
    // Draw pin point at bottom
    final path = Path();
    path.moveTo(size * 0.4, size * 0.85);
    path.lineTo(size / 2, size * 1.0);
    path.lineTo(size * 0.6, size * 0.85);
    path.close();
    canvas.drawPath(path, paint);
    
    // Draw icon
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: icon.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size * 0.7 - textPainter.height) / 2,
      ),
    );
    
    // Add shadow
    paint.color = Colors.black.withOpacity( 0.3);
    canvas.drawCircle(
      Offset(size / 2 + 2, size / 2 + 2),
      size / 2.5,
      paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size, (size * 1.1).toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.bytes(bytes);
  }
  
  /// Create enhanced market marker with market type support
  static Future<BitmapDescriptor> getEnhancedMarketIcon({String? marketType}) async {
    // Use the new getMarketIcon method that supports market types
    return getMarketIcon(marketType: marketType);
  }
  
  /// Create enhanced event marker
  static Future<BitmapDescriptor> getEnhancedEventIcon() async {
    // On web, use simple colored markers
    if (kIsWeb) {
      return Future.value(BitmapDescriptor.defaultMarkerWithHue(eventHue));
    }
    
    // On mobile, use custom bitmap markers
    final cacheKey = 'event_enhanced';
    if (_markerCache.containsKey(cacheKey)) {
      return _markerCache[cacheKey]!;
    }
    
    final bitmap = await _createCustomMarkerBitmap(
      icon: Icons.event,
      color: HiPopColors.errorPlum,  // Plum color for events
      size: 60,  // Reduced from 120 to 60 for smaller markers
    );
    
    _markerCache[cacheKey] = bitmap;
    return bitmap;
  }
  
  /// Clear marker cache (call when needed to free memory)
  static void clearCache() {
    _markerCache.clear();
  }
  
  /// Get icon data for different location types
  static IconData getIconForType(String type) {
    switch (type) {
      case 'market':
        return Icons.store_mall_directory;
      case 'vendor':
        return Icons.store;
      case 'event':
        return Icons.event;
      default:
        return Icons.location_on;
    }
  }
  
  /// Get color for different location types based on HiPop theme
  static Color getColorForType(String type) {
    switch (type) {
      case 'market':
        return HiPopColors.primaryDeepSage;  // Sage for markets
      case 'vendor':
        return HiPopColors.vendorAccent;  // Keep vendor colors based on product chips
      case 'event':
        return HiPopColors.errorPlum;  // Plum for events
      default:
        return HiPopColors.shopperAccent;
    }
  }
  
  /// Get color for specific market type based on requirements
  static Color _getMarketTypeColor(String? marketType) {
    switch (marketType) {
      case 'farmers':
        return HiPopColors.successGreen; // Green for farmers markets
      case 'popup':
        return HiPopColors.accentMauve; // Purple/Mauve for pop-up markets
      case 'vegan':
        return const Color(0xFF00897B); // Teal for vegan markets
      case 'art':
        return HiPopColors.warningAmber; // Orange for art markets
      case 'craft':
        return const Color(0xFF9C27B0); // Purple for craft markets
      case 'night':
        return const Color(0xFF37474F); // Dark blue-gray for night markets
      case 'holiday':
        return const Color(0xFFD32F2F); // Red for holiday markets
      case 'flea':
        return const Color(0xFF8D6E63); // Brown for flea markets
      case 'food':
        return const Color(0xFFFF6F00); // Deep orange for food truck markets
      default:
        return HiPopColors.primaryDeepSage; // Brand color for default
    }
  }
  
  /// Get icon data for specific market type
  static IconData _getMarketTypeIconData(String? marketType) {
    switch (marketType) {
      case 'farmers':
        return Icons.agriculture; // Farm icon
      case 'popup':
        return Icons.store_mall_directory; // Pop-up icon
      case 'vegan':
        return Icons.eco; // Leaf icon for vegan
      case 'art':
        return Icons.palette; // Art palette
      case 'craft':
        return Icons.handyman; // Craft/handmade icon
      case 'night':
        return Icons.nightlight_round; // Night market icon
      case 'holiday':
        return Icons.celebration; // Holiday celebration
      case 'flea':
        return Icons.storefront; // Flea market storefront
      case 'food':
        return Icons.fastfood; // Food truck icon
      default:
        return Icons.store_mall_directory; // Default market icon
    }
  }
  
  /// Get web-compatible market type icon (using hue values)
  static BitmapDescriptor _getWebMarketTypeIcon(String? marketType) {
    double hue;
    switch (marketType) {
      case 'farmers':
        hue = BitmapDescriptor.hueGreen; // Green
        break;
      case 'popup':
        hue = 280.0; // Mauve/Purple
        break;
      case 'vegan':
        hue = BitmapDescriptor.hueCyan; // Teal
        break;
      case 'art':
        hue = 30.0; // Orange
        break;
      case 'craft':
        hue = BitmapDescriptor.hueMagenta; // Purple
        break;
      case 'night':
        hue = 210.0; // Dark blue
        break;
      case 'holiday':
        hue = BitmapDescriptor.hueRed; // Red
        break;
      case 'flea':
        hue = 35.0; // Brown
        break;
      case 'food':
        hue = BitmapDescriptor.hueOrange; // Deep orange
        break;
      default:
        hue = 150.0; // Deep sage green-ish
    }
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }
  
  /// Get web-compatible vendor category icon (using hue values)
  static BitmapDescriptor _getWebVendorCategoryIcon(String category) {
    // Map categories to hue values for web markers
    double hue;
    switch (category) {
      case 'vegetables':
        hue = BitmapDescriptor.hueGreen;
        break;
      case 'baked':
        hue = 30.0; // Brown/Orange
        break;
      case 'crafts':
        hue = BitmapDescriptor.hueMagenta;
        break;
      case 'flowers':
        hue = BitmapDescriptor.hueRose;
        break;
      case 'meat':
        hue = BitmapDescriptor.hueRed;
        break;
      case 'dairy':
        hue = 60.0; // Yellow
        break;
      case 'beverage':
        hue = 195.0; // Light blue
        break;
      case 'prepared':
        hue = BitmapDescriptor.hueOrange;
        break;
      case 'fruits':
        hue = 20.0; // Orange-red
        break;
      case 'seafood':
        hue = BitmapDescriptor.hueAzure;
        break;
      case 'spices':
        hue = 15.0; // Deep orange
        break;
      case 'sweets':
        hue = 320.0; // Pink
        break;
      case 'organic':
        hue = 120.0; // Dark green
        break;
      case 'international':
        hue = BitmapDescriptor.hueBlue;
        break;
      case 'health':
        hue = BitmapDescriptor.hueCyan;
        break;
      case 'jewelry':
        hue = BitmapDescriptor.hueViolet;
        break;
      case 'clothing':
        hue = 260.0; // Deep purple
        break;
      case 'home':
        hue = 35.0; // Brown
        break;
      case 'beauty':
        hue = 330.0; // Pink
        break;
      case 'books':
        hue = 210.0; // Blue grey
        break;
      case 'toys':
        hue = BitmapDescriptor.hueYellow;
        break;
      case 'pets':
        hue = 90.0; // Light green
        break;
      case 'plants':
        hue = 140.0; // Green
        break;
      default:
        hue = vendorHue; // Default vendor blue
    }
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }
}