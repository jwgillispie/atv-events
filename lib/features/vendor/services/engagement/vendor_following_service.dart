// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';

class VendorFollowingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> followVendor(String userId, String vendorId) async {
    // Do nothing - vendor features disabled
  }

  Future<void> unfollowVendor(String userId, String vendorId) async {
    // Do nothing - vendor features disabled
  }

  Future<bool> isFollowing(String userId, String vendorId) async {
    // Return false - vendor features disabled
    return false;
  }

  Stream<List<String>> getFollowedVendors(String userId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  Future<int> getFollowerCount(String vendorId) async {
    // Return 0 - vendor features disabled
    return 0;
  }
}
