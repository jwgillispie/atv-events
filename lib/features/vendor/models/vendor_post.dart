// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class VendorPost extends Equatable {
  final String id;
  final String vendorId;
  final String vendorName;
  final String? imageUrl;
  final String? description;
  final DateTime createdAt;
  final String? category;
  final Map<String, dynamic>? metadata;
  // TODO: Removed for ATV MVP - location fields for compatibility
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime popUpStartDateTime;
  final DateTime popUpEndDateTime;
  final List<String> photoUrls;
  final String? instagramHandle;
  final String? marketId;

  const VendorPost({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.imageUrl,
    this.description,
    required this.createdAt,
    this.category,
    this.metadata,
    this.locationName,
    this.latitude,
    this.longitude,
    DateTime? popUpStartDateTime,
    DateTime? popUpEndDateTime,
    this.photoUrls = const [],
    this.instagramHandle,
    this.marketId,
  }) : popUpStartDateTime = popUpStartDateTime ?? createdAt,
       popUpEndDateTime = popUpEndDateTime ?? createdAt;

  /// Getter for backward compatibility with location field
  String get location => locationName ?? '';

  /// Getter to check if the popup is upcoming (not in the past)
  bool get isUpcoming => popUpEndDateTime.isAfter(DateTime.now());

  /// Getter to check if the event is currently happening
  bool get isHappening {
    final now = DateTime.now();
    return now.isAfter(popUpStartDateTime) && now.isBefore(popUpEndDateTime);
  }

  /// Getter for formatted date/time string
  String get formattedDateTime {
    final start = popUpStartDateTime;
    final end = popUpEndDateTime;

    // Format: "Mon, Jan 1 • 10:00 AM - 5:00 PM"
    final dateStr = '${_monthName(start.month)} ${start.day}';
    final startTime = _formatTime(start);
    final endTime = _formatTime(end);

    return '$dateStr • $startTime - $endTime';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  factory VendorPost.fromMap(Map<String, dynamic> map, String id) {
    return VendorPost(
      id: id,
      vendorId: map['vendorId'] as String? ?? '',
      vendorName: map['vendorName'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      description: map['description'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      locationName: map['locationName'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      popUpStartDateTime: (map['popUpStartDateTime'] as Timestamp?)?.toDate(),
      popUpEndDateTime: (map['popUpEndDateTime'] as Timestamp?)?.toDate(),
      photoUrls: (map['photoUrls'] as List?)?.cast<String>() ?? [],
      instagramHandle: map['instagramHandle'] as String?,
      marketId: map['marketId'] as String?,
    );
  }

  /// Factory constructor from Firestore DocumentSnapshot
  factory VendorPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }
    return VendorPost.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        vendorId,
        vendorName,
        imageUrl,
        description,
        createdAt,
        category,
        metadata,
        locationName,
        latitude,
        longitude,
        popUpStartDateTime,
        popUpEndDateTime,
        photoUrls,
        instagramHandle,
        marketId,
      ];
}
