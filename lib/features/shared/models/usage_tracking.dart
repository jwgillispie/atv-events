import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum UsageMetricType {
  marketParticipation,
  eventCreation,
  photoUpload,
  analyticsView,
  favoriteMarket,
  searchQuery,
  applicationSubmission,
  vendorInvitation,
  marketManagement,
}

class UsageTracking extends Equatable {
  final String id;
  final String userId;
  final String userType;
  final UsageMetricType metricType;
  final String metricName;
  final int count;
  final int monthYear;
  final String? resourceId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UsageTracking({
    required this.id,
    required this.userId,
    required this.userType,
    required this.metricType,
    required this.metricName,
    required this.count,
    required this.monthYear,
    this.resourceId,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UsageTracking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UsageTracking(
      id: doc.id,
      userId: data['userId'] ?? '',
      userType: data['userType'] ?? 'shopper',
      metricType: UsageMetricType.values.firstWhere(
        (type) => type.name == data['metricType'],
        orElse: () => UsageMetricType.searchQuery,
      ),
      metricName: data['metricName'] ?? '',
      count: data['count'] ?? 0,
      monthYear: data['monthYear'] ?? 0,
      resourceId: data['resourceId'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userType': userType,
      'metricType': metricType.name,
      'metricName': metricName,
      'count': count,
      'monthYear': monthYear,
      'resourceId': resourceId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UsageTracking copyWith({
    String? id,
    String? userId,
    String? userType,
    UsageMetricType? metricType,
    String? metricName,
    int? count,
    int? monthYear,
    String? resourceId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UsageTracking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      metricType: metricType ?? this.metricType,
      metricName: metricName ?? this.metricName,
      count: count ?? this.count,
      monthYear: monthYear ?? this.monthYear,
      resourceId: resourceId ?? this.resourceId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  UsageTracking incrementCount({int increment = 1}) {
    return copyWith(
      count: count + increment,
      updatedAt: DateTime.now(),
    );
  }

  static int generateMonthYearKey(DateTime date) {
    return date.year * 100 + date.month;
  }

  static int getCurrentMonthYear() {
    return generateMonthYearKey(DateTime.now());
  }

  static DateTime monthYearToDate(int monthYear) {
    final year = monthYear ~/ 100;
    final month = monthYear % 100;
    return DateTime(year, month, 1);
  }

  String get monthYearDisplay {
    final date = monthYearToDate(monthYear);
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month]} ${date.year}';
  }

  bool get isCurrentMonth {
    return monthYear == getCurrentMonthYear();
  }

  factory UsageTracking.create({
    required String userId,
    required String userType,
    required UsageMetricType metricType,
    required String metricName,
    String? resourceId,
    int count = 1,
    DateTime? date,
    Map<String, dynamic>? metadata,
  }) {
    final now = date ?? DateTime.now();
    return UsageTracking(
      id: '',
      userId: userId,
      userType: userType,
      metricType: metricType,
      metricName: metricName,
      count: count,
      monthYear: generateMonthYearKey(now),
      resourceId: resourceId,
      metadata: metadata ?? {},
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userType,
        metricType,
        metricName,
        count,
        monthYear,
        resourceId,
        metadata,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'UsageTracking(id: $id, userId: $userId, metricType: ${metricType.name}, count: $count, monthYear: $monthYear)';
  }
}

class UsageAggregate extends Equatable {
  final String userId;
  final String userType;
  final int monthYear;
  final Map<String, int> metrics;
  final DateTime calculatedAt;

  const UsageAggregate({
    required this.userId,
    required this.userType,
    required this.monthYear,
    required this.metrics,
    required this.calculatedAt,
  });

  factory UsageAggregate.fromUsageRecords(
    String userId,
    String userType,
    int monthYear,
    List<UsageTracking> usageRecords,
  ) {
    final metrics = <String, int>{};
    
    for (final record in usageRecords) {
      if (record.userId == userId && record.monthYear == monthYear) {
        metrics[record.metricName] = (metrics[record.metricName] ?? 0) + record.count;
      }
    }
    
    return UsageAggregate(
      userId: userId,
      userType: userType,
      monthYear: monthYear,
      metrics: metrics,
      calculatedAt: DateTime.now(),
    );
  }

  int getMetric(String metricName) {
    return metrics[metricName] ?? 0;
  }

  bool hasMetric(String metricName) {
    return metrics.containsKey(metricName);
  }

  List<String> get availableMetrics {
    return metrics.keys.toList();
  }

  int get totalUsage {
    return metrics.values.fold(0, (total, metricCount) => total + metricCount);
  }

  String get monthYearDisplay {
    final date = UsageTracking.monthYearToDate(monthYear);
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month]} ${date.year}';
  }

  @override
  List<Object?> get props => [
        userId,
        userType,
        monthYear,
        metrics,
        calculatedAt,
      ];

  @override
  String toString() {
    return 'UsageAggregate(userId: $userId, monthYear: $monthYear, totalUsage: $totalUsage)';
  }
}