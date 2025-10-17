import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum PostStatus {
  active,
  paused,
  closed,
  expired,
}

enum PostVisibility {
  public,
  premiumOnly,
}

enum ExperienceLevel {
  beginner,
  intermediate,
  experienced,
  expert,
}

enum ContactMethod {
  email,
  phone,
  form,
}

enum ResponseType {
  inquiry,
  application,
  interest,
}

enum ResponseStatus {
  newResponse,
  reviewed,
  contacted,
  accepted,
  rejected,
}

class VendorRequirements extends Equatable {
  final ExperienceLevel experienceLevel;
  final DateTime? applicationDeadline;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? boothFee;
  final double? commissionRate;

  const VendorRequirements({
    required this.experienceLevel,
    this.applicationDeadline,
    this.startDate,
    this.endDate,
    this.boothFee,
    this.commissionRate,
  });

  factory VendorRequirements.fromMap(Map<String, dynamic> data) {
    return VendorRequirements(
      experienceLevel: ExperienceLevel.values.firstWhere(
        (level) => level.name == data['experienceLevel'],
        orElse: () => ExperienceLevel.beginner,
      ),
      applicationDeadline: data['applicationDeadline'] != null
          ? (data['applicationDeadline'] as Timestamp).toDate()
          : null,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      boothFee: data['boothFee']?.toDouble(),
      commissionRate: data['commissionRate']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'experienceLevel': experienceLevel.name,
      'applicationDeadline': applicationDeadline != null
          ? Timestamp.fromDate(applicationDeadline!)
          : null,
      'startDate': startDate != null
          ? Timestamp.fromDate(startDate!)
          : null,
      'endDate': endDate != null
          ? Timestamp.fromDate(endDate!)
          : null,
      'boothFee': boothFee,
      'commissionRate': commissionRate,
    };
  }

  @override
  List<Object?> get props => [
        experienceLevel,
        applicationDeadline,
        startDate,
        endDate,
        boothFee,
        commissionRate,
      ];
}

class ContactInfo extends Equatable {
  final ContactMethod preferredMethod;
  final String? email;
  final String? phone;
  final String? formUrl;

  const ContactInfo({
    required this.preferredMethod,
    this.email,
    this.phone,
    this.formUrl,
  });

  factory ContactInfo.fromMap(Map<String, dynamic> data) {
    return ContactInfo(
      preferredMethod: ContactMethod.values.firstWhere(
        (method) => method.name == data['preferredMethod'],
        orElse: () => ContactMethod.email,
      ),
      email: data['email'],
      phone: data['phone'],
      formUrl: data['formUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredMethod': preferredMethod.name,
      'email': email,
      'phone': phone,
      'formUrl': formUrl,
    };
  }

  @override
  List<Object?> get props => [preferredMethod, email, phone, formUrl];
}

class PostAnalytics extends Equatable {
  final int views;
  final int applications;
  final int responses;

  const PostAnalytics({
    this.views = 0,
    this.applications = 0,
    this.responses = 0,
  });

  factory PostAnalytics.fromMap(Map<String, dynamic> data) {
    return PostAnalytics(
      views: data['views'] ?? 0,
      applications: data['applications'] ?? 0,
      responses: data['responses'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'views': views,
      'applications': applications,
      'responses': responses,
    };
  }

  PostAnalytics copyWith({
    int? views,
    int? applications,
    int? responses,
  }) {
    return PostAnalytics(
      views: views ?? this.views,
      applications: applications ?? this.applications,
      responses: responses ?? this.responses,
    );
  }

  @override
  List<Object?> get props => [views, applications, responses];
}

class PostMetadata extends Equatable {
  final bool featured;
  final String urgency;
  final List<String> tags;

  const PostMetadata({
    this.featured = false,
    this.urgency = 'medium',
    this.tags = const [],
  });

  factory PostMetadata.fromMap(Map<String, dynamic> data) {
    return PostMetadata(
      featured: data['featured'] ?? false,
      urgency: data['urgency'] ?? 'medium',
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'featured': featured,
      'urgency': urgency,
      'tags': tags,
    };
  }

  @override
  List<Object?> get props => [featured, urgency, tags];
}

class OrganizerVendorPost extends Equatable {
  final String id;
  final String organizerId;
  final String marketId;
  final String title;
  final String description;
  final List<String> categories;
  final VendorRequirements requirements;
  final ContactInfo contactInfo;
  final PostStatus status;
  final PostVisibility visibility;
  final PostAnalytics analytics;
  final PostMetadata metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;

  const OrganizerVendorPost({
    required this.id,
    required this.organizerId,
    required this.marketId,
    required this.title,
    required this.description,
    required this.categories,
    required this.requirements,
    required this.contactInfo,
    required this.status,
    required this.visibility,
    required this.analytics,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  factory OrganizerVendorPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrganizerVendorPost(
      id: doc.id,
      organizerId: data['organizerId'] ?? '',
      marketId: data['marketId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      categories: List<String>.from(data['categories'] ?? []),
      requirements: VendorRequirements.fromMap(data['requirements'] ?? {}),
      contactInfo: ContactInfo.fromMap(data['contactInfo'] ?? {}),
      status: PostStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => PostStatus.active,
      ),
      visibility: PostVisibility.values.firstWhere(
        (visibility) => visibility.name == data['visibility'],
        orElse: () => PostVisibility.public,
      ),
      analytics: PostAnalytics.fromMap(data['analytics'] ?? {}),
      metadata: PostMetadata.fromMap(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizerId': organizerId,
      'marketId': marketId,
      'title': title,
      'description': description,
      'categories': categories,
      'requirements': requirements.toMap(),
      'contactInfo': contactInfo.toMap(),
      'status': status.name,
      'visibility': visibility.name,
      'analytics': analytics.toMap(),
      'metadata': metadata.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  OrganizerVendorPost copyWith({
    String? id,
    String? organizerId,
    String? marketId,
    String? title,
    String? description,
    List<String>? categories,
    VendorRequirements? requirements,
    ContactInfo? contactInfo,
    PostStatus? status,
    PostVisibility? visibility,
    PostAnalytics? analytics,
    PostMetadata? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return OrganizerVendorPost(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      marketId: marketId ?? this.marketId,
      title: title ?? this.title,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      requirements: requirements ?? this.requirements,
      contactInfo: contactInfo ?? this.contactInfo,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      analytics: analytics ?? this.analytics,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isActive => status == PostStatus.active;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isPremiumOnly => visibility == PostVisibility.premiumOnly;

  @override
  List<Object?> get props => [
        id,
        organizerId,
        marketId,
        title,
        description,
        categories,
        requirements,
        contactInfo,
        status,
        visibility,
        analytics,
        metadata,
        createdAt,
        updatedAt,
        expiresAt,
      ];

  @override
  String toString() {
    return 'OrganizerVendorPost(id: $id, title: $title, status: ${status.name})';
  }
}