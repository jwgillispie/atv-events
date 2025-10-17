import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserMarketFavorite extends Equatable {
  final String id;
  final String userId;
  final String marketId;
  final List<String> favoriteDays;
  final bool notificationsEnabled;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserMarketFavorite({
    required this.id,
    required this.userId,
    required this.marketId,
    this.favoriteDays = const [],
    this.notificationsEnabled = false,
    this.preferences = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserMarketFavorite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserMarketFavorite(
      id: doc.id,
      userId: data['userId'] ?? '',
      marketId: data['marketId'] ?? '',
      favoriteDays: List<String>.from(data['favoriteDays'] ?? []),
      notificationsEnabled: data['notificationsEnabled'] ?? false,
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'marketId': marketId,
      'favoriteDays': favoriteDays,
      'notificationsEnabled': notificationsEnabled,
      'preferences': preferences,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserMarketFavorite copyWith({
    String? id,
    String? userId,
    String? marketId,
    List<String>? favoriteDays,
    bool? notificationsEnabled,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserMarketFavorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      marketId: marketId ?? this.marketId,
      favoriteDays: favoriteDays ?? this.favoriteDays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isFavoriteDay(String dayName) {
    return favoriteDays.contains(dayName.toLowerCase());
  }

  bool get hasPreferredDays => favoriteDays.isNotEmpty;

  UserMarketFavorite addFavoriteDay(String dayName) {
    final updatedDays = List<String>.from(favoriteDays);
    final lowerDayName = dayName.toLowerCase();
    if (!updatedDays.contains(lowerDayName)) {
      updatedDays.add(lowerDayName);
    }
    return copyWith(
      favoriteDays: updatedDays,
      updatedAt: DateTime.now(),
    );
  }

  UserMarketFavorite removeFavoriteDay(String dayName) {
    final updatedDays = List<String>.from(favoriteDays);
    updatedDays.remove(dayName.toLowerCase());
    return copyWith(
      favoriteDays: updatedDays,
      updatedAt: DateTime.now(),
    );
  }

  UserMarketFavorite toggleNotifications() {
    return copyWith(
      notificationsEnabled: !notificationsEnabled,
      updatedAt: DateTime.now(),
    );
  }

  String get favoriteDaysDisplay {
    if (favoriteDays.isEmpty) return 'Any day';
    
    final capitalizedDays = favoriteDays.map((day) {
      if (day.isEmpty) return day;
      return day[0].toUpperCase() + day.substring(1);
    }).toList();
    
    if (capitalizedDays.length == 1) {
      return capitalizedDays.first;
    } else if (capitalizedDays.length == 2) {
      return '${capitalizedDays[0]} & ${capitalizedDays[1]}';
    } else {
      return '${capitalizedDays.take(capitalizedDays.length - 1).join(', ')} & ${capitalizedDays.last}';
    }
  }

  factory UserMarketFavorite.create({
    required String userId,
    required String marketId,
    List<String>? favoriteDays,
    bool notificationsEnabled = false,
    Map<String, dynamic>? preferences,
  }) {
    final now = DateTime.now();
    return UserMarketFavorite(
      id: '',
      userId: userId,
      marketId: marketId,
      favoriteDays: favoriteDays ?? [],
      notificationsEnabled: notificationsEnabled,
      preferences: preferences ?? {},
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        marketId,
        favoriteDays,
        notificationsEnabled,
        preferences,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'UserMarketFavorite(id: $id, userId: $userId, marketId: $marketId, favoriteDays: $favoriteDays)';
  }
}