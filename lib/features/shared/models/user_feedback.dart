import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Categories of feedback that users can submit
enum FeedbackCategory {
  bug,
  feature,
  improvement,
  general,
  tutorial,
  support,
}

extension FeedbackCategoryExtension on FeedbackCategory {
  String get displayName {
    switch (this) {
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.feature:
        return 'Feature Request';
      case FeedbackCategory.improvement:
        return 'Improvement';
      case FeedbackCategory.general:
        return 'General';
      case FeedbackCategory.tutorial:
        return 'Tutorial';
      case FeedbackCategory.support:
        return 'Support';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedbackCategory.bug:
        return Icons.bug_report;
      case FeedbackCategory.feature:
        return Icons.new_releases;
      case FeedbackCategory.improvement:
        return Icons.trending_up;
      case FeedbackCategory.general:
        return Icons.feedback;
      case FeedbackCategory.tutorial:
        return Icons.school;
      case FeedbackCategory.support:
        return Icons.help;
    }
  }
}

/// Priority levels for feedback (set by system or admin)
enum FeedbackPriority {
  low,
  medium,
  high,
  critical,
}

extension FeedbackPriorityExtension on FeedbackPriority {
  String get displayName {
    switch (this) {
      case FeedbackPriority.low:
        return 'Low';
      case FeedbackPriority.medium:
        return 'Medium';
      case FeedbackPriority.high:
        return 'High';
      case FeedbackPriority.critical:
        return 'Critical';
    }
  }
}

/// Status of feedback review process
enum FeedbackStatus {
  submitted,
  reviewing,
  inProgress,
  resolved,
  closed,
}

extension FeedbackStatusExtension on FeedbackStatus {
  String get displayName {
    switch (this) {
      case FeedbackStatus.submitted:
        return 'New';
      case FeedbackStatus.reviewing:
        return 'Reviewing';
      case FeedbackStatus.inProgress:
        return 'In Progress';
      case FeedbackStatus.resolved:
        return 'Resolved';
      case FeedbackStatus.closed:
        return 'Closed';
    }
  }
}

