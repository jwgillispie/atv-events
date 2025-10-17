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

  @override
  List<Object?> get props => [id, name, description, imageUrl, metadata];
}
