import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hipop/features/shared/services/data/event_service.dart';
import '../../models/event.dart';

part 'event_detail_event.dart';
part 'event_detail_state.dart';

class EventDetailBloc extends Bloc<EventDetailEvent, EventDetailState> {
  EventDetailBloc() : super(const EventDetailState()) {
    on<LoadEventDetail>(_onLoadEventDetail);
    on<RefreshEventDetail>(_onRefreshEventDetail);
    on<ToggleEventFavorite>(_onToggleEventFavorite);
  }

  Future<void> _onLoadEventDetail(
    LoadEventDetail event,
    Emitter<EventDetailState> emit,
  ) async {
    emit(state.copyWith(status: EventDetailStatus.loading));

    try {
      // Load event details
      final eventData = await EventService.getEvent(event.eventId);
      
      if (eventData == null) {
        emit(state.copyWith(
          status: EventDetailStatus.error,
          errorMessage: 'Event not found',
        ));
        return;
      }

      // Check if event is favorited (assuming user context is available)
      // For now, defaulting to false - this would need user context
      bool isFavorite = false;
      try {
        // This would need to be updated with actual user ID when available
        // isFavorite = await FavoritesService.isEventFavorited(userId, eventData.id);
      } catch (e) {
        // Silently continue if favorites check fails
      }

      emit(state.copyWith(
        status: EventDetailStatus.loaded,
        event: eventData,
        isFavorite: isFavorite,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EventDetailStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshEventDetail(
    RefreshEventDetail event,
    Emitter<EventDetailState> emit,
  ) async {
    if (state.event != null) {
      add(LoadEventDetail(state.event!.id));
    }
  }

  Future<void> _onToggleEventFavorite(
    ToggleEventFavorite event,
    Emitter<EventDetailState> emit,
  ) async {
    if (state.event == null) return;

    try {
      final newFavoriteStatus = !state.isFavorite;
      
      // Update the UI immediately for better UX
      emit(state.copyWith(isFavorite: newFavoriteStatus));

      // This would need to be updated with actual user ID and favorite service
      // if (newFavoriteStatus) {
      //   await FavoritesService.addEventToFavorites(userId, state.event!.id);
      // } else {
      //   await FavoritesService.removeEventFromFavorites(userId, state.event!.id);
      // }
    } catch (e) {
      // Revert the state if the operation failed
      emit(state.copyWith(isFavorite: !state.isFavorite));
      // Could emit an error state or show a snackbar here
    }
  }
}