/// Represents user feedback submitted to the platform
/// All feedback is routed to the CEO verification dashboard for review
class UserFeedback extends Equatable {
  final String id;
  final String userId;
  final String userType; // vendor, market_organizer, shopper
  final String userEmail;
  final String? userName;
  final FeedbackCategory category;
  final String title;
  final String description;
  final FeedbackPriority priority;
  final FeedbackStatus status;
  final List<String> tags; // Additional categorization
  final Map<String, dynamic> metadata; // Device info, app version, etc.
  final String? adminResponse;
  final String? adminUserId;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserFeedback({
    required this.id,
    required this.userId,
    required this.userType,
    required this.userEmail,
    this.userName,
    required this.category,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.tags,
    required this.metadata,
    this.adminResponse,
    this.adminUserId,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create new feedback submission
  factory UserFeedback.create({
    required String userId,
    required String userType,
    required String userEmail,
    String? userName,
    required FeedbackCategory category,
    required String title,
    required String description,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return UserFeedback(
      id: '', // Will be set by Firestore
      userId: userId,
      userType: userType,
      userEmail: userEmail,
      userName: userName,
      category: category,
      title: title.trim(),
      description: description.trim(),
      priority: _calculatePriority(category, description),
      status: FeedbackStatus.submitted,
      tags: tags ?? [],
      metadata: metadata ?? {},
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create from Firestore document
  factory UserFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserFeedback(
      id: doc.id,
      userId: data['userId'] ?? '',
      userType: data['userType'] ?? 'shopper',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'],
      category: FeedbackCategory.values.firstWhere(
        (cat) => cat.name == data['category'],
        orElse: () => FeedbackCategory.general,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      priority: FeedbackPriority.values.firstWhere(
        (pri) => pri.name == data['priority'],
        orElse: () => FeedbackPriority.medium,
      ),
      status: FeedbackStatus.values.firstWhere(
        (stat) => stat.name == data['status'],
        orElse: () => FeedbackStatus.submitted,
      ),
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      adminResponse: data['adminResponse'],
      adminUserId: data['adminUserId'],
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userType': userType,
      'userEmail': userEmail,
      'userName': userName,
      'category': category.name,
      'title': title,
      'description': description,
      'priority': priority.name,
      'status': status.name,
      'tags': tags,
      'metadata': metadata,
      'adminResponse': adminResponse,
      'adminUserId': adminUserId,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  UserFeedback copyWith({
    String? id,
    String? userId,
    String? userType,
    String? userEmail,
    String? userName,
    FeedbackCategory? category,
    String? title,
    String? description,
    FeedbackPriority? priority,
    FeedbackStatus? status,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    String? adminResponse,
    String? adminUserId,
    DateTime? respondedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      adminResponse: adminResponse ?? this.adminResponse,
      adminUserId: adminUserId ?? this.adminUserId,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Add admin response to feedback
  UserFeedback respondTo({
    required String response,
    required String adminUserId,
  }) {
    return copyWith(
      adminResponse: response,
      adminUserId: adminUserId,
      respondedAt: DateTime.now(),
      status: FeedbackStatus.resolved,
      updatedAt: DateTime.now(),
    );
  }

  /// Update feedback status
  UserFeedback updateStatus(FeedbackStatus newStatus) {
    return copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  /// Get display-friendly category name
  String get categoryDisplayName {
    switch (category) {
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.feature:
        return 'Feature Request';
      case FeedbackCategory.improvement:
        return 'Improvement Suggestion';
      case FeedbackCategory.general:
        return 'General Feedback';
      case FeedbackCategory.tutorial:
        return 'Tutorial Feedback';
      case FeedbackCategory.support:
        return 'Support Request';
    }
  }

  /// Get display-friendly priority name
  String get priorityDisplayName {
    switch (priority) {
      case FeedbackPriority.low:
        return 'Low';
      case FeedbackPriority.medium:
        return 'Medium';
      case FeedbackPriority.high:
        return 'High';
      case FeedbackPriority.critical:
        return 'Critical';
    }
  }

  /// Get display-friendly status name
  String get statusDisplayName {
    switch (status) {
      case FeedbackStatus.submitted:
        return 'Submitted';
      case FeedbackStatus.reviewing:
        return 'Under Review';
      case FeedbackStatus.inProgress:
        return 'In Progress';
      case FeedbackStatus.resolved:
        return 'Resolved';
      case FeedbackStatus.closed:
        return 'Closed';
    }
  }

  /// Get user-friendly display name
  String get userDisplayName {
    if (userName?.isNotEmpty == true) {
      return userName!;
    }
    return userEmail.split('@').first; // Use email prefix as fallback
  }

  /// Check if feedback is still active (not resolved or closed)
  bool get isActive => status != FeedbackStatus.resolved && status != FeedbackStatus.closed;

  /// Check if feedback has been responded to
  bool get hasResponse => adminResponse?.isNotEmpty == true;

  /// Get time since submission
  String get timeSinceSubmission {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Validate feedback before submission
  String? validate() {
    if (title.isEmpty) {
      return 'Title is required';
    }
    if (title.length < 5) {
      return 'Title must be at least 5 characters';
    }
    if (title.length > 200) {
      return 'Title must be less than 200 characters';
    }
    if (description.isEmpty) {
      return 'Description is required';
    }
    if (description.length < 10) {
      return 'Description must be at least 10 characters';
    }
    if (description.length > 2000) {
      return 'Description must be less than 2000 characters';
    }
    return null;
  }

  /// Calculate automatic priority based on category and content
  static FeedbackPriority _calculatePriority(FeedbackCategory category, String description) {
    final descLower = description.toLowerCase();
    
    // Critical keywords
    if (descLower.contains('crash') || 
        descLower.contains('broken') || 
        descLower.contains('urgent') ||
        descLower.contains('critical') ||
        descLower.contains('emergency')) {
      return FeedbackPriority.critical;
    }
    
    // High priority categories or keywords
    if (category == FeedbackCategory.bug ||
        descLower.contains('error') ||
        descLower.contains('issue') ||
        descLower.contains('problem')) {
      return FeedbackPriority.high;
    }
    
    // Feature requests are usually medium
    if (category == FeedbackCategory.feature || category == FeedbackCategory.improvement) {
      return FeedbackPriority.medium;
    }
    
    // Everything else is low
    return FeedbackPriority.low;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userType,
        userEmail,
        userName,
        category,
        title,
        description,
        priority,
        status,
        tags,
        metadata,
        adminResponse,
        adminUserId,
        respondedAt,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'UserFeedback(id: $id, title: $title, category: ${category.name}, status: ${status.name})';
  }
}