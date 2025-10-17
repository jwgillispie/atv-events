import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../shared/models/location_data.dart';

class Market extends Equatable {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String? placeId;
  final DateTime eventDate; // Single specific date for this market event
  final String startTime; // e.g., "9:00 AM"
  final String endTime; // e.g., "2:00 PM"
  final String? description;
  final String? imageUrl;
  final List<String> flyerUrls;
  final String? instagramHandle;
  final bool isActive;
  final List<String> associatedVendorIds; // IDs of vendors associated with this market
  final DateTime createdAt;
  
  // Vendor Recruitment Fields
  final bool isLookingForVendors;
  final bool isRecruitmentOnly; // If true, only shows in vendor discovery, not shopper feed
  final String? applicationUrl;
  final double? applicationFee;
  final double? dailyBoothFee;
  final int? vendorSpotsAvailable;
  final int? vendorSpotsTotal;
  final DateTime? applicationDeadline;
  final String? vendorRequirements;
  final List<String>? targetCategories; // Categories to target for vendor recruitment

  // In-App Applications (NEW for vendor application system)
  final bool enableInAppApplications; // Enable in-app application flow
  final double? boothFee; // Booth/spot fee for approved applications (replaces dailyBoothFee for applications)
  final List<String> appliedVendorIds; // Vendors who have applied (any status)
  final List<String> confirmedVendorIds; // Vendors who paid and confirmed spot

  // Optimized Location Data
  final LocationData? locationData;
  
  // Organizer Information
  final String? organizerId; // User ID of the market organizer
  final String? organizerName; // Display name/organization name of the organizer
  
  // Market Type/Category
  final String? marketType; // e.g., 'farmers', 'popup', 'vegan', 'art', 'craft', 'night', 'holiday'

  const Market({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.placeId,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    this.description,
    this.imageUrl,
    this.flyerUrls = const [],
    this.instagramHandle,
    this.isActive = true,
    this.associatedVendorIds = const [],
    required this.createdAt,
    // Vendor Recruitment Fields with defaults
    this.isLookingForVendors = false,
    this.isRecruitmentOnly = false,
    this.applicationUrl,
    this.applicationFee,
    this.dailyBoothFee,
    this.vendorSpotsAvailable,
    this.vendorSpotsTotal,
    this.applicationDeadline,
    this.vendorRequirements,
    this.targetCategories,
    // In-App Applications
    this.enableInAppApplications = false,
    this.boothFee,
    this.appliedVendorIds = const [],
    this.confirmedVendorIds = const [],
    this.locationData,
    this.organizerId,
    this.organizerName,
    this.marketType,
  });

