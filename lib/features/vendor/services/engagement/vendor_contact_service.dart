// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendContactMessage({
    required String vendorId,
    required String userId,
    required String message,
  }) async {
    // Do nothing - vendor features disabled
  }

  Future<List<Map<String, dynamic>>> getContactMessages(String vendorId) async {
    // Return empty list - vendor features disabled
    return [];
  }

  /// Launch email
  Future<void> launchEmail(String? email, {String? subject, String? body}) async {
    if (email == null) return;

    final queryParams = <String, String>{};
    if (subject != null) queryParams['subject'] = subject;
    if (body != null) queryParams['body'] = body;

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Format phone number (static for backward compatibility)
  static String formatPhoneNumber(String? phone) {
    if (phone == null) return '';
    // Simple formatting - remove non-digits and format
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  /// Launch phone call
  Future<void> launchPhoneCall(String? phone) async {
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Format Instagram handle (static for backward compatibility)
  static String formatInstagramHandle(String? handle) {
    if (handle == null) return '';
    // Remove @ if present
    return handle.startsWith('@') ? handle : '@$handle';
  }

  /// Launch Instagram
  Future<void> launchInstagram(String? handle) async {
    if (handle == null) return;
    final cleanHandle = handle.replaceAll('@', '');
    final uri = Uri.parse('https://instagram.com/$cleanHandle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Format website for display (static for backward compatibility)
  static String formatWebsiteForDisplay(String? url) {
    if (url == null) return '';
    // Remove protocol for display
    return url.replaceAll(RegExp(r'https?://'), '');
  }

  /// Launch website
  Future<void> launchWebsite(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
