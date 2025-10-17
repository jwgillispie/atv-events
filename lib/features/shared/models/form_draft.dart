import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a draft of a form that can be saved and resumed
/// Supports both local and cloud persistence for optimal UX
class FormDraft extends Equatable {
  final String id;
  final String userId;
  final DraftType type;
  final Map<String, dynamic> formData;
  final List<String> photoUrls;
  final List<String> localPhotoPaths;
  final DateTime createdAt;
  final DateTime lastModified;
  final String? associatedId; // marketId, eventId, or postId for edits
  final DraftStatus status;
  final double completionPercentage;
  final Map<String, bool> completedSections;
  final String? deviceId; // For cross-device sync detection
  final int version; // For conflict resolution

  const FormDraft({
    required this.id,
    required this.userId,
    required this.type,
    required this.formData,
    this.photoUrls = const [],
    this.localPhotoPaths = const [],
    required this.createdAt,
    required this.lastModified,
    this.associatedId,
    this.status = DraftStatus.inProgress,
    this.completionPercentage = 0.0,
    this.completedSections = const {},
    this.deviceId,
    this.version = 1,
  });

  /// Create from Firestore document
  factory FormDraft.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FormDraft(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: DraftType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => DraftType.popup,
      ),
      formData: Map<String, dynamic>.from(data['formData'] ?? {}),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      localPhotoPaths: [], // Local paths not stored in Firestore
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastModified: (data['lastModified'] as Timestamp).toDate(),
      associatedId: data['associatedId'],
      status: DraftStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => DraftStatus.inProgress,
      ),
      completionPercentage: (data['completionPercentage'] ?? 0.0).toDouble(),
      completedSections: Map<String, bool>.from(data['completedSections'] ?? {}),
      deviceId: data['deviceId'],
      version: data['version'] ?? 1,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.toString(),
      'formData': formData,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModified': Timestamp.fromDate(lastModified),
      'associatedId': associatedId,
      'status': status.toString(),
      'completionPercentage': completionPercentage,
      'completedSections': completedSections,
      'deviceId': deviceId,
      'version': version,
    };
  }

  /// Create from local storage JSON
  factory FormDraft.fromJson(Map<String, dynamic> json) {
    return FormDraft(
      id: json['id'],
      userId: json['userId'],
      type: DraftType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => DraftType.popup,
      ),
      formData: Map<String, dynamic>.from(json['formData'] ?? {}),
      photoUrls: List<String>.from(json['photoUrls'] ?? []),
      localPhotoPaths: List<String>.from(json['localPhotoPaths'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      lastModified: DateTime.parse(json['lastModified']),
      associatedId: json['associatedId'],
      status: DraftStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DraftStatus.inProgress,
      ),
      completionPercentage: (json['completionPercentage'] ?? 0.0).toDouble(),
      completedSections: Map<String, bool>.from(json['completedSections'] ?? {}),
      deviceId: json['deviceId'],
      version: json['version'] ?? 1,
    );
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString(),
      'formData': formData,
      'photoUrls': photoUrls,
      'localPhotoPaths': localPhotoPaths,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'associatedId': associatedId,
      'status': status.toString(),
      'completionPercentage': completionPercentage,
      'completedSections': completedSections,
      'deviceId': deviceId,
      'version': version,
    };
  }

  /// Create a copy with updated fields
  FormDraft copyWith({
    String? id,
    String? userId,
    DraftType? type,
    Map<String, dynamic>? formData,
    List<String>? photoUrls,
    List<String>? localPhotoPaths,
    DateTime? createdAt,
    DateTime? lastModified,
    String? associatedId,
    DraftStatus? status,
    double? completionPercentage,
    Map<String, bool>? completedSections,
    String? deviceId,
    int? version,
  }) {
    return FormDraft(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      formData: formData ?? this.formData,
      photoUrls: photoUrls ?? this.photoUrls,
      localPhotoPaths: localPhotoPaths ?? this.localPhotoPaths,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      associatedId: associatedId ?? this.associatedId,
      status: status ?? this.status,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      completedSections: completedSections ?? this.completedSections,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
    );
  }

  /// Calculate completion percentage based on required fields
  double calculateCompletion(List<String> requiredFields) {
    if (requiredFields.isEmpty) return 100.0;

    int completedCount = 0;
    for (final field in requiredFields) {
      final value = formData[field];
      if (value != null && value.toString().isNotEmpty) {
        completedCount++;
      }
    }

    return (completedCount / requiredFields.length) * 100;
  }

  /// Check if draft is stale (older than 30 days)
  bool get isStale {
    final daysSinceModified = DateTime.now().difference(lastModified).inDays;
    return daysSinceModified > 30;
  }

  /// Check if draft is recent (modified within last hour)
  bool get isRecent {
    final minutesSinceModified = DateTime.now().difference(lastModified).inMinutes;
    return minutesSinceModified <= 60;
  }

  /// Get human-readable type name
  String get typeName {
    switch (type) {
      case DraftType.popup:
        return 'Pop-up';
      case DraftType.market:
        return 'Market';
      case DraftType.event:
        return 'Event';
    }
  }

  /// Get draft age as human-readable string
  String get ageDescription {
    final now = DateTime.now();
    final difference = now.difference(lastModified);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? "" : "s"} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? "" : "s"} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? "" : "s"} ago';
    } else {
      return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() == 1 ? "" : "s"} ago';
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        formData,
        photoUrls,
        localPhotoPaths,
        createdAt,
        lastModified,
        associatedId,
        status,
        completionPercentage,
        completedSections,
        deviceId,
        version,
      ];
}

/// Types of forms that support drafts
enum DraftType {
  popup,
  market,
  event,
}

/// Status of a draft
enum DraftStatus {
  inProgress, // Active draft being edited
  abandoned, // Not touched for > 7 days
  recovered, // Recovered from crash/closure
  scheduled, // Set for auto-submission
  conflict, // Conflict with another device
}

/// Extension for draft type colors (using HiPop color system)
extension DraftTypeExtension on DraftType {
  Color get color {
    switch (this) {
      case DraftType.popup:
        return const Color(0xFF946C7E); // Vendor accent - Mauve
      case DraftType.market:
        return const Color(0xFF558B6E); // Organizer accent - Deep Sage
      case DraftType.event:
        return const Color(0xFF6F9686); // Secondary Soft Sage
    }
  }

  IconData get icon {
    switch (this) {
      case DraftType.popup:
        return Icons.storefront;
      case DraftType.market:
        return Icons.location_city;
      case DraftType.event:
        return Icons.event;
    }
  }
}