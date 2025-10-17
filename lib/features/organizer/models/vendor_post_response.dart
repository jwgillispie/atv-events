import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'organizer_vendor_post.dart';

class VendorProfileSummary extends Equatable {
  final String displayName;
  final List<String> categories;
  final String experience;
  final Map<String, dynamic> contactInfo;

  const VendorProfileSummary({
    required this.displayName,
    required this.categories,
    required this.experience,
    required this.contactInfo,
  });

  factory VendorProfileSummary.fromMap(Map<String, dynamic> data) {
    return VendorProfileSummary(
      displayName: data['displayName'] ?? '',
      categories: List<String>.from(data['categories'] ?? []),
      experience: data['experience'] ?? '',
      contactInfo: Map<String, dynamic>.from(data['contactInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'categories': categories,
      'experience': experience,
      'contactInfo': contactInfo,
    };
  }

  @override
  List<Object?> get props => [displayName, categories, experience, contactInfo];
}

class VendorPostResponse extends Equatable {
  final String id;
  final String postId;
  final String vendorId;
  final String organizerId;
  final String marketId;
  final ResponseType type;
  final String message;
  final VendorProfileSummary vendorProfile;
  final ResponseStatus status;
  final String? organizerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorPostResponse({
    required this.id,
    required this.postId,
    required this.vendorId,
    required this.organizerId,
    required this.marketId,
    required this.type,
    required this.message,
    required this.vendorProfile,
    required this.status,
    this.organizerNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorPostResponse.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return VendorPostResponse(
      id: doc.id,
      postId: data['postId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      organizerId: data['organizerId'] ?? '',
      marketId: data['marketId'] ?? '',
      type: ResponseType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => ResponseType.inquiry,
      ),
      message: data['message'] ?? '',
      vendorProfile: VendorProfileSummary.fromMap(data['vendorProfile'] ?? {}),
      status: ResponseStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => ResponseStatus.newResponse,
      ),
      organizerNotes: data['organizerNotes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'vendorId': vendorId,
      'organizerId': organizerId,
      'marketId': marketId,
      'type': type.name,
      'message': message,
      'vendorProfile': vendorProfile.toMap(),
      'status': status.name,
      'organizerNotes': organizerNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  VendorPostResponse copyWith({
    String? id,
    String? postId,
    String? vendorId,
    String? organizerId,
    String? marketId,
    ResponseType? type,
    String? message,
    VendorProfileSummary? vendorProfile,
    ResponseStatus? status,
    String? organizerNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorPostResponse(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      vendorId: vendorId ?? this.vendorId,
      organizerId: organizerId ?? this.organizerId,
      marketId: marketId ?? this.marketId,
      type: type ?? this.type,
      message: message ?? this.message,
      vendorProfile: vendorProfile ?? this.vendorProfile,
      status: status ?? this.status,
      organizerNotes: organizerNotes ?? this.organizerNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isNew => status == ResponseStatus.newResponse;
  bool get isReviewed => status == ResponseStatus.reviewed;
  bool get isAccepted => status == ResponseStatus.accepted;
  bool get isRejected => status == ResponseStatus.rejected;
  bool get isContacted => status == ResponseStatus.contacted;

  @override
  List<Object?> get props => [
        id,
        postId,
        vendorId,
        organizerId,
        marketId,
        type,
        message,
        vendorProfile,
        status,
        organizerNotes,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'VendorPostResponse(id: $id, type: ${type.name}, status: ${status.name})';
  }
}