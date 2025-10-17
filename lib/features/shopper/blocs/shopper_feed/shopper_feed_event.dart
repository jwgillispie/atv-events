part of 'shopper_feed_bloc.dart';

/// Feed filter options
enum FeedFilter { markets, vendors, events, all }

/// Base event for shopper feed
abstract class ShopperFeedEvent extends Equatable {
  const ShopperFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load initial feed data
class LoadFeedRequested extends ShopperFeedEvent {
  final FeedFilter filter;
  final String? location;

  const LoadFeedRequested({
    this.filter = FeedFilter.all,
    this.location,
  });

  @override
  List<Object?> get props => [filter, location];
}

/// Event to refresh feed (pull-to-refresh)
class RefreshFeedRequested extends ShopperFeedEvent {
  const RefreshFeedRequested();
}

/// Event to load more items (pagination)
class LoadMoreRequested extends ShopperFeedEvent {
  const LoadMoreRequested();
}

/// Event when search location changes
class SearchLocationChanged extends ShopperFeedEvent {
  final String location;

  const SearchLocationChanged(this.location);

  @override
  List<Object> get props => [location];
}

/// Event when filter changes
class FilterChanged extends ShopperFeedEvent {
  final FeedFilter filter;

  const FilterChanged(this.filter);

  @override
  List<Object> get props => [filter];
}

/// Event to clear search and show all items
class ClearSearch extends ShopperFeedEvent {
  const ClearSearch();
}