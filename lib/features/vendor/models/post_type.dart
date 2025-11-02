/// Enum defining the type of vendor post
enum PostType {
  /// Independent popup - vendor's own event at any location
  independent,
  
  /// Market vendor - join an organized market event (requires approval)
  market;

  /// Convert enum to string for Firestore storage
  String get value {
    switch (this) {
      case PostType.independent:
        return 'independent';
      case PostType.market:
        return 'market';
    }
  }

  /// Create enum from string value
  static PostType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'independent':
        return PostType.independent;
      case 'market':
        return PostType.market;
      default:
        throw ArgumentError('Invalid PostType value: $value');
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case PostType.independent:
        return 'Independent Popup';
      case PostType.market:
        return 'Market Vendor';
    }
  }

  /// Description for UI
  String get description {
    switch (this) {
      case PostType.independent:
        return 'Your own event at any location';
      case PostType.market:
        return 'Join an organized market event (instant approval)';
    }
  }

  /// Whether this post type requires approval
  bool get requiresApproval {
    switch (this) {
      case PostType.independent:
        return false;
      case PostType.market:
        return false; // Changed: Market posts no longer require approval
    }
  }
}

/// Enum for approval status
enum ApprovalStatus {
  /// Approval is pending organizer review
  pending,
  
  /// Post has been approved and is active
  approved,
  
  /// Post has been denied by organizer
  denied;

  /// Convert enum to string for Firestore storage
  String get value {
    switch (this) {
      case ApprovalStatus.pending:
        return 'pending';
      case ApprovalStatus.approved:
        return 'approved';
      case ApprovalStatus.denied:
        return 'denied';
    }
  }

  /// Create enum from string value
  static ApprovalStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return ApprovalStatus.pending;
      case 'approved':
        return ApprovalStatus.approved;
      case 'denied':
        return ApprovalStatus.denied;
      default:
        throw ArgumentError('Invalid ApprovalStatus value: $value');
    }
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case ApprovalStatus.pending:
        return 'Pending Approval';
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.denied:
        return 'Denied';
    }
  }

  /// Color for UI display
  String get colorHex {
    switch (this) {
      case ApprovalStatus.pending:
        return '#FF9800'; // Orange
      case ApprovalStatus.approved:
        return '#4CAF50'; // Green
      case ApprovalStatus.denied:
        return '#F44336'; // Red
    }
  }
}

/// Priority level for approval requests
enum ApprovalPriority {
  /// Event is within 48 hours
  urgent,
  
  /// Event is within 72 hours
  high,
  
  /// Normal priority
  normal;

  /// Convert enum to string for Firestore storage
  String get value {
    switch (this) {
      case ApprovalPriority.urgent:
        return 'urgent';
      case ApprovalPriority.high:
        return 'high';
      case ApprovalPriority.normal:
        return 'normal';
    }
  }

  /// Create enum from string value
  static ApprovalPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'urgent':
        return ApprovalPriority.urgent;
      case 'high':
        return ApprovalPriority.high;
      case 'normal':
        return ApprovalPriority.normal;
      default:
        throw ArgumentError('Invalid ApprovalPriority value: $value');
    }
  }

  /// Calculate priority based on event date
  static ApprovalPriority calculatePriority(DateTime eventDate) {
    final hoursUntil = eventDate.difference(DateTime.now()).inHours;
    if (hoursUntil <= 48) return ApprovalPriority.urgent;
    if (hoursUntil <= 72) return ApprovalPriority.high;
    return ApprovalPriority.normal;
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case ApprovalPriority.urgent:
        return 'Urgent';
      case ApprovalPriority.high:
        return 'High';
      case ApprovalPriority.normal:
        return 'Normal';
    }
  }

  /// Sort order (higher number = higher priority)
  int get sortOrder {
    switch (this) {
      case ApprovalPriority.urgent:
        return 3;
      case ApprovalPriority.high:
        return 2;
      case ApprovalPriority.normal:
        return 1;
    }
  }
}