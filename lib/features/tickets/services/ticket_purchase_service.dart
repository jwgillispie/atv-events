// TODO: Removed for ATV Events demo - Ticket features disabled
// This is a stub to maintain compilation

class TicketPurchaseService {
  static final TicketPurchaseService _instance = TicketPurchaseService._internal();
  factory TicketPurchaseService() => _instance;
  TicketPurchaseService._internal();

  Future<Map<String, dynamic>?> purchaseTicket({
    required String eventId,
    required String userId,
    required int quantity,
  }) async {
    // Return null - ticket features disabled
    return null;
  }

  Future<List<Map<String, dynamic>>> getUserTickets(String userId) async {
    // Return empty list - ticket features disabled
    return [];
  }

  Stream<List<Map<String, dynamic>>> getUserTicketsStream(String userId) {
    // Return empty stream - ticket features disabled
    return Stream.value([]);
  }

  /// Get cached upcoming ticket count for user
  static Future<int> getCachedUpcomingTicketCount(String userId) async {
    // Stub implementation - returns 0
    return 0;
  }
}
