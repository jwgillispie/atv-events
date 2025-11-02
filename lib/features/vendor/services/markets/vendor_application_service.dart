// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/vendor_application.dart';

class VendorApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Static method to get approved applications for a market
  static Future<List<VendorApplication>> getApprovedApplicationsForMarket(
    String marketId,
  ) async {
    // Return empty list - vendor features disabled
    return [];
  }

  Future<VendorApplication?> getApplication(String applicationId) async {
    // Return null - vendor features disabled
    return null;
  }

  Stream<List<VendorApplication>> getApplicationsForVendor(String vendorId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  Stream<List<VendorApplication>> getApplicationsForMarket(String marketId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  Future<void> createApplication(VendorApplication application) async {
    // Do nothing - vendor features disabled
  }

  Future<void> updateApplicationStatus(String applicationId, String status) async {
    // Do nothing - vendor features disabled
  }
}