  factory Market.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    try {
      return Market(
        id: doc.id,
        name: data['name'] ?? '',
        address: data['address'] ?? '',
        city: data['city'] ?? '',
        state: data['state'] ?? '',
        latitude: data['latitude']?.toDouble() ?? 0.0,
        longitude: data['longitude']?.toDouble() ?? 0.0,
        placeId: data['placeId'],
        eventDate: (data['eventDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        startTime: data['startTime'] ?? '9:00 AM',
        endTime: data['endTime'] ?? '2:00 PM',
        description: data['description'],
        imageUrl: data['imageUrl'],
        flyerUrls: data['flyerUrls'] != null 
            ? List<String>.from(data['flyerUrls'])
            : [],
        instagramHandle: data['instagramHandle'],
        isActive: data['isActive'] ?? true,
        associatedVendorIds: data['associatedVendorIds'] != null
            ? List<String>.from(data['associatedVendorIds'])
            : [],
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        // Vendor Recruitment Fields
        isLookingForVendors: data['isLookingForVendors'] ?? false,
        isRecruitmentOnly: data['isRecruitmentOnly'] ?? false,
        applicationUrl: data['applicationUrl'],
        applicationFee: data['applicationFee']?.toDouble(),
        dailyBoothFee: data['dailyBoothFee']?.toDouble(),
        vendorSpotsAvailable: data['vendorSpotsAvailable'],
        vendorSpotsTotal: data['vendorSpotsTotal'],
        applicationDeadline: (data['applicationDeadline'] as Timestamp?)?.toDate(),
        vendorRequirements: data['vendorRequirements'],
        targetCategories: data['targetCategories'] != null
            ? List<String>.from(data['targetCategories'])
            : null,
        // In-App Applications
        enableInAppApplications: data['enableInAppApplications'] ?? false,
        boothFee: data['boothFee']?.toDouble(),
        appliedVendorIds: data['appliedVendorIds'] != null
            ? List<String>.from(data['appliedVendorIds'])
            : [],
        confirmedVendorIds: data['confirmedVendorIds'] != null
            ? List<String>.from(data['confirmedVendorIds'])
            : [],
        locationData: data['locationData'] != null
            ? LocationData.fromFirestore(data['locationData'])
            : null,
        organizerId: data['organizerId'],
        organizerName: data['organizerName'],
        marketType: data['marketType'] ?? _detectMarketType(data['name'] ?? '', data['description'] ?? ''),
      );
    } catch (e) {
      // Error parsing Market from Firestore
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      'imageUrl': imageUrl,
      'flyerUrls': flyerUrls,
      'instagramHandle': instagramHandle,
      'isActive': isActive,
      'associatedVendorIds': associatedVendorIds,
      'createdAt': Timestamp.fromDate(createdAt),
      // Vendor Recruitment Fields
      'isLookingForVendors': isLookingForVendors,
      'isRecruitmentOnly': isRecruitmentOnly,
      'applicationUrl': applicationUrl,
      'applicationFee': applicationFee,
      'dailyBoothFee': dailyBoothFee,
      'vendorSpotsAvailable': vendorSpotsAvailable,
      'vendorSpotsTotal': vendorSpotsTotal,
      'applicationDeadline': applicationDeadline != null 
          ? Timestamp.fromDate(applicationDeadline!) 
          : null,
      'vendorRequirements': vendorRequirements,
      'targetCategories': targetCategories,
      // In-App Applications
      'enableInAppApplications': enableInAppApplications,
      'boothFee': boothFee,
      'appliedVendorIds': appliedVendorIds,
      'confirmedVendorIds': confirmedVendorIds,
      'locationData': locationData?.toFirestore(),
      'organizerId': organizerId,
      'organizerName': organizerName,
      'marketType': marketType,
    };
  }

  Market copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    String? placeId,
    DateTime? eventDate,
    String? startTime,
    String? endTime,
    String? description,
    String? imageUrl,
    List<String>? flyerUrls,
    String? instagramHandle,
    bool? isActive,
    List<String>? associatedVendorIds,
    DateTime? createdAt,
    bool? isLookingForVendors,
    bool? isRecruitmentOnly,
    String? applicationUrl,
    double? applicationFee,
    double? dailyBoothFee,
    int? vendorSpotsAvailable,
    int? vendorSpotsTotal,
    DateTime? applicationDeadline,
    String? vendorRequirements,
    List<String>? targetCategories,
    bool? enableInAppApplications,
    double? boothFee,
    List<String>? appliedVendorIds,
    List<String>? confirmedVendorIds,
    LocationData? locationData,
    String? organizerId,
    String? organizerName,
    String? marketType,
  }) {
    return Market(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      flyerUrls: flyerUrls ?? this.flyerUrls,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      isActive: isActive ?? this.isActive,
      associatedVendorIds: associatedVendorIds ?? this.associatedVendorIds,
      createdAt: createdAt ?? this.createdAt,
      isLookingForVendors: isLookingForVendors ?? this.isLookingForVendors,
      isRecruitmentOnly: isRecruitmentOnly ?? this.isRecruitmentOnly,
      applicationUrl: applicationUrl ?? this.applicationUrl,
      applicationFee: applicationFee ?? this.applicationFee,
      dailyBoothFee: dailyBoothFee ?? this.dailyBoothFee,
      vendorSpotsAvailable: vendorSpotsAvailable ?? this.vendorSpotsAvailable,
      vendorSpotsTotal: vendorSpotsTotal ?? this.vendorSpotsTotal,
      applicationDeadline: applicationDeadline ?? this.applicationDeadline,
      vendorRequirements: vendorRequirements ?? this.vendorRequirements,
      targetCategories: targetCategories ?? this.targetCategories,
      enableInAppApplications: enableInAppApplications ?? this.enableInAppApplications,
      boothFee: boothFee ?? this.boothFee,
      appliedVendorIds: appliedVendorIds ?? this.appliedVendorIds,
      confirmedVendorIds: confirmedVendorIds ?? this.confirmedVendorIds,
      locationData: locationData ?? this.locationData,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      marketType: marketType ?? this.marketType,
    );
  }

  // Helper methods
  String get fullAddress => '$address, $city, $state';
  
  /// Whether this market event is happening today
  bool get isHappeningToday {
    final today = DateTime.now();
    return eventDate.year == today.year &&
           eventDate.month == today.month &&
           eventDate.day == today.day;
  }
  
  /// Whether this market event is in the future
  bool get isFutureEvent {
    return eventDate.isAfter(DateTime.now());
  }
  
  /// Whether this market event is in the past
  bool get isPastEvent {
    return eventDate.isBefore(DateTime.now());
  }
  
  /// Time range as a formatted string
  String get timeRange => '$startTime - $endTime';
  
  /// Combined date and time information for display
  String get eventDisplayInfo {
    final dateStr = '${eventDate.month}/${eventDate.day}/${eventDate.year}';
    return '$dateStr • $timeRange';
  }
  
  /// Helper methods for vendor recruitment
  bool get hasAvailableSpots {
    if (vendorSpotsAvailable == null || vendorSpotsTotal == null) return true;
    return vendorSpotsAvailable! > 0;
  }
  
  String get spotsDisplay {
    if (vendorSpotsAvailable == null || vendorSpotsTotal == null) {
      return 'Spots available';
    }
    return '$vendorSpotsAvailable of $vendorSpotsTotal spots available';
  }
  
  bool get isApplicationDeadlinePassed {
    if (applicationDeadline == null) return false;
    return applicationDeadline!.isBefore(DateTime.now());
  }
  
  bool get isApplicationDeadlineUrgent {
    if (applicationDeadline == null) return false;
    final daysUntilDeadline = applicationDeadline!.difference(DateTime.now()).inDays;
    return daysUntilDeadline <= 3 && daysUntilDeadline >= 0;
  }
  
  String get applicationDeadlineDisplay {
    if (applicationDeadline == null) return '';
    final now = DateTime.now();
    final difference = applicationDeadline!.difference(now);
    
    if (difference.isNegative) {
      return 'Application closed';
    } else if (difference.inDays == 0) {
      return 'Deadline: Today';
    } else if (difference.inDays == 1) {
      return 'Deadline: Tomorrow';
    } else if (difference.inDays <= 7) {
      return 'Deadline: ${difference.inDays} days';
    } else {
      return 'Deadline: ${applicationDeadline!.month}/${applicationDeadline!.day}';
    }
  }

  /// Detect market type based on name and description
  static String _detectMarketType(String name, String description) {
    final combinedText = '$name $description'.toLowerCase();
    
    // Check for specific market types based on keywords
    if (combinedText.contains('farmers') || combinedText.contains('farmer\'s') || 
        combinedText.contains('farm')) {
      return 'farmers';
    } else if (combinedText.contains('vegan') || combinedText.contains('plant-based') ||
               combinedText.contains('vegetarian')) {
      return 'vegan';
    } else if (combinedText.contains('art') || combinedText.contains('artist') ||
               combinedText.contains('gallery')) {
      return 'art';
    } else if (combinedText.contains('craft') || combinedText.contains('handmade') ||
               combinedText.contains('artisan')) {
      return 'craft';
    } else if (combinedText.contains('night') || combinedText.contains('evening') ||
               combinedText.contains('twilight')) {
      return 'night';
    } else if (combinedText.contains('holiday') || combinedText.contains('christmas') ||
               combinedText.contains('thanksgiving') || combinedText.contains('halloween')) {
      return 'holiday';
    } else if (combinedText.contains('flea') || combinedText.contains('vintage') ||
               combinedText.contains('antique')) {
      return 'flea';
    } else if (combinedText.contains('food truck') || combinedText.contains('foodie')) {
      return 'food';
    } else if (combinedText.contains('pop-up') || combinedText.contains('popup') ||
               combinedText.contains('pop up')) {
      return 'popup';
    }
    
    // Default to popup for general markets
    return 'popup';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        city,
        state,
        latitude,
        longitude,
        placeId,
        eventDate,
        startTime,
        endTime,
        description,
        imageUrl,
        flyerUrls,
        instagramHandle,
        isActive,
        associatedVendorIds,
        createdAt,
        isLookingForVendors,
        isRecruitmentOnly,
        applicationUrl,
        applicationFee,
        dailyBoothFee,
        vendorSpotsAvailable,
        vendorSpotsTotal,
        applicationDeadline,
        vendorRequirements,
        locationData,
        organizerId,
        organizerName,
        marketType,
      ];
}