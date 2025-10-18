// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Application status enum
enum ApplicationStatus {
  pending,
  approved,
  rejected,
  withdrawn,
  waitlisted;

  String get displayName {
    switch (this) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.withdrawn:
        return 'Withdrawn';
      case ApplicationStatus.waitlisted:
        return 'Waitlisted';
    }
  }
}

class VendorApplication extends Equatable {
  final String id;
  final String vendorId;
  final String marketId;
  final String status;
  final DateTime appliedAt;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const VendorApplication({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.status,
    required this.appliedAt,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? appliedAt;

  factory VendorApplication.fromMap(Map<String, dynamic> map, String id) {
    return VendorApplication(
      id: id,
      vendorId: map['vendorId'] as String? ?? '',
      marketId: map['marketId'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      appliedAt: (map['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Factory constructor from Firestore DocumentSnapshot
  factory VendorApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return VendorApplication.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'marketId': marketId,
      'status': status,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [id, vendorId, marketId, status, appliedAt, createdAt, metadata];
}
