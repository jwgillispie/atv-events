import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static const String _googleMapsApiKey = 'GOOGLE_MAPS_API_KEY';
  static const String _fallbackApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: 'AIzaSyDp17RxIsSydQqKZGBRsYtJkmGdwqnHZ84');
  static bool _initialized = false;

  static Future<FirebaseRemoteConfig?> get instance async {
    try {
      _remoteConfig ??= FirebaseRemoteConfig.instance;
      
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode 
          ? const Duration(minutes: 5)  // Fetch frequently in debug
          : const Duration(hours: 1),   // Cache for 1 hour in production
      ));

      // Determine environment from .env
      final environment = dotenv.env['ENVIRONMENT'] ?? 'staging';
      final isProduction = environment == 'production';
      
      
      // Set default values with environment-specific price IDs
      final defaults = <String, dynamic>{
        _googleMapsApiKey: _fallbackApiKey,
        'environment': environment,
        'stripe_publishable_key': dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '',
      };
      
      // Add environment-specific price IDs
      if (isProduction) {
        // Use live price IDs for production
        defaults['stripe_price_vendor_premium'] = dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '';
        defaults['stripe_price_market_organizer_premium'] = dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '';
        defaults['stripe_price_enterprise'] = dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '';
      } else {
        // Use test price IDs for staging/test
        defaults['stripe_price_vendor_premium'] = dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM_TEST'] ?? '';
        defaults['stripe_price_market_organizer_premium'] = dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM_TEST'] ?? '';
        defaults['stripe_price_enterprise'] = dotenv.env['STRIPE_PRICE_ENTERPRISE_TEST'] ?? '';
      }

      await _remoteConfig!.setDefaults(defaults);

      // Fetch and activate with timeout protection
      try {
        final activated = await _remoteConfig!.fetchAndActivate();
      } catch (fetchError) {
        // Continue with defaults instead of failing
      }
      
      _initialized = true;
      
      // Log loaded values for debugging
      
      return _remoteConfig!;
    } catch (e) {
      return null;
    }
  }

  static Future<String> getGoogleMapsApiKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString(_googleMapsApiKey);
        return key.isNotEmpty ? key : _fallbackApiKey;
      }
      return _fallbackApiKey;
    } catch (e) {
      return _fallbackApiKey;
    }
  }

  /// Get Stripe price ID for user type
  static Future<String> getStripePriceId(String userType) async {
    try {
      
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        String key;
        switch (userType) {
          // case 'shopper':
          //   key = 'STRIPE_PRICE_SHOPPER_PREMIUM';
          //   break;
          case 'vendor':
            key = 'STRIPE_PRICE_VENDOR_PREMIUM';
            break;
          case 'market_organizer':
            key = 'STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM';
            break;
          case 'enterprise':
            key = 'STRIPE_PRICE_ENTERPRISE';
            break;
          default:
            return '';
        }
        
        final priceId = remoteConfig.getString(key);
        
        // If Remote Config returns empty, try direct .env fallback
        if (priceId.isEmpty) {
          return _getPriceIdFromEnv(userType);
        }
        
        return priceId;
      }
      
      // Fallback to .env if Remote Config fails
      return _getPriceIdFromEnv(userType);
    } catch (e) {
      return _getPriceIdFromEnv(userType);
    }
  }

  /// Fallback to get price ID from environment variables
  static String _getPriceIdFromEnv(String userType) {
    // Determine environment to choose the right price ID
    final environment = dotenv.env['ENVIRONMENT'] ?? 'staging';
    final isProduction = environment == 'production';
    
    
    switch (userType) {
      // case 'shopper':
      //   return isProduction 
      //     ? (dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM'] ?? '')
      //     : (dotenv.env['STRIPE_PRICE_SHOPPER_PREMIUM_TEST'] ?? '');
      case 'vendor':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM'] ?? '')
          : (dotenv.env['STRIPE_PRICE_VENDOR_PREMIUM_TEST'] ?? '');
        return priceId;
      case 'market_organizer':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM'] ?? '')
          : (dotenv.env['STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM_TEST'] ?? '');
        return priceId;
      case 'enterprise':
        final priceId = isProduction 
          ? (dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? '')
          : (dotenv.env['STRIPE_PRICE_ENTERPRISE_TEST'] ?? '');
        return priceId;
      default:
        return '';
    }
  }

  /// Get Stripe publishable key
  static Future<String> getStripePublishableKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('STRIPE_PUBLISHABLE_KEY');
        if (key.isNotEmpty) return key;
      }
      // Fallback to .env
      return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    } catch (e) {
      return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    }
  }

  /// Debug method to print all Remote Config values
  static Future<void> debugConfiguration() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        
        // Check Stripe price IDs
        final vendorPrice = remoteConfig.getString('STRIPE_PRICE_VENDOR_PREMIUM');
        final marketOrgPrice = remoteConfig.getString('STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM');
        final enterprisePrice = remoteConfig.getString('STRIPE_PRICE_ENTERPRISE');
        final publishableKey = remoteConfig.getString('STRIPE_PUBLISHABLE_KEY');
        
        
        final testVendor = await getStripePriceId('vendor');
        final testMarketOrg = await getStripePriceId('market_organizer');
      } else {
      }
    } catch (e) {
    }
  }
  
  /// Get Apple Shared Secret Key
  static Future<String> getAppleSharedSecretKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('APPLE_SHARED_SECRET_KEY');
        if (key.isNotEmpty) {
          return key;
        }
      }
      // Fallback to .env
      return dotenv.env['APPLE_SHARED_SECRET_KEY'] ?? '';
    } catch (e) {
      return dotenv.env['APPLE_SHARED_SECRET_KEY'] ?? '';
    }
  }

  /// Get RevenueCat API Key
  static Future<String> getRevenueCatApiKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('REVENUE_CAT_API_KEY');
        if (key.isNotEmpty) {
          return key;
        }
      }
      // Fallback to .env
      return dotenv.env['REVENUE_CAT_API_KEY'] ?? '';
    } catch (e) {
      return dotenv.env['REVENUE_CAT_API_KEY'] ?? '';
    }
  }

  /// Get RevenueCat App ID
  static Future<String> getRevenueCatAppId() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('REVENUE_CAT_APP_ID');
        if (key.isNotEmpty) {
          return key;
        }
      }
      // Fallback to .env
      return dotenv.env['REVENUE_CAT_APP_ID'] ?? '';
    } catch (e) {
      return dotenv.env['REVENUE_CAT_APP_ID'] ?? '';
    }
  }

  /// Get RevenueCat Secret Key
  static Future<String> getRevenueCatSecretKey() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('REVENUE_CAT_SECRET_KEY');
        if (key.isNotEmpty) {
          return key;
        }
      }
      // Fallback to .env
      return dotenv.env['REVENUE_CAT_SECRET_KEY'] ?? '';
    } catch (e) {
      return dotenv.env['REVENUE_CAT_SECRET_KEY'] ?? '';
    }
  }

  /// Get RevenueCat Entitlement ID
  static Future<String> getRevenueCatEntitlementId() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('REVENUE_CAT_ENTITLEMENT_ID');
        if (key.isNotEmpty) {
          return key;
        }
      }
      // Fallback to .env
      return dotenv.env['REVENUE_CAT_ENTITLEMENT_ID'] ?? '';
    } catch (e) {
      return dotenv.env['REVENUE_CAT_ENTITLEMENT_ID'] ?? '';
    }
  }

  /// Get RevenueCat Vendor Offering ID
  static Future<String> getRevenueCatVendorOfferingId() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('REVENUE_CAT_VENDOR_OFFERING_ID');
        if (key.isNotEmpty) {
          return key;
        }
      }
      // Fallback to .env
      return dotenv.env['REVENUE_CAT_VENDOR_OFFERING_ID'] ?? '';
    } catch (e) {
      return dotenv.env['REVENUE_CAT_VENDOR_OFFERING_ID'] ?? '';
    }
  }

  /// Get RevenueCat Organizer Offering ID
  static Future<String> getRevenueCatOrganizerOfferingId() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final key = remoteConfig.getString('REVENUE_CAT_ORGANIZER_OFFERING_ID');
        if (key.isNotEmpty) {
          return key;
        }
      }
      // Fallback to .env
      return dotenv.env['REVENUE_CAT_ORGANIZER_OFFERING_ID'] ?? '';
    } catch (e) {
      return dotenv.env['REVENUE_CAT_ORGANIZER_OFFERING_ID'] ?? '';
    }
  }

  /// Force refresh Remote Config values
  static Future<void> refresh() async {
    try {
      final remoteConfig = await instance;
      if (remoteConfig != null) {
        final activated = await remoteConfig.fetchAndActivate();
        if (activated) {
        }
      }
    } catch (e) {
    }
  }
  
  /// Debug method to test all RevenueCat Remote Config values
  static Future<void> debugRevenueCatConfiguration() async {
    
    try {
      final apiKey = await getRevenueCatApiKey();
      final entitlementId = await getRevenueCatEntitlementId();
      final vendorOfferingId = await getRevenueCatVendorOfferingId();
      final organizerOfferingId = await getRevenueCatOrganizerOfferingId();
      final appId = await getRevenueCatAppId();
      final secretKey = await getRevenueCatSecretKey();
      final appleSecret = await getAppleSharedSecretKey();
      
      
    } catch (e) {
    }
  }
}