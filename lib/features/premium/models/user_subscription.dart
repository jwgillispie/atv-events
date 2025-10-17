// TODO: Removed for ATV Events demo - Premium/subscription features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserSubscription extends Equatable {
  final String id;
  final String userId;
  final String planId;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;
  final Map<String, dynamic>? metadata;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    required this.startDate,
    this.endDate,
    this.metadata,
  });

  bool get isActive => status == 'active';

  factory UserSubscription.fromMap(Map<String, dynamic> map, String id) {
    return UserSubscription(
      id: id,
      userId: map['userId'] as String? ?? '',
      planId: map['planId'] as String? ?? '',
      status: map['status'] as String? ?? 'inactive',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planId': planId,
      'status': status,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [id, userId, planId, status, startDate, endDate, metadata];
}
