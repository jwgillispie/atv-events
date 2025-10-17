import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MessageStatus {
  pending,
  processing,
  sent,
  failed,
  scheduled,
  cancelled,
}

enum MessagePriority {
  low,
  normal,
  high,
  urgent,
}

class BulkMessage extends Equatable {
  final String id;
  final String organizerId;
  final String subject;
  final String content;
  final List<String> recipientIds;
  final Map<String, dynamic> selectionCriteria;
  final MessageStatus status;
  final MessagePriority priority;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final Map<String, dynamic> deliveryStats;
  final Map<String, dynamic> metadata;
  final String? templateId;
  final Map<String, String> templateVariables;

  const BulkMessage({
    required this.id,
    required this.organizerId,
    required this.subject,
    required this.content,
    required this.recipientIds,
    this.selectionCriteria = const {},
    required this.status,
    this.priority = MessagePriority.normal,
    required this.createdAt,
    this.scheduledFor,
    this.sentAt,
    this.deliveryStats = const {},
    this.metadata = const {},
    this.templateId,
    this.templateVariables = const {},
  });

  factory BulkMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BulkMessage(
      id: doc.id,
      organizerId: data['organizerId'] ?? '',
      subject: data['subject'] ?? '',
      content: data['content'] ?? '',
      recipientIds: List<String>.from(data['recipientIds'] ?? []),
      selectionCriteria: Map<String, dynamic>.from(data['selectionCriteria'] ?? {}),
      status: MessageStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => MessageStatus.pending,
      ),
      priority: MessagePriority.values.firstWhere(
        (priority) => priority.name == data['priority'],
        orElse: () => MessagePriority.normal,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledFor: (data['scheduledFor'] as Timestamp?)?.toDate(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      deliveryStats: Map<String, dynamic>.from(data['deliveryStats'] ?? {}),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      templateId: data['templateId'],
      templateVariables: Map<String, String>.from(data['templateVariables'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizerId': organizerId,
      'subject': subject,
      'content': content,
      'recipientIds': recipientIds,
      'selectionCriteria': selectionCriteria,
      'status': status.name,
      'priority': priority.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor!) : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'deliveryStats': deliveryStats,
      'metadata': metadata,
      'templateId': templateId,
      'templateVariables': templateVariables,
    };
  }

  BulkMessage copyWith({
    String? id,
    String? organizerId,
    String? subject,
    String? content,
    List<String>? recipientIds,
    Map<String, dynamic>? selectionCriteria,
    MessageStatus? status,
    MessagePriority? priority,
    DateTime? createdAt,
    DateTime? scheduledFor,
    DateTime? sentAt,
    Map<String, dynamic>? deliveryStats,
    Map<String, dynamic>? metadata,
    String? templateId,
    Map<String, String>? templateVariables,
  }) {
    return BulkMessage(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      recipientIds: recipientIds ?? this.recipientIds,
      selectionCriteria: selectionCriteria ?? this.selectionCriteria,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      sentAt: sentAt ?? this.sentAt,
      deliveryStats: deliveryStats ?? this.deliveryStats,
      metadata: metadata ?? this.metadata,
      templateId: templateId ?? this.templateId,
      templateVariables: templateVariables ?? this.templateVariables,
    );
  }

  /// Mark message as sent
  BulkMessage markAsSent() {
    return copyWith(
      status: MessageStatus.sent,
      sentAt: DateTime.now(),
    );
  }

  /// Mark message as failed
  BulkMessage markAsFailed(String errorMessage) {
    return copyWith(
      status: MessageStatus.failed,
      metadata: {
        ...metadata,
        'error': errorMessage,
        'failedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Update delivery statistics
  BulkMessage updateDeliveryStats(Map<String, dynamic> stats) {
    return copyWith(
      deliveryStats: {
        ...deliveryStats,
        ...stats,
        'lastUpdated': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Schedule message for later delivery
  BulkMessage schedule(DateTime scheduledTime) {
    return copyWith(
      status: MessageStatus.scheduled,
      scheduledFor: scheduledTime,
    );
  }

  /// Cancel scheduled message
  BulkMessage cancel() {
    return copyWith(
      status: MessageStatus.cancelled,
      metadata: {
        ...metadata,
        'cancelledAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // Getters for delivery statistics
  int get totalRecipients => recipientIds.length;
  int get deliveredCount => deliveryStats['delivered'] as int? ?? 0;
  int get failedCount => deliveryStats['failed'] as int? ?? 0;
  int get openedCount => deliveryStats['opened'] as int? ?? 0;
  int get clickedCount => deliveryStats['clicked'] as int? ?? 0;
  
  double get deliveryRate => totalRecipients > 0 ? deliveredCount / totalRecipients : 0.0;
  double get openRate => deliveredCount > 0 ? openedCount / deliveredCount : 0.0;
  double get clickRate => openedCount > 0 ? clickedCount / openedCount : 0.0;

  bool get isScheduled => status == MessageStatus.scheduled;
  bool get isSent => status == MessageStatus.sent;
  bool get isFailed => status == MessageStatus.failed;
  bool get isPending => status == MessageStatus.pending;
  bool get isProcessing => status == MessageStatus.processing;
  bool get isCancelled => status == MessageStatus.cancelled;

  @override
  List<Object?> get props => [
        id,
        organizerId,
        subject,
        content,
        recipientIds,
        selectionCriteria,
        status,
        priority,
        createdAt,
        scheduledFor,
        sentAt,
        deliveryStats,
        metadata,
        templateId,
        templateVariables,
      ];

  @override
  String toString() {
    return 'BulkMessage(id: $id, organizerId: $organizerId, subject: $subject, status: ${status.name}, recipients: ${recipientIds.length})';
  }
}

/// Individual message delivery record
class MessageDelivery extends Equatable {
  final String id;
  final String bulkMessageId;
  final String recipientId;
  final String recipientEmail;
  final String recipientName;
  final String status; // delivered, failed, bounced, etc.
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final DateTime? clickedAt;
  final Map<String, dynamic> metadata;
  final String? errorMessage;

  const MessageDelivery({
    required this.id,
    required this.bulkMessageId,
    required this.recipientId,
    required this.recipientEmail,
    required this.recipientName,
    required this.status,
    this.deliveredAt,
    this.openedAt,
    this.clickedAt,
    this.metadata = const {},
    this.errorMessage,
  });

  factory MessageDelivery.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageDelivery(
      id: doc.id,
      bulkMessageId: data['bulkMessageId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      recipientEmail: data['recipientEmail'] ?? '',
      recipientName: data['recipientName'] ?? '',
      status: data['status'] ?? 'pending',
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      clickedAt: (data['clickedAt'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      errorMessage: data['errorMessage'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bulkMessageId': bulkMessageId,
      'recipientId': recipientId,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'status': status,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'clickedAt': clickedAt != null ? Timestamp.fromDate(clickedAt!) : null,
      'metadata': metadata,
      'errorMessage': errorMessage,
    };
  }

  MessageDelivery copyWith({
    String? id,
    String? bulkMessageId,
    String? recipientId,
    String? recipientEmail,
    String? recipientName,
    String? status,
    DateTime? deliveredAt,
    DateTime? openedAt,
    DateTime? clickedAt,
    Map<String, dynamic>? metadata,
    String? errorMessage,
  }) {
    return MessageDelivery(
      id: id ?? this.id,
      bulkMessageId: bulkMessageId ?? this.bulkMessageId,
      recipientId: recipientId ?? this.recipientId,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      recipientName: recipientName ?? this.recipientName,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      openedAt: openedAt ?? this.openedAt,
      clickedAt: clickedAt ?? this.clickedAt,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isDelivered => status == 'delivered';
  bool get isFailed => status == 'failed';
  bool get isOpened => openedAt != null;
  bool get isClicked => clickedAt != null;

  @override
  List<Object?> get props => [
        id,
        bulkMessageId,
        recipientId,
        recipientEmail,
        recipientName,
        status,
        deliveredAt,
        openedAt,
        clickedAt,
        metadata,
        errorMessage,
      ];

  @override
  String toString() {
    return 'MessageDelivery(id: $id, recipient: $recipientEmail, status: $status)';
  }
}