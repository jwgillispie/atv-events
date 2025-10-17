import 'package:atv_events/features/market/models/market.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/features/vendor/models/vendor_market_relationship.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailService {
  static const String _supportEmail = 'hipopmarkets@gmail.com';

  /// Send vendor invitation email
  static Future<void> sendVendorInvitation({
    required VendorMarketRelationship relationship,
    required Market market,
    String? customMessage,
  }) async {
    try {
      if (relationship.invitationEmail == null || relationship.invitationEmail!.isEmpty) {
        throw Exception('Invitation email is required');
      }

      // Get market organizer information
      String organizerName = 'Market Organizer';
      if (relationship.createdBy.isNotEmpty) {
        try {
          final organizer = await UserProfileService().getUserProfile(relationship.createdBy);
          if (organizer?.displayName?.isNotEmpty == true) {
            organizerName = organizer!.displayName!;
          } else if (organizer?.businessName?.isNotEmpty == true) {
            organizerName = organizer!.businessName!;
          }
        } catch (e) {
        }
      }

      final emailContent = _buildInvitationEmailContent(
        relationship: relationship,
        market: market,
        organizerName: organizerName,
        customMessage: customMessage,
      );

      // For now, log the email content since we don't have SMTP configured

      // TODO: Integrate with actual email service (SendGrid, AWS SES, etc.)
      // This would be replaced with actual email sending logic:
      // await _sendEmailViaProvider(
      //   to: relationship.invitationEmail!,
      //   subject: 'Invitation to Join ${market.name}',
      //   content: emailContent,
      // );

    } catch (e) {
      rethrow;
    }
  }

  /// Build invitation email content
  static String _buildInvitationEmailContent({
    required VendorMarketRelationship relationship,
    required Market market,
    required String organizerName,
    String? customMessage,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Subject: You\'re Invited to Join ${market.name}!');
    buffer.writeln();
    buffer.writeln('Hello,');
    buffer.writeln();
    buffer.writeln('We\'d like to invite you to join ${market.name} as a vendor on the HiPop platform!');
    buffer.writeln();
    buffer.writeln('Market Details:');
    buffer.writeln(market.name);
    buffer.writeln('Location: ${market.address}, ${market.city}, ${market.state}');
    
    if (market.description != null && market.description!.isNotEmpty) {
      buffer.writeln('About: ${market.description}');
    }
    buffer.writeln();

    // Add event schedule
    buffer.writeln('🗓️ Event Schedule:');
    buffer.writeln('  Date: ${market.eventDisplayInfo}');
    buffer.writeln('  Time: ${market.timeRange}');
    buffer.writeln();

    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln('Personal Message from $organizerName:');
      buffer.writeln('"$customMessage"');
      buffer.writeln();
    }

    if (relationship.invitationToken != null) {
      buffer.writeln('To accept this invitation, please:');
      buffer.writeln('1. Download the HiPop app: https://hipop-markets.web.app');
      buffer.writeln('2. Create or log into your vendor account');
      buffer.writeln('3. Use invitation code: ${relationship.invitationToken}');
      buffer.writeln();
    } else {
      buffer.writeln('To get started:');
      buffer.writeln('1. Download the HiPop app: https://hipop-markets.web.app');
      buffer.writeln('2. Create a vendor account');
      buffer.writeln('3. Apply to join ${market.name}');
      buffer.writeln();
    }

    buffer.writeln('Why join HiPop?');
    buffer.writeln('• Connect with local customers');
    buffer.writeln('• Manage your pop-up events easily');
    buffer.writeln('• Get discovered by food lovers in your area');
    buffer.writeln('• Build your local business community');
    buffer.writeln();

    buffer.writeln('Questions? Contact us at $_supportEmail');
    buffer.writeln();
    buffer.writeln('Welcome to the HiPop community!');
    buffer.writeln('The HiPop Team');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('HiPop - Discover Local Pop-ups and Markets');
    buffer.writeln('This invitation was sent by $organizerName on behalf of ${market.name}.');

    return buffer.toString();
  }




  /// Send general support email notification
  static Future<void> sendSupportNotification({
    required String subject,
    required String message,
    String? userEmail,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final emailContent = _buildSupportEmailContent(
        subject: subject,
        message: message,
        userEmail: userEmail,
        metadata: metadata,
      );


      // Create mailto URI with proper encoding
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: Uri.encodeFull(
          'subject=[HiPop Support] $subject&body=$emailContent',
        ),
      );

      // Open the user's email client
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        // Fallback: try with a simpler URI
        final fallbackUri = Uri.parse('mailto:$_supportEmail?subject=[HiPop Support] $subject');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          throw Exception('Could not open email client. Please email us directly at $_supportEmail');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Build support email content
  static String _buildSupportEmailContent({
    required String subject,
    required String message,
    String? userEmail,
    Map<String, dynamic>? metadata,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Support Request: $subject');
    buffer.writeln();
    
    if (userEmail != null && userEmail.isNotEmpty) {
      buffer.writeln('From: $userEmail');
      buffer.writeln();
    }

    buffer.writeln('Message:');
    buffer.writeln(message);
    buffer.writeln();

    if (metadata != null && metadata.isNotEmpty) {
      buffer.writeln('Additional Information:');
      metadata.forEach((key, value) {
        buffer.writeln('$key: $value');
      });
      buffer.writeln();
    }

    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');

    return buffer.toString();
  }

  /// Send market application notification
  static Future<void> sendMarketApplicationNotification({
    required String marketName,
    required String vendorName,
    required String vendorEmail,
    required String marketOrganizerId,
  }) async {
    try {
      // Get market organizer email
      String organizerEmail = _supportEmail; // Fallback to support email
      try {
        final organizer = await UserProfileService().getUserProfile(marketOrganizerId);
        if (organizer?.email != null && organizer!.email.isNotEmpty) {
          organizerEmail = organizer.email;
        }
      } catch (e) {
      }

      final emailContent = _buildApplicationNotificationContent(
        marketName: marketName,
        vendorName: vendorName,
        vendorEmail: vendorEmail,
      );


      // TODO: Integrate with actual email service
    } catch (e) {
      rethrow;
    }
  }

  /// Build application notification content
  static String _buildApplicationNotificationContent({
    required String marketName,
    required String vendorName,
    required String vendorEmail,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('New Vendor Application for $marketName');
    buffer.writeln();
    buffer.writeln('A new vendor has applied to join your market!');
    buffer.writeln();
    buffer.writeln('Vendor Details:');
    buffer.writeln('Name: $vendorName');
    buffer.writeln('Email: $vendorEmail');
    buffer.writeln('Market: $marketName');
    buffer.writeln();
    buffer.writeln('Please log into the HiPop app to review this application.');
    buffer.writeln();
    buffer.writeln('The HiPop Team');
    buffer.writeln('Contact: $_supportEmail');

    return buffer.toString();
  }

  /// Open email client to contact support directly
  /// This is a simpler method for support buttons throughout the app
  static Future<void> contactSupport({
    String? subject,
    String? body,
  }) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: Uri.encodeFull([
          if (subject != null) 'subject=$subject',
          if (body != null) 'body=$body',
        ].join('&')),
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        // Try simpler fallback
        final fallbackUri = Uri.parse('mailto:$_supportEmail');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          throw Exception('Could not open email client. Please email $_supportEmail');
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}