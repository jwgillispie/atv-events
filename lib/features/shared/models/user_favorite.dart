import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum FavoriteType {
  vendor,
  market,
  event,
  product,
  organizer,
}

class UserFavorite extends Equatable {
  final String id;
  final String userId;
  final String itemId; // vendor ID, market ID, or event ID
  final FavoriteType type;
  final DateTime createdAt;
  final Map<String, dynamic> metadata; // Store additional info if needed

  const UserFavorite({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.type,
    required this.createdAt,
    this.metadata = const {},
  });

  factory UserFavorite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserFavorite(
      id: doc.id,
      userId: data['userId'] ?? '',
      itemId: data['itemId'] ?? '',
      type: FavoriteType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => FavoriteType.vendor,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'itemId': itemId,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  UserFavorite copyWith({
    String? id,
    String? userId,
    String? itemId,
    FavoriteType? type,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return UserFavorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        itemId,
        type,
        createdAt,
        metadata,
      ];

  @override
  String toString() {
    return 'UserFavorite(id: $id, userId: $userId, itemId: $itemId, type: $type)';
  }
}