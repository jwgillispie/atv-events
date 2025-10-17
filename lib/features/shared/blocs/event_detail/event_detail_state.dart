part of 'event_detail_bloc.dart';

enum EventDetailStatus { initial, loading, loaded, error }

class EventDetailState extends Equatable {
  final EventDetailStatus status;
  final Event? event;
  final String? errorMessage;
  final bool isFavorite;

  const EventDetailState({
    this.status = EventDetailStatus.initial,
    this.event,
    this.errorMessage,
    this.isFavorite = false,
  });

  EventDetailState copyWith({
    EventDetailStatus? status,
    Event? event,
    String? errorMessage,
    bool? isFavorite,
  }) {
    return EventDetailState(
      status: status ?? this.status,
      event: event ?? this.event,
      errorMessage: errorMessage ?? this.errorMessage,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [status, event, errorMessage, isFavorite];
}