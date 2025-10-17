// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class VendorMarket extends Equatable {
  final String id;
  final String vendorId;
  final String marketId;
  final String marketName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final Map<String, dynamic>? metadata;

  const VendorMarket({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.marketName,
    this.startDate,
    this.endDate,
    this.status,
    this.metadata,
  });

  factory VendorMarket.fromMap(Map<String, dynamic> map, String id) {
    return VendorMarket(
      id: id,
      vendorId: map['vendorId'] as String? ?? '',
      marketId: map['marketId'] as String? ?? '',
      marketName: map['marketName'] as String? ?? '',
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      status: map['status'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'marketId': marketId,
      'marketName': marketName,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        marketId,
        marketName,
        startDate,
        endDate,
        status,
        metadata,
      ];
}
