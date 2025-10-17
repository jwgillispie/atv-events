import 'package:cloud_firestore/cloud_firestore.dart';

class WaitlistEntry {
  final String id;
  final String productId;
  final String userId;
  final String userEmail;
  final String vendorId;
  final String? popupId;
  final DateTime createdAt;
  final bool notified;

  const WaitlistEntry({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userEmail,
    required this.vendorId,
    this.popupId,
    required this.createdAt,
    this.notified = false,
  });

  factory WaitlistEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WaitlistEntry(
      id: doc.id,
      productId: data['productId'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      vendorId: data['vendorId'] ?? '',
      popupId: data['popupId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      notified: data['notified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'userId': userId,
      'userEmail': userEmail,
      'vendorId': vendorId,
      'popupId': popupId,
      'createdAt': Timestamp.fromDate(createdAt),
      'notified': notified,
    };
  }
}
