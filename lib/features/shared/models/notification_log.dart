import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a notification log entry in Firestore
/// Used for tracking notification history and user engagement
class NotificationLog {
  final String id;
  final String userId;
  final String type; // vendor_popup, market_today, market_reminder, popup_starting, tomorrow_preview
  final String? title;
  final String? body;
  final String? message; // Alternative to body
  final Map<String, dynamic> data; // Additional data for navigation
  final DateTime createdAt;
  final bool read;
  final DateTime? readAt;
  final bool seen;
  final DateTime? seenAt;
  final bool opened;
  final DateTime? openedAt;

  // Navigation data
  final String? vendorId;
  final String? marketId;
  final String? eventId;
  final String? postId;

  // Metadata
  final String? imageUrl;
  final String? actionUrl;
  final int? priority;
  final Map<String, dynamic>? metadata;

  NotificationLog({
    required this.id,
    required this.userId,
    required this.type,
    this.title,
    this.body,
    this.message,
    required this.data,
    required this.createdAt,
    this.read = false,
    this.readAt,
    this.seen = false,
    this.seenAt,
    this.opened = false,
    this.openedAt,
    this.vendorId,
    this.marketId,
    this.eventId,
    this.postId,
    this.imageUrl,
    this.actionUrl,
    this.priority,
    this.metadata,
  });

  /// Create from Firestore document
  factory NotificationLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return NotificationLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'general',
      title: data['title'],
      body: data['body'],
      message: data['message'],
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      seen: data['seen'] ?? false,
      seenAt: (data['seenAt'] as Timestamp?)?.toDate(),
      opened: data['opened'] ?? false,
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      vendorId: data['vendorId'] ?? data['data']?['vendorId'],
      marketId: data['marketId'] ?? data['data']?['marketId'],
      eventId: data['eventId'] ?? data['data']?['eventId'],
      postId: data['postId'] ?? data['data']?['postId'],
      imageUrl: data['imageUrl'],
      actionUrl: data['actionUrl'],
      priority: data['priority'],
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'message': message,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'seen': seen,
      'seenAt': seenAt != null ? Timestamp.fromDate(seenAt!) : null,
      'opened': opened,
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'vendorId': vendorId,
      'marketId': marketId,
      'eventId': eventId,
      'postId': postId,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'priority': priority,
      'metadata': metadata,
    };
  }

  /// Get display text for the notification
  String get displayText => body ?? message ?? '';

  /// Get display title with fallback
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;

    switch (type) {
      case 'vendor_popup':
        return 'Vendor Update';
      case 'market_today':
        return 'Market Today';
      case 'market_reminder':
        return 'Market Reminder';
      case 'popup_starting':
        return 'Popup Starting Soon';
      case 'tomorrow_preview':
        return 'Tomorrow\'s Events';
      default:
        return 'HiPop Markets';
    }
  }

  /// Check if notification is actionable (has navigation data)
  bool get isActionable {
    return vendorId != null ||
           marketId != null ||
           eventId != null ||
           postId != null ||
           actionUrl != null;
  }

  /// Get the age of the notification
  Duration get age => DateTime.now().difference(createdAt);

  /// Check if notification is recent (within 24 hours)
  bool get isRecent => age.inHours < 24;

  /// Get formatted relative time
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return _formatDate(createdAt);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year) {
      return '${_monthName(date.month)} ${date.day}';
    }
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Create a copy with updated fields
  NotificationLog copyWith({
    bool? read,
    DateTime? readAt,
    bool? seen,
    DateTime? seenAt,
    bool? opened,
    DateTime? openedAt,
  }) {
    return NotificationLog(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      message: message,
      data: data,
      createdAt: createdAt,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      seen: seen ?? this.seen,
      seenAt: seenAt ?? this.seenAt,
      opened: opened ?? this.opened,
      openedAt: openedAt ?? this.openedAt,
      vendorId: vendorId,
      marketId: marketId,
      eventId: eventId,
      postId: postId,
      imageUrl: imageUrl,
      actionUrl: actionUrl,
      priority: priority,
      metadata: metadata,
    );
  }
}