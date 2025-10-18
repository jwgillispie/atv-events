// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:equatable/equatable.dart';

class UnifiedVendor extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  const UnifiedVendor({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.metadata,
  });

  factory UnifiedVendor.fromMap(Map<String, dynamic> map, String id) {
    return UnifiedVendor(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      imageUrl: map['imageUrl'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Factory constructors for compatibility
  factory UnifiedVendor.fromManagedVendor(dynamic vendor) {
    return UnifiedVendor(
      id: vendor.id as String? ?? '',
      name: vendor.name as String? ?? '',
      description: vendor.description as String?,
      imageUrl: vendor.imageUrl as String?,
      metadata: vendor.metadata as Map<String, dynamic>?,
    );
  }

  factory UnifiedVendor.fromApplication(dynamic application) {
    return UnifiedVendor(
      id: application.vendorId as String? ?? '',
      name: application.businessName as String? ?? '',
      description: application.businessDescription as String?,
      imageUrl: null,
      metadata: {'applicationId': application.id},
    );
  }

  // Add missing getters for compatibility
  String get businessName => name;
  String? get email => metadata?['email'] as String?;

  @override
  List<Object?> get props => [id, name, description, imageUrl, metadata];
}
