// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ManagedVendor extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? imageUrl;
  final String? contactEmail;
  final String? contactPhone;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const ManagedVendor({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.imageUrl,
    this.contactEmail,
    this.contactPhone,
    required this.createdAt,
    this.metadata,
  });

  factory ManagedVendor.fromMap(Map<String, dynamic> map, String id) {
    return ManagedVendor(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      category: map['category'] as String?,
      imageUrl: map['imageUrl'] as String?,
      contactEmail: map['contactEmail'] as String?,
      contactPhone: map['contactPhone'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        category,
        imageUrl,
        contactEmail,
        contactPhone,
        createdAt,
        metadata,
      ];
}
