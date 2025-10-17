import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../features/shared/services/user/favorites_service.dart';
import '../../features/shared/models/user_favorite.dart';
import '../../repositories/shopper/favorites_repository.dart';

part 'favorites_event.dart';
part 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritesRepository _favoritesRepository;

  FavoritesBloc({
    required FavoritesRepository favoritesRepository,
  }) : _favoritesRepository = favoritesRepository,
       super(const FavoritesState()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<TogglePostFavorite>(_onTogglePostFavorite);
    on<ToggleVendorFavorite>(_onToggleVendorFavorite);
    on<ToggleMarketFavorite>(_onToggleMarketFavorite);
    on<ToggleEventFavorite>(_onToggleEventFavorite);
    on<ToggleProductFavorite>(_onToggleProductFavorite);
    on<ClearAllFavorites>(_onClearAllFavorites);
  }

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    // Only show loading for initial load or when switching users
    if (state.status != FavoritesStatus.loaded) {
      emit(state.copyWith(status: FavoritesStatus.loading));
    }
    
    try {
      List<String> favoritePostIds = [];
      List<String> favoriteVendorIds = [];
      List<String> favoriteMarketIds = [];
      List<String> favoriteEventIds = [];
      List<String> favoriteProductIds = [];

      if (event.userId != null) {
        // Use Firestore service for authenticated users - fetch IDs only for fast loading
        favoriteVendorIds = await FavoritesService.getUserFavoriteVendorIds(event.userId!);
        favoriteMarketIds = await FavoritesService.getUserFavoriteMarketIds(event.userId!);
        favoriteEventIds = await FavoritesService.getUserFavoriteEventIds(event.userId!);
        favoriteProductIds = await FavoritesService.getUserFavoriteProductIds(event.userId!);

        // Note: Posts are not supported in Firestore service yet, keep local for now
        favoritePostIds = await _favoritesRepository.getFavoritePostIds();
      } else {
        // Use local repository for anonymous users
        favoritePostIds = await _favoritesRepository.getFavoritePostIds();
        favoriteVendorIds = await _favoritesRepository.getFavoriteVendorIds();
        favoriteMarketIds = await _favoritesRepository.getFavoriteMarketIds();
        favoriteProductIds = await _favoritesRepository.getFavoriteProductIds();
        // Events are not supported in local repository yet
      }

      emit(state.copyWith(
        status: FavoritesStatus.loaded,
        favoritePostIds: favoritePostIds,
        favoriteVendorIds: favoriteVendorIds,
        favoriteMarketIds: favoriteMarketIds,
        favoriteEventIds: favoriteEventIds,
        favoriteProductIds: favoriteProductIds,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onTogglePostFavorite(
    TogglePostFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final updatedFavoritePostIds = List<String>.from(state.favoritePostIds);
      
      // OPTIMISTIC UPDATE - Update UI immediately
      final wasAlreadyFavorited = updatedFavoritePostIds.contains(event.postId);
      if (wasAlreadyFavorited) {
        updatedFavoritePostIds.remove(event.postId);
      } else {
        updatedFavoritePostIds.add(event.postId);
      }
      
      // Emit optimistic state immediately for instant UI feedback
      emit(state.copyWith(favoritePostIds: updatedFavoritePostIds));
      
      // Then perform the async database operation
      try {
        if (wasAlreadyFavorited) {
          await _favoritesRepository.removeFavoritePost(event.postId);
        } else {
          await _favoritesRepository.addFavoritePost(event.postId);
        }
      } catch (dbError) {
        // Revert optimistic update on database error
        final revertedFavoritePostIds = List<String>.from(state.favoritePostIds);
        if (wasAlreadyFavorited) {
          revertedFavoritePostIds.add(event.postId);
        } else {
          revertedFavoritePostIds.remove(event.postId);
        }
        emit(state.copyWith(favoritePostIds: revertedFavoritePostIds));
        rethrow;
      }
    } catch (error) {
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onToggleVendorFavorite(
    ToggleVendorFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final updatedFavoriteVendorIds = List<String>.from(state.favoriteVendorIds);
      
      // OPTIMISTIC UPDATE - Update UI immediately
      final wasAlreadyFavorited = updatedFavoriteVendorIds.contains(event.vendorId);
      if (wasAlreadyFavorited) {
        updatedFavoriteVendorIds.remove(event.vendorId);
      } else {
        updatedFavoriteVendorIds.add(event.vendorId);
      }
      
      // Emit optimistic state immediately for instant UI feedback
      emit(state.copyWith(favoriteVendorIds: updatedFavoriteVendorIds));
      
      // Then perform the async database operation
      if (event.userId != null) {
        // Use Firestore service for authenticated users
        try {
          final newIsFavorited = await FavoritesService.toggleFavorite(
            userId: event.userId!,
            itemId: event.vendorId,
            type: FavoriteType.vendor,
          );
          
          // Verify the result matches our optimistic update
          final finalFavoriteVendorIds = List<String>.from(updatedFavoriteVendorIds);
          if (newIsFavorited && !finalFavoriteVendorIds.contains(event.vendorId)) {
            finalFavoriteVendorIds.add(event.vendorId);
          } else if (!newIsFavorited && finalFavoriteVendorIds.contains(event.vendorId)) {
            finalFavoriteVendorIds.remove(event.vendorId);
          }
          
          // Only emit again if the final state differs from optimistic state
          if (finalFavoriteVendorIds.length != updatedFavoriteVendorIds.length ||
              !finalFavoriteVendorIds.every((id) => updatedFavoriteVendorIds.contains(id))) {
            emit(state.copyWith(favoriteVendorIds: finalFavoriteVendorIds));
          }
        } catch (dbError) {
          // Revert optimistic update on database error
          final revertedFavoriteVendorIds = List<String>.from(state.favoriteVendorIds);
          if (wasAlreadyFavorited) {
            revertedFavoriteVendorIds.add(event.vendorId);
          } else {
            revertedFavoriteVendorIds.remove(event.vendorId);
          }
          emit(state.copyWith(favoriteVendorIds: revertedFavoriteVendorIds));
          rethrow;
        }
      } else {
        // Use local repository for anonymous users
        try {
          if (wasAlreadyFavorited) {
            await _favoritesRepository.removeFavoriteVendor(event.vendorId);
          } else {
            await _favoritesRepository.addFavoriteVendor(event.vendorId);
          }
        } catch (dbError) {
          // Revert optimistic update on database error
          final revertedFavoriteVendorIds = List<String>.from(state.favoriteVendorIds);
          if (wasAlreadyFavorited) {
            revertedFavoriteVendorIds.add(event.vendorId);
          } else {
            revertedFavoriteVendorIds.remove(event.vendorId);
          }
          emit(state.copyWith(favoriteVendorIds: revertedFavoriteVendorIds));
          rethrow;
        }
      }
    } catch (error) {
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onToggleMarketFavorite(
    ToggleMarketFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final updatedFavoriteMarketIds = List<String>.from(state.favoriteMarketIds);
      
      // OPTIMISTIC UPDATE - Update UI immediately
      final wasAlreadyFavorited = updatedFavoriteMarketIds.contains(event.marketId);
      if (wasAlreadyFavorited) {
        updatedFavoriteMarketIds.remove(event.marketId);
      } else {
        updatedFavoriteMarketIds.add(event.marketId);
      }
      
      // Emit optimistic state immediately for instant UI feedback
      emit(state.copyWith(favoriteMarketIds: updatedFavoriteMarketIds));
      
      // Then perform the async database operation
      if (event.userId != null) {
        // Use Firestore service for authenticated users
        try {
          final newIsFavorited = await FavoritesService.toggleFavorite(
            userId: event.userId!,
            itemId: event.marketId,
            type: FavoriteType.market,
          );
          
          // Verify the result matches our optimistic update
          final finalFavoriteMarketIds = List<String>.from(updatedFavoriteMarketIds);
          if (newIsFavorited && !finalFavoriteMarketIds.contains(event.marketId)) {
            finalFavoriteMarketIds.add(event.marketId);
          } else if (!newIsFavorited && finalFavoriteMarketIds.contains(event.marketId)) {
            finalFavoriteMarketIds.remove(event.marketId);
          }
          
          // Only emit again if the final state differs from optimistic state
          if (finalFavoriteMarketIds.length != updatedFavoriteMarketIds.length ||
              !finalFavoriteMarketIds.every((id) => updatedFavoriteMarketIds.contains(id))) {
            emit(state.copyWith(favoriteMarketIds: finalFavoriteMarketIds));
          }
        } catch (dbError) {
          // Revert optimistic update on database error
          final revertedFavoriteMarketIds = List<String>.from(state.favoriteMarketIds);
          if (wasAlreadyFavorited) {
            revertedFavoriteMarketIds.add(event.marketId);
          } else {
            revertedFavoriteMarketIds.remove(event.marketId);
          }
          emit(state.copyWith(favoriteMarketIds: revertedFavoriteMarketIds));
          rethrow;
        }
      } else {
        // Use local repository for anonymous users
        try {
          if (wasAlreadyFavorited) {
            await _favoritesRepository.removeFavoriteMarket(event.marketId);
          } else {
            await _favoritesRepository.addFavoriteMarket(event.marketId);
          }
        } catch (dbError) {
          // Revert optimistic update on database error
          final revertedFavoriteMarketIds = List<String>.from(state.favoriteMarketIds);
          if (wasAlreadyFavorited) {
            revertedFavoriteMarketIds.add(event.marketId);
          } else {
            revertedFavoriteMarketIds.remove(event.marketId);
          }
          emit(state.copyWith(favoriteMarketIds: revertedFavoriteMarketIds));
          rethrow;
        }
      }
    } catch (error) {
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onToggleEventFavorite(
    ToggleEventFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final updatedFavoriteEventIds = List<String>.from(state.favoriteEventIds);
      
      // OPTIMISTIC UPDATE - Update UI immediately
      final wasAlreadyFavorited = updatedFavoriteEventIds.contains(event.eventId);
      if (wasAlreadyFavorited) {
        updatedFavoriteEventIds.remove(event.eventId);
      } else {
        updatedFavoriteEventIds.add(event.eventId);
      }
      
      // Emit optimistic state immediately for instant UI feedback
      emit(state.copyWith(favoriteEventIds: updatedFavoriteEventIds));
      
      // Then perform the async database operation
      if (event.userId != null) {
        // Use Firestore service for authenticated users
        try {
          final newIsFavorited = await FavoritesService.toggleFavorite(
            userId: event.userId!,
            itemId: event.eventId,
            type: FavoriteType.event,
          );
          
          // Verify the result matches our optimistic update
          final finalFavoriteEventIds = List<String>.from(updatedFavoriteEventIds);
          if (newIsFavorited && !finalFavoriteEventIds.contains(event.eventId)) {
            finalFavoriteEventIds.add(event.eventId);
          } else if (!newIsFavorited && finalFavoriteEventIds.contains(event.eventId)) {
            finalFavoriteEventIds.remove(event.eventId);
          }
          
          // Only emit again if the final state differs from optimistic state
          if (finalFavoriteEventIds.length != updatedFavoriteEventIds.length ||
              !finalFavoriteEventIds.every((id) => updatedFavoriteEventIds.contains(id))) {
            emit(state.copyWith(favoriteEventIds: finalFavoriteEventIds));
          }
        } catch (dbError) {
          // Revert optimistic update on database error
          final revertedFavoriteEventIds = List<String>.from(state.favoriteEventIds);
          if (wasAlreadyFavorited) {
            revertedFavoriteEventIds.add(event.eventId);
          } else {
            revertedFavoriteEventIds.remove(event.eventId);
          }
          emit(state.copyWith(favoriteEventIds: revertedFavoriteEventIds));
          rethrow;
        }
      } else {
        // For now, events are not supported in local repository
        // This would need to be implemented if anonymous users need to favorite events
        emit(state.copyWith(favoriteEventIds: updatedFavoriteEventIds));
      }
    } catch (error) {
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onToggleProductFavorite(
    ToggleProductFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final updatedFavoriteProductIds = List<String>.from(state.favoriteProductIds);

      // OPTIMISTIC UPDATE - Update UI immediately
      final wasAlreadyFavorited = updatedFavoriteProductIds.contains(event.productId);
      if (wasAlreadyFavorited) {
        updatedFavoriteProductIds.remove(event.productId);
      } else {
        updatedFavoriteProductIds.add(event.productId);
      }

      // Emit optimistic state immediately for instant UI feedback
      emit(state.copyWith(favoriteProductIds: updatedFavoriteProductIds));

      // Then perform the async database operation
      if (event.userId != null) {
        // Use Firestore service for authenticated users
        try {
          final newIsFavorited = await FavoritesService.toggleFavorite(
            userId: event.userId!,
            itemId: event.productId,
            type: FavoriteType.product,
          );

          // Verify the result matches our optimistic update
          final finalFavoriteProductIds = List<String>.from(updatedFavoriteProductIds);
          if (newIsFavorited && !finalFavoriteProductIds.contains(event.productId)) {
            finalFavoriteProductIds.add(event.productId);
          } else if (!newIsFavorited && finalFavoriteProductIds.contains(event.productId)) {
            finalFavoriteProductIds.remove(event.productId);
          }

          // Only emit again if the final state differs from optimistic state
          if (finalFavoriteProductIds.length != updatedFavoriteProductIds.length ||
              !finalFavoriteProductIds.every((id) => updatedFavoriteProductIds.contains(id))) {
            emit(state.copyWith(favoriteProductIds: finalFavoriteProductIds));
          }
        } catch (dbError) {
          // Revert optimistic update on database error
          final revertedFavoriteProductIds = List<String>.from(state.favoriteProductIds);
          if (wasAlreadyFavorited) {
            revertedFavoriteProductIds.add(event.productId);
          } else {
            revertedFavoriteProductIds.remove(event.productId);
          }
          emit(state.copyWith(favoriteProductIds: revertedFavoriteProductIds));
          rethrow;
        }
      } else {
        // Use local repository for anonymous users
        try {
          if (wasAlreadyFavorited) {
            await _favoritesRepository.removeFavoriteProduct(event.productId);
          } else {
            await _favoritesRepository.addFavoriteProduct(event.productId);
          }
        } catch (dbError) {
          // Revert optimistic update on database error
          final revertedFavoriteProductIds = List<String>.from(state.favoriteProductIds);
          if (wasAlreadyFavorited) {
            revertedFavoriteProductIds.add(event.productId);
          } else {
            revertedFavoriteProductIds.remove(event.productId);
          }
          emit(state.copyWith(favoriteProductIds: revertedFavoriteProductIds));
          rethrow;
        }
      }
    } catch (error) {
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _onClearAllFavorites(
    ClearAllFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      if (event.userId != null) {
        // Use Firestore service for authenticated users
        await FavoritesService.clearAllFavorites(event.userId!);
      } else {
        // Use local repository for anonymous users
        await _favoritesRepository.clearAllFavorites();
      }

      emit(state.copyWith(
        favoritePostIds: [],
        favoriteVendorIds: [],
        favoriteMarketIds: [],
        favoriteEventIds: [],
        favoriteProductIds: [],
      ));
    } catch (error) {
      emit(state.copyWith(
        status: FavoritesStatus.error,
        errorMessage: error.toString(),
      ));
    }
  }
}