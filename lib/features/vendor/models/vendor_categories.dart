// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

class VendorCategories {
  static const List<String> all = [
    'Food & Beverage',
    'Arts & Crafts',
    'Clothing & Accessories',
    'Health & Beauty',
    'Home & Garden',
    'Other',
  ];

  static const String foodBeverage = 'Food & Beverage';
  static const String artsCrafts = 'Arts & Crafts';
  static const String clothing = 'Clothing & Accessories';
  static const String healthBeauty = 'Health & Beauty';
  static const String homeGarden = 'Home & Garden';
  static const String other = 'Other';

  // Group-based methods for category targeting
  static List<String> getGroupNames() {
    return ['All Categories'];
  }

  static List<String> getCategoriesForGroup(String group) {
    return all;
  }

  static List<String> searchCategories(String query) {
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all.where((cat) => cat.toLowerCase().contains(lowerQuery)).toList();
  }

  static String? getGroupForCategory(String category) {
    return all.contains(category) ? 'All Categories' : null;
  }
}
