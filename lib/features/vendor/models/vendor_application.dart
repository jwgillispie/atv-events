// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class VendorApplication extends Equatable {
  final String id;
  final String vendorId;
  final String marketId;
  final String status;
  final DateTime appliedAt;
  final Map<String, dynamic>? metadata;

  const VendorApplication({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.status,
    required this.appliedAt,
    this.metadata,
  });

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
  List<Object?> get props => [id, vendorId, marketId, status, appliedAt, metadata];
}
