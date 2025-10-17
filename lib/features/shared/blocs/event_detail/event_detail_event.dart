part of 'event_detail_bloc.dart';

sealed class EventDetailEvent extends Equatable {
  const EventDetailEvent();

  @override
  List<Object?> get props => [];
}

class LoadEventDetail extends EventDetailEvent {
  final String eventId;

  const LoadEventDetail(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

class RefreshEventDetail extends EventDetailEvent {
  const RefreshEventDetail();
}

class ToggleEventFavorite extends EventDetailEvent {
  const ToggleEventFavorite();
}