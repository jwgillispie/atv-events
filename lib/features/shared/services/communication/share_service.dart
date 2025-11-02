import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:atv_events/features/shared/models/event.dart';
import 'package:atv_events/features/market/models/market.dart';

/// Service for handling different types of content sharing
class ShareService {
  static const String _appName = 'ATV Events';
  static const String _appTagline = 'Discover local pop-ups and markets';
  static const String _appWebsite = 'https://atv-events.web.app';
  
  /// Share a vendor popup event
  static Future<ShareResult> sharePopup(VendorPost popup, {String? marketName}) async {
    try {
      final content = _buildPopupContent(popup, marketName);
      return await Share.share(
        content,
        subject: 'Check out this pop-up on ATV Events!',
      );
    } catch (e) {
      return ShareResult('', ShareResultStatus.unavailable);
    }
  }

  /// Share an event
  static Future<ShareResult> shareEvent(Event event) async {
    try {
      final content = _buildEventContent(event);
      return await Share.share(
        content,
        subject: 'Check out this event on ATV Events!',
      );
    } catch (e) {
      return ShareResult('', ShareResultStatus.unavailable);
    }
  }

  /// Share a market
  static Future<ShareResult> shareMarket(Market market) async {
    try {
      final content = _buildMarketContent(market);
      return await Share.share(
        content,
        subject: 'Check out this market on ATV Events!',
      );
    } catch (e) {
      return ShareResult('', ShareResultStatus.unavailable);
    }
  }

  /// Share the app itself for promotional purposes
  static Future<ShareResult> shareApp() async {
    try {
      const content = '''Discover amazing local pop-ups and farmers markets with $_appName!

$_appTagline

Connect with local vendors, find fresh produce, unique crafts, and delicious food in your area.

Download $_appName: $_appWebsite

#LocalBusiness #PopUps #FarmersMarkets #SupportLocal #$_appName
      ''';
      
      return await Share.share(
        content,
        subject: 'Check out the $_appName app!',
      );
    } catch (e) {
      return ShareResult('', ShareResultStatus.unavailable);
    }
  }

  /// Share text to clipboard as fallback
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  // Private methods for building content

  static String _buildPopupContent(VendorPost popup, String? marketName) {
    final buffer = StringBuffer();
    
    // Emoji and title
    buffer.writeln('Pop-up Alert!');
    buffer.writeln();
    
    // Vendor and description
    buffer.writeln(popup.vendorName);
    buffer.writeln(popup.description);
    buffer.writeln();
    
    // Location
    buffer.writeln('Location: ${popup.location}');
    if (marketName != null && marketName.isNotEmpty) {
      buffer.writeln('At: $marketName');
    }
    buffer.writeln();
    
    // Date and time
    buffer.writeln('When: ${_formatDateTime(popup.popUpStartDateTime, popup.popUpEndDateTime)}');
    buffer.writeln();
    
    // Status
    if (popup.isHappening) {
      buffer.writeln('HAPPENING NOW!');
    } else if (popup.isUpcoming) {
      buffer.writeln('Coming up soon!');
    }
    buffer.writeln();
    
    // Instagram handle if available
    if (popup.instagramHandle != null && popup.instagramHandle!.isNotEmpty) {
      buffer.writeln('Follow: ${popup.instagramHandle!.startsWith('@') ? popup.instagramHandle : '@${popup.instagramHandle}'}');
      buffer.writeln();
    }
    
    // App promotion
    buffer.writeln('Discovered on $_appName - $_appTagline');
    buffer.writeln('Download: $_appWebsite');
    buffer.writeln();
    
    // Hashtags
    buffer.writeln('#PopUp #LocalBusiness #${popup.location.replaceAll(' ', '')} #SupportLocal #$_appName');
    
    return buffer.toString();
  }

  static String _buildEventContent(Event event) {
    final buffer = StringBuffer();
    
    buffer.writeln('Event Alert!');
    buffer.writeln();
    buffer.writeln(event.name);
    if (event.description.isNotEmpty) {
      buffer.writeln(event.description);
    }
    buffer.writeln();
    buffer.writeln('Location: ${event.location}');
    buffer.writeln('When: ${_formatDateTime(event.startDateTime, event.endDateTime)}');
    buffer.writeln();
    buffer.writeln('Discovered on $_appName - $_appTagline');
    buffer.writeln('Download: $_appWebsite');
    buffer.writeln();
    buffer.writeln('#Event #LocalEvents #${event.location.replaceAll(' ', '')} #$_appName');
    
    return buffer.toString();
  }

  static String _buildMarketContent(Market market) {
    final buffer = StringBuffer();
    
    buffer.writeln('Market Discovery!');
    buffer.writeln();
    buffer.writeln(market.name);
    if (market.description != null && market.description!.isNotEmpty) {
      buffer.writeln(market.description);
    }
    buffer.writeln();
    buffer.writeln('Location: ${market.address}');
    buffer.writeln();
    
    // Add schedule information if available
    buffer.writeln('Visit this amazing local market!');
    buffer.writeln();
    
    buffer.writeln('Discovered on $_appName - $_appTagline');
    buffer.writeln('Download: $_appWebsite');
    buffer.writeln();
    buffer.writeln('#FarmersMarket #LocalMarket #${market.address.replaceAll(' ', '')} #SupportLocal #$_appName');
    
    return buffer.toString();
  }

  // Date formatting helpers

  static String _formatDateTime(DateTime start, DateTime end) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    String formatDate(DateTime date) {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    
    String formatTime(DateTime time) {
      final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
      final minute = time.minute.toString().padLeft(2, '0');
      final ampm = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    }
    
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      // Same day
      return '${formatDate(start)} • ${formatTime(start)} - ${formatTime(end)}';
    } else {
      // Multi-day
      return '${formatDate(start)} ${formatTime(start)} - ${formatDate(end)} ${formatTime(end)}';
    }
  }


  /// Get a user-friendly error message for share result status
  static String getShareErrorMessage(ShareResultStatus status) {
    switch (status) {
      case ShareResultStatus.success:
        return 'Successfully shared!';
      case ShareResultStatus.dismissed:
        return 'Share cancelled';
      case ShareResultStatus.unavailable:
        return 'Sharing is not available on this device';
    }
  }

  /// Check if sharing is available on the current platform
  static bool isShareAvailable() {
    // share_plus generally works on all platforms, but we can add platform-specific checks if needed
    return true;
  }
}