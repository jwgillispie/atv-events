// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:equatable/equatable.dart';

class VendorMarketRelationship extends Equatable {
  final String id;
  final String vendorId;
  final String marketId;
  final String status;
  final Map<String, dynamic>? metadata;
  final List<String>? operatingDays;
  final String? boothNumber;
  final bool isActive;
  final bool isApproved;

  const VendorMarketRelationship({
    required this.id,
    required this.vendorId,
    required this.marketId,
    required this.status,
    this.metadata,
    this.operatingDays,
    this.boothNumber,
    this.isActive = false,
    this.isApproved = false,
  });

  factory VendorMarketRelationship.fromMap(Map<String, dynamic> map, String id) {
    return VendorMarketRelationship(
      id: id,
      vendorId: map['vendorId'] as String? ?? '',
      marketId: map['marketId'] as String? ?? '',
      status: map['status'] as String? ?? 'inactive',
      metadata: map['metadata'] as Map<String, dynamic>?,
      operatingDays: (map['operatingDays'] as List?)?.cast<String>(),
      boothNumber: map['boothNumber'] as String?,
      isActive: map['isActive'] as bool? ?? false,
      isApproved: map['isApproved'] as bool? ?? false,
    );
  }

  /// Factory constructor from Firestore DocumentSnapshot
  factory VendorMarketRelationship.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return VendorMarketRelationship.fromMap(data, doc.id);
  }

  /// Getters for compatibility with email service
  String? get invitationEmail => metadata?['invitationEmail'] as String?;
  String? get createdBy => metadata?['createdBy'] as String?;
  String? get invitationToken => metadata?['invitationToken'] as String?;

  @override
  List<Object?> get props => [id, vendorId, marketId, status, metadata, operatingDays, boothNumber, isActive, isApproved];
}
