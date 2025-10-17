import 'package:flutter/foundation.dart';
import 'package:atv_events/features/shared/services/user/favorites_service.dart';
import 'package:atv_events/features/shared/models/user_favorite.dart';
import 'package:atv_events/repositories/shopper/favorites_repository.dart';


class FavoritesMigrationService {
  static final FavoritesRepository _localRepository = FavoritesRepository();

  /// Migrates local favorites to user account when user logs in
  static Future<void> migrateLocalFavoritesToUser(String userId) async {
    try {
      // Get existing local favorites
      final localPostIds = await _localRepository.getFavoritePostIds();
      final localVendorIds = await _localRepository.getFavoriteVendorIds();
      final localMarketIds = await _localRepository.getFavoriteMarketIds();

      // Check if user already has cloud favorites to avoid duplicates
      final existingVendorFavorites = await FavoritesService.getUserFavoriteVendors(userId);
      final existingMarketFavorites = await FavoritesService.getUserFavoriteMarkets(userId);
      
      final existingVendorIds = existingVendorFavorites.map((v) => v.id).toSet();
      final existingMarketIds = existingMarketFavorites.map((m) => m.id).toSet();

      // Migrate vendor favorites
      for (final vendorId in localVendorIds) {
        if (!existingVendorIds.contains(vendorId)) {
          try {
            await FavoritesService.addFavorite(
              userId: userId,
              itemId: vendorId,
              type: FavoriteType.vendor,
            );
          } catch (e) {
          }
        }
      }

      // Migrate market favorites
      for (final marketId in localMarketIds) {
        if (!existingMarketIds.contains(marketId)) {
          try {
            await FavoritesService.addFavorite(
              userId: userId,
              itemId: marketId,
              type: FavoriteType.market,
            );
          } catch (e) {
          }
        }
      }

      // Note: Post favorites are not migrated as they're not supported in Firestore service yet
      if (localPostIds.isNotEmpty) {
      }

    } catch (e) {
      throw Exception('Failed to migrate favorites: $e');
    }
  }

  /// Checks if local favorites exist (to decide whether migration is needed)
  static Future<bool> hasLocalFavorites() async {
    try {
      final localPostIds = await _localRepository.getFavoritePostIds();
      final localVendorIds = await _localRepository.getFavoriteVendorIds();
      final localMarketIds = await _localRepository.getFavoriteMarketIds();

      return localPostIds.isNotEmpty || localVendorIds.isNotEmpty || localMarketIds.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clears local favorites after successful migration
  static Future<void> clearLocalFavoritesAfterMigration() async {
    try {
      await _localRepository.clearAllFavorites();
    } catch (e) {
    }
  }

  /// Gets count of local favorites for migration preview
  static Future<Map<String, int>> getLocalFavoritesCounts() async {
    try {
      final localPostIds = await _localRepository.getFavoritePostIds();
      final localVendorIds = await _localRepository.getFavoriteVendorIds();
      final localMarketIds = await _localRepository.getFavoriteMarketIds();

      return {
        'posts': localPostIds.length,
        'vendors': localVendorIds.length,
        'markets': localMarketIds.length,
      };
    } catch (e) {
      return {'posts': 0, 'vendors': 0, 'markets': 0};
    }
  }
}