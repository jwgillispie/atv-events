import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../vendor/models/post_type.dart';

/// Represents a pending vendor approval request for market organizers
class ApprovalRequest extends Equatable {
  final String id;
  final String marketId;
  final String organizerId;
  final String vendorPostId;
  final String vendorName;
  final String vendorId;
  final DateTime eventDate;
  final DateTime requestedAt;
  final ApprovalPriority priority;
  final String status;
  final Map<String, dynamic> preview;

  const ApprovalRequest({
    required this.id,
    required this.marketId,
    required this.organizerId,
    required this.vendorPostId,
    required this.vendorName,
    required this.vendorId,
    required this.eventDate,
    required this.requestedAt,
    required this.priority,
    required this.status,
    required this.preview,
  });

  factory ApprovalRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ApprovalRequest(
      id: doc.id,
      marketId: data['marketId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      vendorPostId: data['vendorPostId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      vendorId: data['vendorId'] ?? '',
      eventDate: (data['eventDate'] as Timestamp).toDate(),
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      priority: ApprovalPriority.fromString(data['priority'] ?? 'normal'),
      status: data['status'] ?? 'pending',
      preview: Map<String, dynamic>.from(data['preview'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'marketId': marketId,
      'organizerId': organizerId,
      'vendorPostId': vendorPostId,
      'vendorName': vendorName,
      'vendorId': vendorId,
      'eventDate': Timestamp.fromDate(eventDate),
      'requestedAt': Timestamp.fromDate(requestedAt),
      'priority': priority.value,
      'status': status,
      'preview': preview,
    };
  }

  // Simple getter methods
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get isExpired => status == 'expired';
  bool get isUrgent => priority == ApprovalPriority.urgent;
  bool get isHigh => priority == ApprovalPriority.high;

  String get previewDescription => preview['description'] ?? '';
  int get productCount => preview['productCount'] ?? 0;
  int get photoCount => preview['photoCount'] ?? 0;

  @override
  List<Object?> get props => [
    id,
    marketId,
    organizerId,
    vendorPostId,
    vendorName,
    vendorId,
    eventDate,
    requestedAt,
    priority,
    status,
    preview,
  ];
}

/// Simple model for monthly tracking - keeping it basic like existing models
class VendorMonthlyTracking extends Equatable {
  final String id; // Format: vendorId_YYYY_MM
  final String vendorId;
  final String yearMonth;
  final Map<String, int> posts;
  final List<String> postIds;
  final DateTime lastPostDate;
  final String subscriptionTier;

  const VendorMonthlyTracking({
    required this.id,
    required this.vendorId,
    required this.yearMonth,
    required this.posts,
    required this.postIds,
    required this.lastPostDate,
    required this.subscriptionTier,
  });

  factory VendorMonthlyTracking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VendorMonthlyTracking(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      yearMonth: data['yearMonth'] ?? '',
      posts: Map<String, int>.from(data['posts'] ?? {}),
      postIds: List<String>.from(data['postIds'] ?? []),
      lastPostDate: (data['lastPostDate'] as Timestamp).toDate(),
      subscriptionTier: data['subscriptionTier'] ?? 'free',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'yearMonth': yearMonth,
      'posts': posts,
      'postIds': postIds,
      'lastPostDate': Timestamp.fromDate(lastPostDate),
      'subscriptionTier': subscriptionTier,
    };
  }

  // Simple getters
  int get totalPosts => posts['total'] ?? 0;
  int get independentPosts => posts['independent'] ?? 0;
  int get marketPosts => posts['market'] ?? 0;
  int get deniedPosts => posts['denied'] ?? 0;

  @override
  List<Object?> get props => [
    id,
    vendorId,
    yearMonth,
    posts,
    postIds,
    lastPostDate,
    subscriptionTier,
  ];
}