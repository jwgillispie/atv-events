import 'package:shared_preferences/shared_preferences.dart';

class FavoritesRepository {
  static const String _favoriteVendorsKey = 'favorite_vendors';
  static const String _favoritePostsKey = 'favorite_posts';
  static const String _favoriteMarketsKey = 'favorite_markets';
  static const String _favoriteProductsKey = 'favorite_products';

  // Favorite vendor posts
  Future<List<String>> getFavoritePostIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoritePostsKey) ?? [];
    return favoritesJson;
  }

  Future<void> addFavoritePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoritePostIds();
    if (!favorites.contains(postId)) {
      favorites.add(postId);
      await prefs.setStringList(_favoritePostsKey, favorites);
    }
  }

  Future<void> removeFavoritePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoritePostIds();
    favorites.remove(postId);
    await prefs.setStringList(_favoritePostsKey, favorites);
  }

  Future<bool> isPostFavorite(String postId) async {
    final favorites = await getFavoritePostIds();
    return favorites.contains(postId);
  }

  // Favorite vendors
  Future<List<String>> getFavoriteVendorIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteVendorsKey) ?? [];
    return favoritesJson;
  }

  Future<void> addFavoriteVendor(String vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteVendorIds();
    if (!favorites.contains(vendorId)) {
      favorites.add(vendorId);
      await prefs.setStringList(_favoriteVendorsKey, favorites);
    }
  }

  Future<void> removeFavoriteVendor(String vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteVendorIds();
    favorites.remove(vendorId);
    await prefs.setStringList(_favoriteVendorsKey, favorites);
  }

  Future<bool> isVendorFavorite(String vendorId) async {
    final favorites = await getFavoriteVendorIds();
    return favorites.contains(vendorId);
  }

  // Favorite markets
  Future<List<String>> getFavoriteMarketIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteMarketsKey) ?? [];
    return favoritesJson;
  }

  Future<void> addFavoriteMarket(String marketId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteMarketIds();
    if (!favorites.contains(marketId)) {
      favorites.add(marketId);
      await prefs.setStringList(_favoriteMarketsKey, favorites);
    }
  }

  Future<void> removeFavoriteMarket(String marketId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteMarketIds();
    favorites.remove(marketId);
    await prefs.setStringList(_favoriteMarketsKey, favorites);
  }

  Future<bool> isMarketFavorite(String marketId) async {
    final favorites = await getFavoriteMarketIds();
    return favorites.contains(marketId);
  }

  // Favorite products
  Future<List<String>> getFavoriteProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteProductsKey) ?? [];
    return favoritesJson;
  }

  Future<void> addFavoriteProduct(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteProductIds();
    if (!favorites.contains(productId)) {
      favorites.add(productId);
      await prefs.setStringList(_favoriteProductsKey, favorites);
    }
  }

  Future<void> removeFavoriteProduct(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavoriteProductIds();
    favorites.remove(productId);
    await prefs.setStringList(_favoriteProductsKey, favorites);
  }

  Future<bool> isProductFavorite(String productId) async {
    final favorites = await getFavoriteProductIds();
    return favorites.contains(productId);
  }

  // Clear all favorites (useful for logout)
  Future<void> clearAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritePostsKey);
    await prefs.remove(_favoriteVendorsKey);
    await prefs.remove(_favoriteMarketsKey);
    await prefs.remove(_favoriteProductsKey);
  }

  // Get favorites count
  Future<int> getFavoritesCount() async {
    final posts = await getFavoritePostIds();
    final vendors = await getFavoriteVendorIds();
    final markets = await getFavoriteMarketIds();
    final products = await getFavoriteProductIds();
    return posts.length + vendors.length + markets.length + products.length;
  }
}