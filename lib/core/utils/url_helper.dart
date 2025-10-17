import 'package:flutter/foundation.dart';

/// Helper class for consistent URL construction across the app
class UrlHelper {
  /// Creates success and cancel URLs for Stripe checkout flows
  static (String success, String cancel) getCheckoutUrls(
    String path,
    Map<String, String> params,
  ) {
    final query = Uri(queryParameters: params).query;

    if (kIsWeb) {
      return (
        '${Uri.base.origin}/#/$path/success${query.isNotEmpty ? "?$query" : ""}',
        '${Uri.base.origin}/#/$path/cancel',
      );
    } else {
      return (
        'hipop://$path/success${query.isNotEmpty ? "?$query" : ""}',
        'hipop://$path/cancel',
      );
    }
  }

  /// Creates a single callback URL for various flows
  static String getCallbackUrl(String path, {Map<String, String>? params}) {
    final query = params != null ? Uri(queryParameters: params).query : '';

    if (kIsWeb) {
      return '${Uri.base.origin}/#/$path${query.isNotEmpty ? "?$query" : ""}';
    } else {
      return 'hipop://$path${query.isNotEmpty ? "?$query" : ""}';
    }
  }

  /// Creates a return URL for payment flows
  static String getReturnUrl(String path) {
    return kIsWeb
      ? '${Uri.base.origin}/#/$path'
      : 'hipop://$path';
  }
}