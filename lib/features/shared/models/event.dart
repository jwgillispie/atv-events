import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class EventLink extends Equatable {
  final String label;
  final String url;
  final EventLinkType type;

  const EventLink({
    required this.label,
    required this.url,
    required this.type,
  });

  @override
  List<Object?> get props => [label, url, type];

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'url': url,
      'type': type.value,
    };
  }

  factory EventLink.fromMap(Map<String, dynamic> map) {
    return EventLink(
      label: map['label'] ?? '',
      url: map['url'] ?? '',
      type: EventLinkType.fromString(map['type'] ?? 'website'),
    );
  }
}

enum EventLinkType {
  tickets('tickets', 'Tickets'),
  registration('registration', 'Registration'),
  website('website', 'Website'),
  facebook('facebook', 'Facebook'),
  instagram('instagram', 'Instagram'),
  other('other', 'Other');

  final String value;
  final String displayName;
  const EventLinkType(this.value, this.displayName);

  static EventLinkType fromString(String value) {
    return EventLinkType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => EventLinkType.other,
    );
  }
}

class Event extends Equatable {
  final String id;
  final String name;
  final String description;
  final String location;
  final String address;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? organizerId;
  final String? organizerName;
  final String? marketId; // Optional: events can be associated with markets
  final List<String> tags;
  final String? imageUrl;
  final List<EventLink> links; // Event links for tickets, registration, etc.
  final String? eventWebsite;
  final String? instagramUrl;
  final String? facebookUrl;
  final String? ticketUrl;
  final Map<String, String>? additionalLinks;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Ticketing fields
  final bool hasTicketing; // Whether event has ticketing enabled
  final int? totalTicketsSold; // Total tickets sold across all ticket types
  final double? totalRevenue; // Total revenue from ticket sales
  final int? totalAttendees; // Total tickets actually scanned/used
  final double? actualRevenue; // Revenue from tickets that were actually scanned
  final bool? requiresTicket; // Whether attendance requires a ticket

  // Ticket Configuration (for simple single-tier ticketing)
  final double? ticketPrice; // Base ticket price
  final int? maxAttendees; // Maximum number of attendees/tickets
  final double? earlyBirdPrice; // Early bird ticket price (optional)
  final DateTime? earlyBirdDeadline; // When early bird pricing ends
  final bool? enableQRScanning; // Whether QR code scanning is enabled for check-in
  final String? ticketDescription; // Description of what's included with ticket

