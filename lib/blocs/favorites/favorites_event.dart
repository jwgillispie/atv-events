part of 'favorites_bloc.dart';

abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class LoadFavorites extends FavoritesEvent {
  final String? userId;
  
  const LoadFavorites({this.userId});
  
  @override
  List<Object?> get props => [userId];
}

class TogglePostFavorite extends FavoritesEvent {
  final String postId;
  final String? userId;

  const TogglePostFavorite({required this.postId, this.userId});

  @override
  List<Object?> get props => [postId, userId];
}

class ToggleVendorFavorite extends FavoritesEvent {
  final String vendorId;
  final String? userId;

  const ToggleVendorFavorite({required this.vendorId, this.userId});

  @override
  List<Object?> get props => [vendorId, userId];
}

class ToggleMarketFavorite extends FavoritesEvent {
  final String marketId;
  final String? userId;

  const ToggleMarketFavorite({required this.marketId, this.userId});

  @override
  List<Object?> get props => [marketId, userId];
}

class ToggleEventFavorite extends FavoritesEvent {
  final String eventId;
  final String? userId;

  const ToggleEventFavorite({required this.eventId, this.userId});

  @override
  List<Object?> get props => [eventId, userId];
}

class ToggleProductFavorite extends FavoritesEvent {
  final String productId;
  final String? userId;

  const ToggleProductFavorite({required this.productId, this.userId});

  @override
  List<Object?> get props => [productId, userId];
}

class ClearAllFavorites extends FavoritesEvent {
  final String? userId;

  const ClearAllFavorites({this.userId});

  @override
  List<Object?> get props => [userId];
}