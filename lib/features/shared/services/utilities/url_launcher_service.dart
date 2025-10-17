import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional import for web-only features
import 'url_launcher_web_stub.dart' 
  if (dart.library.html) 'url_launcher_web_impl.dart' as web_launcher;

class UrlLauncherService {
  /// Launch Instagram profile
  static Future<void> launchInstagram(String handle) async {
    final cleanHandle = handle.startsWith('@') ? handle.substring(1) : handle;
    final url = 'https://instagram.com/$cleanHandle';
    await _launchUrl(url);
  }
  
  /// Launch address in maps app with choice between Apple Maps and Google Maps on iOS
  static Future<void> launchMaps(String address, {BuildContext? context}) async {
    final encodedAddress = Uri.encodeComponent(address);
    
    // On iOS, give user choice between Apple Maps and Google Maps
    if (!kIsWeb && Platform.isIOS && context != null) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Open with',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.map,
                      color: Colors.black87,
                      size: 28,
                    ),
                  ),
                  title: const Text('Apple Maps'),
                  subtitle: const Text('Get directions with Apple Maps'),
                  onTap: () async {
                    Navigator.pop(context);
                    final appleMapsUrl = 'maps://maps.apple.com/?q=$encodedAddress';
                    await _launchUrl(appleMapsUrl);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.blue[600],
                      size: 28,
                    ),
                  ),
                  title: const Text('Google Maps'),
                  subtitle: const Text('Get directions with Google Maps'),
                  onTap: () async {
                    Navigator.pop(context);
                    final googleMapsUrl = 'https://maps.google.com/?q=$encodedAddress';
                    await _launchUrl(googleMapsUrl);
                  },
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // For Android and Web, default to Google Maps
      final url = 'https://maps.google.com/?q=$encodedAddress';
      await _launchUrl(url);
    }
  }
  
  /// Launch website URL
  static Future<void> launchWebsite(String url) async {
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    await _launchUrl(finalUrl);
  }
  
  /// Launch email
  static Future<void> launchEmail(String email) async {
    final url = 'mailto:$email';
    await _launchUrl(url);
  }
  
  /// Launch phone number
  static Future<void> launchPhone(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    await _launchUrl(url);
  }
  
  /// Internal method to launch URL with error handling
  static Future<void> _launchUrl(String url) async {
    try {
      if (kIsWeb) {
        // For Flutter Web, use web-specific implementation
        web_launcher.openUrl(url);
        return;
      }
      
      // For mobile platforms
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot launch URL: $url');
      }
    } catch (e) {
      throw Exception('Cannot open link: $url');
    }
  }
}