  const Event({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.address,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.startDateTime,
    required this.endDateTime,
    this.organizerId,
    this.organizerName,
    this.marketId,
    this.tags = const [],
    this.imageUrl,
    this.links = const [],
    this.eventWebsite,
    this.instagramUrl,
    this.facebookUrl,
    this.ticketUrl,
    this.additionalLinks,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.hasTicketing = false,
    this.totalTicketsSold,
    this.totalRevenue,
    this.totalAttendees,
    this.actualRevenue,
    this.requiresTicket,
    this.ticketPrice,
    this.maxAttendees,
    this.earlyBirdPrice,
    this.earlyBirdDeadline,
    this.enableQRScanning,
    this.ticketDescription,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        location,
        address,
        city,
        state,
        latitude,
        longitude,
        startDateTime,
        endDateTime,
        organizerId,
        organizerName,
        marketId,
        tags,
        imageUrl,
        links,
        eventWebsite,
        instagramUrl,
        facebookUrl,
        ticketUrl,
        additionalLinks,
        isActive,
        createdAt,
        updatedAt,
        hasTicketing,
        totalTicketsSold,
        totalRevenue,
        totalAttendees,
        actualRevenue,
        requiresTicket,
        ticketPrice,
        maxAttendees,
        earlyBirdPrice,
        earlyBirdDeadline,
        enableQRScanning,
        ticketDescription,
      ];

  Event copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    String? address,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? organizerId,
    String? organizerName,
    String? marketId,
    List<String>? tags,
    String? imageUrl,
    List<EventLink>? links,
    String? eventWebsite,
    String? instagramUrl,
    String? facebookUrl,
    String? ticketUrl,
    Map<String, String>? additionalLinks,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasTicketing,
    int? totalTicketsSold,
    double? totalRevenue,
    int? totalAttendees,
    double? actualRevenue,
    bool? requiresTicket,
    double? ticketPrice,
    int? maxAttendees,
    double? earlyBirdPrice,
    DateTime? earlyBirdDeadline,
    bool? enableQRScanning,
    String? ticketDescription,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      marketId: marketId ?? this.marketId,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      links: links ?? this.links,
      eventWebsite: eventWebsite ?? this.eventWebsite,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      additionalLinks: additionalLinks ?? this.additionalLinks,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasTicketing: hasTicketing ?? this.hasTicketing,
      totalTicketsSold: totalTicketsSold ?? this.totalTicketsSold,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalAttendees: totalAttendees ?? this.totalAttendees,
      actualRevenue: actualRevenue ?? this.actualRevenue,
      requiresTicket: requiresTicket ?? this.requiresTicket,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      earlyBirdPrice: earlyBirdPrice ?? this.earlyBirdPrice,
      earlyBirdDeadline: earlyBirdDeadline ?? this.earlyBirdDeadline,
      enableQRScanning: enableQRScanning ?? this.enableQRScanning,
      ticketDescription: ticketDescription ?? this.ticketDescription,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'address': address,
      'city': city,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'organizerId': organizerId,
      'organizerName': organizerName,
      'marketId': marketId,
      'tags': tags,
      'imageUrl': imageUrl,
      'links': links.map((link) => link.toMap()).toList(),
      'eventWebsite': eventWebsite,
      'instagramUrl': instagramUrl,
      'facebookUrl': facebookUrl,
      'ticketUrl': ticketUrl,
      'additionalLinks': additionalLinks,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'hasTicketing': hasTicketing,
      'totalTicketsSold': totalTicketsSold,
      'totalRevenue': totalRevenue,
      'totalAttendees': totalAttendees,
      'actualRevenue': actualRevenue,
      'requiresTicket': requiresTicket,
      'ticketPrice': ticketPrice,
      'maxAttendees': maxAttendees,
      'earlyBirdPrice': earlyBirdPrice,
      'earlyBirdDeadline': earlyBirdDeadline != null
          ? Timestamp.fromDate(earlyBirdDeadline!)
          : null,
      'enableQRScanning': enableQRScanning,
      'ticketDescription': ticketDescription,
    };
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      startDateTime: data['startDateTime'] != null
          ? (data['startDateTime'] as Timestamp).toDate()
          : DateTime.now(),
      endDateTime: data['endDateTime'] != null
          ? (data['endDateTime'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(hours: 2)),
      organizerId: data['organizerId'],
      organizerName: data['organizerName'],
      marketId: data['marketId'],
      tags: List<String>.from(data['tags'] ?? []),
      imageUrl: data['imageUrl'],
      links: (data['links'] as List<dynamic>?)
          ?.map((link) => EventLink.fromMap(link as Map<String, dynamic>))
          .toList() ?? [],
      eventWebsite: data['eventWebsite'],
      instagramUrl: data['instagramUrl'],
      facebookUrl: data['facebookUrl'],
      ticketUrl: data['ticketUrl'],
      additionalLinks: data['additionalLinks'] != null
          ? Map<String, String>.from(data['additionalLinks'])
          : null,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      hasTicketing: data['hasTicketing'] ?? false,
      totalTicketsSold: data['totalTicketsSold'],
      totalRevenue: data['totalRevenue'] != null
          ? (data['totalRevenue'] as num).toDouble()
          : null,
      totalAttendees: data['totalAttendees'],
      actualRevenue: data['actualRevenue'] != null
          ? (data['actualRevenue'] as num).toDouble()
          : null,
      requiresTicket: data['requiresTicket'],
      ticketPrice: data['ticketPrice'] != null
          ? (data['ticketPrice'] as num).toDouble()
          : null,
      maxAttendees: data['maxAttendees'],
      earlyBirdPrice: data['earlyBirdPrice'] != null
          ? (data['earlyBirdPrice'] as num).toDouble()
          : null,
      earlyBirdDeadline: data['earlyBirdDeadline'] != null
          ? (data['earlyBirdDeadline'] as Timestamp).toDate()
          : null,
      enableQRScanning: data['enableQRScanning'],
      ticketDescription: data['ticketDescription'],
    );
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      startDateTime: map['startDateTime'] is Timestamp
          ? (map['startDateTime'] as Timestamp).toDate()
          : DateTime.parse(map['startDateTime']),
      endDateTime: map['endDateTime'] is Timestamp
          ? (map['endDateTime'] as Timestamp).toDate()
          : DateTime.parse(map['endDateTime']),
      organizerId: map['organizerId'],
      organizerName: map['organizerName'],
      marketId: map['marketId'],
      tags: List<String>.from(map['tags'] ?? []),
      imageUrl: map['imageUrl'],
      links: (map['links'] as List<dynamic>?)
          ?.map((link) => EventLink.fromMap(link as Map<String, dynamic>))
          .toList() ?? [],
      eventWebsite: map['eventWebsite'],
      instagramUrl: map['instagramUrl'],
      facebookUrl: map['facebookUrl'],
      ticketUrl: map['ticketUrl'],
      additionalLinks: map['additionalLinks'] != null
          ? Map<String, String>.from(map['additionalLinks'])
          : null,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt']),
      hasTicketing: map['hasTicketing'] ?? false,
      totalTicketsSold: map['totalTicketsSold'],
      totalRevenue: map['totalRevenue'] != null
          ? (map['totalRevenue'] as num).toDouble()
          : null,
      totalAttendees: map['totalAttendees'],
      actualRevenue: map['actualRevenue'] != null
          ? (map['actualRevenue'] as num).toDouble()
          : null,
      requiresTicket: map['requiresTicket'],
      ticketPrice: map['ticketPrice'] != null
          ? (map['ticketPrice'] as num).toDouble()
          : null,
      maxAttendees: map['maxAttendees'],
      earlyBirdPrice: map['earlyBirdPrice'] != null
          ? (map['earlyBirdPrice'] as num).toDouble()
          : null,
      earlyBirdDeadline: map['earlyBirdDeadline'] is Timestamp
          ? (map['earlyBirdDeadline'] as Timestamp).toDate()
          : map['earlyBirdDeadline'] != null
              ? DateTime.parse(map['earlyBirdDeadline'])
              : null,
      enableQRScanning: map['enableQRScanning'],
      ticketDescription: map['ticketDescription'],
    );
  }

  /// Check if the event is currently happening
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDateTime) && now.isBefore(endDateTime);
  }

  /// Check if the event is upcoming (starts in the future)
  bool get isUpcoming {
    final now = DateTime.now();
    return isActive && startDateTime.isAfter(now);
  }

  /// Check if the event has ended
  bool get hasEnded {
    final now = DateTime.now();
    return endDateTime.isBefore(now);
  }

  /// Get formatted date and time string
  String get formattedDateTime {
    final startDate = startDateTime;
    final endDate = endDateTime;
    
    if (startDate.day == endDate.day &&
        startDate.month == endDate.month &&
        startDate.year == endDate.year) {
      // Same day event
      return '${_formatDate(startDate)} ${_formatTime(startDate)} - ${_formatTime(endDate)}';
    } else {
      // Multi-day event
      return '${_formatDate(startDate)} ${_formatTime(startDate)} - ${_formatDate(endDate)} ${_formatTime(endDate)}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
}