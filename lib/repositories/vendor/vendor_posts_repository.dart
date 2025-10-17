// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/vendor/models/vendor_post.dart';

abstract class IVendorPostsRepository {
  Stream<List<VendorPost>> getVendorPosts({String? category});
  Stream<List<VendorPost>> getVendorPostsForUser(String userId);
  Future<VendorPost?> getVendorPostById(String postId);
  Stream<List<VendorPost>> searchPostsByLocation(String location);
  Stream<List<VendorPost>> getAllActivePosts();
}

class VendorPostsRepository implements IVendorPostsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<VendorPost>> getVendorPosts({String? category}) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  @override
  Stream<List<VendorPost>> getVendorPostsForUser(String userId) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  @override
  Future<VendorPost?> getVendorPostById(String postId) async {
    // Return null - vendor features disabled
    return null;
  }

  @override
  Stream<List<VendorPost>> searchPostsByLocation(String location) {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }

  @override
  Stream<List<VendorPost>> getAllActivePosts() {
    // Return empty stream - vendor features disabled
    return Stream.value([]);
  }
}
