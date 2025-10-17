import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive metrics aggregation service for CEO dashboard
class CEOMetricsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get comprehensive platform metrics
  static Future<Map<String, dynamic>> getPlatformMetrics() async {
    try {
      final results = await Future.wait([
        _getUserMetrics(),
        _getVendorMetrics(),
        _getMarketMetrics(),
        _getEngagementMetrics(),
        _getRevenueMetrics(),
        _getActivityMetrics(),
        _getErrorMetrics(),
        _getContentMetrics(),
        _getProductMetrics(),
        _getTicketMetrics(),
        _getTransactionMetrics(),
        _getKeyPerformanceIndicators(),
      ]);

      return {
        'users': results[0],
        'vendors': results[1],
        'markets': results[2],
        'engagement': results[3],
        'revenue': results[4],
        'activity': results[5],
        'errors': results[6],
        'content': results[7],
        'products': results[8],
        'tickets': results[9],
        'transactions': results[10],
        'kpis': results[11],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// User metrics - total users, by type, new users, active users
  static Future<Map<String, dynamic>> _getUserMetrics() async {
    try {
      // Get all user profiles
      final userProfilesSnapshot = await _firestore.collection('user_profiles').get();
      
      int totalUsers = userProfilesSnapshot.docs.length;
      int vendorUsers = 0;
      int organizerUsers = 0;
      int shopperUsers = 0;
      int verifiedUsers = 0;
      int premiumUsers = 0;
      
      // Today's metrics
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));
      
      int todayNewUsers = 0;
      int weekNewUsers = 0;
      int monthNewUsers = 0;
      int activeToday = 0;
      int activeWeek = 0;
      int activeMonth = 0;
      
      for (final doc in userProfilesSnapshot.docs) {
        final data = doc.data();
        final userType = data['userType'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final lastActive = (data['lastActive'] as Timestamp?)?.toDate();
        final isVerified = data['isVerified'] as bool? ?? false;
        final isPremium = data['isPremium'] as bool? ?? false;
        
        // Count by user type
        if (userType == 'vendor') {
          vendorUsers++;
        } else if (userType == 'market_organizer') organizerUsers++;
        else if (userType == 'shopper') shopperUsers++;
        
        if (isVerified) verifiedUsers++;
        if (isPremium) premiumUsers++;
        
        // New user counts
        if (createdAt != null) {
          if (createdAt.isAfter(todayStart)) todayNewUsers++;
          if (createdAt.isAfter(weekAgo)) weekNewUsers++;
          if (createdAt.isAfter(monthAgo)) monthNewUsers++;
        }
        
        // Active user counts
        if (lastActive != null) {
          if (lastActive.isAfter(todayStart)) activeToday++;
          if (lastActive.isAfter(weekAgo)) activeWeek++;
          if (lastActive.isAfter(monthAgo)) activeMonth++;
        }
      }
      
      // Get subscription breakdown
      final subscriptionsSnapshot = await _firestore.collection('user_subscriptions')
          .where('status', isEqualTo: 'active')
          .get();
      
      int vendorBasic = 0;
      int vendorGrowth = 0;
      int vendorPremium = 0;
      int organizerBasic = 0;
      int organizerPro = 0;
      int shopperPremium = 0;
      
      for (final doc in subscriptionsSnapshot.docs) {
        final tier = doc.data()['tier'] as String?;
        switch (tier) {
          case 'vendor_basic':
            vendorBasic++;
            break;
          case 'vendor_growth':
            vendorGrowth++;
            break;
          case 'vendor_pro':
            vendorPremium++;
            break;
          case 'organizer_basic':
            organizerBasic++;
            break;
          case 'organizer_pro':
            organizerPro++;
            break;
          case 'shopper_premium':
            shopperPremium++;
            break;
        }
      }
      
      return {
        'total': totalUsers,
        'byType': {
          'vendors': vendorUsers,
          'organizers': organizerUsers,
          'shoppers': shopperUsers,
        },
        'verified': verifiedUsers,
        'premium': premiumUsers,
        'newUsers': {
          'today': todayNewUsers,
          'week': weekNewUsers,
          'month': monthNewUsers,
        },
        'activeUsers': {
          'today': activeToday,
          'week': activeWeek,
          'month': activeMonth,
        },
        'subscriptions': {
          'vendorBasic': vendorBasic,
          'vendorGrowth': vendorGrowth,
          'vendorPremium': vendorPremium,
          'organizerBasic': organizerBasic,
          'organizerPro': organizerPro,
          'shopperPremium': shopperPremium,
          'totalActive': subscriptionsSnapshot.docs.length,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Vendor-specific metrics
  static Future<Map<String, dynamic>> _getVendorMetrics() async {
    try {
      final vendorsSnapshot = await _firestore.collection('managed_vendors').get();
      final vendorAppsSnapshot = await _firestore.collection('vendor_applications').get();
      final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();
      
      // Count by status
      int activeVendors = 0;
      int featuredVendors = 0;
      int organicVendors = 0;
      
      for (final doc in vendorsSnapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == true) activeVendors++;
        if (data['isFeatured'] == true) featuredVendors++;
        if (data['isOrganic'] == true) organicVendors++;
      }
      
      // Application metrics
      int pendingApps = 0;
      int approvedApps = 0;
      int rejectedApps = 0;
      
      for (final doc in vendorAppsSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'pending') {
          pendingApps++;
        } else if (status == 'approved') approvedApps++;
        else if (status == 'rejected') rejectedApps++;
      }
      
      return {
        'total': vendorsSnapshot.docs.length,
        'active': activeVendors,
        'featured': featuredVendors,
        'organic': organicVendors,
        'applications': {
          'total': vendorAppsSnapshot.docs.length,
          'pending': pendingApps,
          'approved': approvedApps,
          'rejected': rejectedApps,
        },
        'posts': vendorPostsSnapshot.docs.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Market metrics
  static Future<Map<String, dynamic>> _getMarketMetrics() async {
    try {
      final marketsSnapshot = await _firestore.collection('markets').get();
      final eventsSnapshot = await _firestore.collection('events').get();
      
      int activeMarkets = 0;
      int upcomingMarkets = 0;
      int pastMarkets = 0;
      int recruitingMarkets = 0;
      
      final now = DateTime.now();
      
      for (final doc in marketsSnapshot.docs) {
        final data = doc.data();
        final eventDate = (data['eventDate'] as Timestamp?)?.toDate();
        final isActive = data['isActive'] as bool? ?? false;
        final isLookingForVendors = data['isLookingForVendors'] as bool? ?? false;
        
        if (isActive) activeMarkets++;
        if (isLookingForVendors) recruitingMarkets++;
        
        if (eventDate != null) {
          if (eventDate.isAfter(now)) {
            upcomingMarkets++;
          } else {
            pastMarkets++;
          }
        }
      }
      
      return {
        'total': marketsSnapshot.docs.length,
        'active': activeMarkets,
        'upcoming': upcomingMarkets,
        'past': pastMarkets,
        'recruiting': recruitingMarkets,
        'events': eventsSnapshot.docs.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Engagement metrics - favorites, shares, views
  static Future<Map<String, dynamic>> _getEngagementMetrics() async {
    try {
      // Favorites
      final favoritesSnapshot = await _firestore.collection('user_favorites').get();
      
      int vendorFavorites = 0;
      int marketFavorites = 0;
      int eventFavorites = 0;
      
      for (final doc in favoritesSnapshot.docs) {
        final type = doc.data()['type'] as String?;
        if (type == 'vendor') {
          vendorFavorites++;
        } else if (type == 'market') marketFavorites++;
        else if (type == 'event') eventFavorites++;
      }
      
      // Analytics events
      final analyticsSnapshot = await _firestore.collection('analytics').get();
      
      int totalViews = 0;
      int totalShares = 0;
      int profileViews = 0;
      int marketViews = 0;
      int vendorInteractions = 0;
      
      for (final doc in analyticsSnapshot.docs) {
        final data = doc.data();
        final eventType = data['eventType'] as String?;
        final count = data['count'] as int? ?? 1;
        
        if (eventType?.contains('view') == true) {
          totalViews += count;
          if (eventType?.contains('profile') == true) profileViews += count;
          if (eventType?.contains('market') == true) marketViews += count;
        }
        if (eventType?.contains('share') == true) totalShares += count;
        if (eventType?.contains('vendor') == true) vendorInteractions += count;
      }
      
      // User sessions
      final sessionsSnapshot = await _firestore.collection('user_sessions').get();
      
      return {
        'favorites': {
          'total': favoritesSnapshot.docs.length,
          'vendors': vendorFavorites,
          'markets': marketFavorites,
          'events': eventFavorites,
        },
        'views': {
          'total': totalViews,
          'profiles': profileViews,
          'markets': marketViews,
        },
        'shares': totalShares,
        'interactions': vendorInteractions,
        'sessions': sessionsSnapshot.docs.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Revenue metrics
  static Future<Map<String, dynamic>> _getRevenueMetrics() async {
    try {
      final subscriptionsSnapshot = await _firestore.collection('user_subscriptions')
          .where('status', isEqualTo: 'active')
          .get();

      double monthlyRecurring = 0;
      double annualRecurring = 0;

      // Calculate MRR and ARR
      for (final doc in subscriptionsSnapshot.docs) {
        final data = doc.data();
        final tier = data['tier'] as String?;
        final interval = data['interval'] as String?;

        // Define pricing (you should adjust these to match your actual pricing)
        double monthlyPrice = 0;
        switch (tier) {
          case 'vendor_basic':
            monthlyPrice = 19.99;
            break;
          case 'vendor_growth':
            monthlyPrice = 49.99;
            break;
          case 'vendor_pro':
            monthlyPrice = 99.99;
            break;
          case 'organizer_basic':
            monthlyPrice = 29.99;
            break;
          case 'organizer_pro':
            monthlyPrice = 79.99;
            break;
          case 'shopper_premium':
            monthlyPrice = 9.99;
            break;
        }

        if (interval == 'month') {
          monthlyRecurring += monthlyPrice;
        } else if (interval == 'year') {
          monthlyRecurring += (monthlyPrice * 12) / 12; // Convert annual to monthly
        }
      }

      annualRecurring = monthlyRecurring * 12;

      // Get order revenue (actual transactions)
      final ordersSnapshot = await _firestore.collection('orders').get();

      double totalRevenue = 0;
      double todayRevenue = 0;
      double weekRevenue = 0;
      double monthRevenue = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final status = data['status'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Only count successful orders
        if (status == 'paid' || status == 'confirmed' || status == 'preparing' ||
            status == 'ready_for_pickup' || status == 'picked_up') {
          totalRevenue += total;

          if (createdAt != null) {
            if (createdAt.isAfter(todayStart)) todayRevenue += total;
            if (createdAt.isAfter(weekAgo)) weekRevenue += total;
            if (createdAt.isAfter(monthAgo)) monthRevenue += total;
          }
        }
      }

      return {
        'mrr': monthlyRecurring,
        'arr': annualRecurring,
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
        'weekRevenue': weekRevenue,
        'monthRevenue': monthRevenue,
        'activeSubscriptions': subscriptionsSnapshot.docs.length,
        'averageRevenue': subscriptionsSnapshot.docs.isNotEmpty
            ? monthlyRecurring / subscriptionsSnapshot.docs.length
            : 0,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// User activity metrics
  static Future<Map<String, dynamic>> _getActivityMetrics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final hourAgo = now.subtract(const Duration(hours: 1));
      
      // Get recent user events
      final userEventsSnapshot = await _firestore.collection('user_events')
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get();
      
      int todayEvents = 0;
      int hourEvents = 0;
      Map<String, int> eventTypes = {};
      
      for (final doc in userEventsSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        final eventType = data['eventType'] as String? ?? 'unknown';
        
        eventTypes[eventType] = (eventTypes[eventType] ?? 0) + 1;
        
        if (timestamp != null) {
          if (timestamp.isAfter(todayStart)) todayEvents++;
          if (timestamp.isAfter(hourAgo)) hourEvents++;
        }
      }
      
      // Get user feedback
      final feedbackSnapshot = await _firestore.collection('user_feedback').get();
      
      int positiveFeedback = 0;
      int negativeFeedback = 0;
      int neutralFeedback = 0;
      
      for (final doc in feedbackSnapshot.docs) {
        final rating = doc.data()['rating'] as int?;
        if (rating != null) {
          if (rating >= 4) {
            positiveFeedback++;
          } else if (rating <= 2) negativeFeedback++;
          else neutralFeedback++;
        }
      }
      
      return {
        'todayEvents': todayEvents,
        'lastHourEvents': hourEvents,
        'totalEvents': userEventsSnapshot.docs.length,
        'eventTypes': eventTypes,
        'feedback': {
          'total': feedbackSnapshot.docs.length,
          'positive': positiveFeedback,
          'negative': negativeFeedback,
          'neutral': neutralFeedback,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Error and system health metrics
  static Future<Map<String, dynamic>> _getErrorMetrics() async {
    try {
      // System alerts
      final alertsSnapshot = await _firestore.collection('system_alerts')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      int criticalErrors = 0;
      int warnings = 0;
      int info = 0;
      List<Map<String, dynamic>> recentErrors = [];
      
      for (final doc in alertsSnapshot.docs) {
        final data = doc.data();
        final severity = data['severity'] as String?;
        
        if (severity == 'critical') {
          criticalErrors++;
        } else if (severity == 'warning') warnings++;
        else info++;
        
        if (recentErrors.length < 10) {
          recentErrors.add({
            'message': data['message'],
            'severity': severity,
            'timestamp': (data['timestamp'] as Timestamp?)?.toDate().toIso8601String(),
          });
        }
      }
      
      // Debug logs
      final debugLogsSnapshot = await _firestore.collection('debug_logs').get();
      
      // Performance metrics
      final performanceSnapshot = await _firestore.collection('performance_metrics')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      Map<String, dynamic> latestPerformance = {};
      if (performanceSnapshot.docs.isNotEmpty) {
        latestPerformance = performanceSnapshot.docs.first.data();
      }
      
      return {
        'alerts': {
          'total': alertsSnapshot.docs.length,
          'critical': criticalErrors,
          'warnings': warnings,
          'info': info,
        },
        'debugLogs': debugLogsSnapshot.docs.length,
        'recentErrors': recentErrors,
        'performance': latestPerformance,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Content metrics - posts, products, etc.
  static Future<Map<String, dynamic>> _getContentMetrics() async {
    try {
      // Vendor posts
      final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();
      
      int activePosts = 0;
      int expiredPosts = 0;
      final now = DateTime.now();
      
      for (final doc in vendorPostsSnapshot.docs) {
        final expiresAt = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
        if (expiresAt != null) {
          if (expiresAt.isAfter(now)) {
            activePosts++;
          } else {
            expiredPosts++;
          }
        }
      }
      
      // Vendor products
      final vendorProductsSnapshot = await _firestore.collection('vendor_product_lists').get();
      
      // Market items
      final marketItemsSnapshot = await _firestore.collection('vendor_market_items').get();
      
      return {
        'vendorPosts': {
          'total': vendorPostsSnapshot.docs.length,
          'active': activePosts,
          'expired': expiredPosts,
        },
        'products': vendorProductsSnapshot.docs.length,
        'marketItems': marketItemsSnapshot.docs.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get real-time activity stream
  static Stream<List<Map<String, dynamic>>> getActivityStream() {
    return _firestore
        .collection('user_events')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'],
          'userEmail': data['userEmail'],
          'eventType': data['eventType'],
          'details': data['details'],
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate().toIso8601String(),
        };
      }).toList();
    });
  }

  /// Product metrics - listings, categories, views, conversions
  static Future<Map<String, dynamic>> _getProductMetrics() async {
    try {
      // Get all products from products collection
      final productsSnapshot = await _firestore.collection('products').get();

      // Get vendor posts (popups) with products
      final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();

      // Get product interactions from analytics
      final analyticsSnapshot = await _firestore.collection('analytics')
          .where('eventType', whereIn: ['product_view', 'product_interaction', 'product_purchase'])
          .get();

      int totalProducts = productsSnapshot.docs.length;
      int activeProducts = 0;
      int featuredProducts = 0;
      Map<String, int> productsByCategory = {};
      double totalPrice = 0;
      int productViews = 0;
      int productInteractions = 0;
      int productPurchases = 0;
      Map<String, int> topSellingProducts = {};

      // Analyze products
      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        final isActive = data['isActive'] as bool? ?? true;
        final isFeatured = data['isFeatured'] as bool? ?? false;
        final category = data['category'] as String? ?? 'uncategorized';
        final price = (data['price'] as num?)?.toDouble() ?? 0;

        if (isActive) activeProducts++;
        if (isFeatured) featuredProducts++;

        productsByCategory[category] = (productsByCategory[category] ?? 0) + 1;
        totalPrice += price;
      }

      // Count active popups with products
      int activePopups = 0;
      final now = DateTime.now();

      for (final doc in vendorPostsSnapshot.docs) {
        final data = doc.data();
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        final products = data['products'] as List? ?? [];

        if (expiresAt != null && expiresAt.isAfter(now) && products.isNotEmpty) {
          activePopups++;
        }
      }

      // Analyze product analytics
      for (final doc in analyticsSnapshot.docs) {
        final data = doc.data();
        final eventType = data['eventType'] as String?;
        final productId = data['productId'] as String?;
        final count = data['count'] as int? ?? 1;

        if (eventType == 'product_view') {
          productViews += count;
        } else if (eventType == 'product_interaction') {
          productInteractions += count;
        } else if (eventType == 'product_purchase') {
          productPurchases += count;
          if (productId != null) {
            topSellingProducts[productId] = (topSellingProducts[productId] ?? 0) + count;
          }
        }
      }

      // Calculate conversion rate
      double conversionRate = productViews > 0 ? (productPurchases / productViews) * 100 : 0;

      // Get top selling products names
      List<Map<String, dynamic>> topProducts = [];
      final sortedProducts = topSellingProducts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < sortedProducts.length && i < 10; i++) {
        final productId = sortedProducts[i].key;
        final salesCount = sortedProducts[i].value;

        try {
          final productDoc = await _firestore.collection('products').doc(productId).get();
          if (productDoc.exists) {
            final productData = productDoc.data()!;
            topProducts.add({
              'id': productId,
              'name': productData['name'] ?? 'Unknown Product',
              'sales': salesCount,
              'price': productData['price'] ?? 0,
            });
          }
        } catch (e) {
          // Skip if product not found
        }
      }

      return {
        'total': totalProducts,
        'active': activeProducts,
        'featured': featuredProducts,
        'activePopups': activePopups,
        'byCategory': productsByCategory,
        'averagePrice': totalProducts > 0 ? totalPrice / totalProducts : 0,
        'views': productViews,
        'interactions': productInteractions,
        'purchases': productPurchases,
        'conversionRate': conversionRate,
        'topSelling': topProducts,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Ticket metrics - sales, revenue, events, check-ins
  static Future<Map<String, dynamic>> _getTicketMetrics() async {
    try {
      // Get all tickets
      final ticketsSnapshot = await _firestore.collection('tickets').get();

      // Get all orders and filter for ticket orders
      final ordersSnapshot = await _firestore.collection('orders').get();

      // Get QR check-ins
      final checkInsSnapshot = await _firestore.collection('ticket_checkins').get();

      // Get events with ticketing
      final eventsSnapshot = await _firestore.collection('events')
          .where('hasTicketing', isEqualTo: true)
          .get();

      int totalTickets = ticketsSnapshot.docs.length;
      int soldTickets = 0;
      double ticketRevenue = 0;
      double totalTicketPrice = 0;
      int qrCheckins = 0;

      // Time periods
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));

      int ticketsSoldToday = 0;
      int ticketsSoldWeek = 0;
      int ticketsSoldMonth = 0;
      double revenueToday = 0;
      double revenueWeek = 0;
      double revenueMonth = 0;

      // Analyze ticket orders
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final ticketId = data['ticketId'] as String?;
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final quantity = data['quantity'] as int? ?? 1;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Only count ticket orders with successful status
        if (ticketId != null &&
            (status == 'paid' || status == 'confirmed' || status == 'preparing' ||
             status == 'ready_for_pickup' || status == 'picked_up')) {
          soldTickets += quantity;
          ticketRevenue += total;

          if (createdAt != null) {
            if (createdAt.isAfter(todayStart)) {
              ticketsSoldToday += quantity;
              revenueToday += total;
            }
            if (createdAt.isAfter(weekAgo)) {
              ticketsSoldWeek += quantity;
              revenueWeek += total;
            }
            if (createdAt.isAfter(monthAgo)) {
              ticketsSoldMonth += quantity;
              revenueMonth += total;
            }
          }
        }
      }

      // Analyze tickets for pricing
      for (final doc in ticketsSnapshot.docs) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        totalTicketPrice += price;
      }

      // Count QR check-ins
      qrCheckins = checkInsSnapshot.docs.length;

      // Calculate utilization rate
      double utilizationRate = soldTickets > 0 ? (qrCheckins / soldTickets) * 100 : 0;

      return {
        'total': totalTickets,
        'sold': {
          'total': soldTickets,
          'today': ticketsSoldToday,
          'week': ticketsSoldWeek,
          'month': ticketsSoldMonth,
        },
        'revenue': {
          'total': ticketRevenue,
          'today': revenueToday,
          'week': revenueWeek,
          'month': revenueMonth,
        },
        'averagePrice': totalTickets > 0 ? totalTicketPrice / totalTickets : 0,
        'eventsWithTicketing': eventsSnapshot.docs.length,
        'qrCheckins': qrCheckins,
        'utilizationRate': utilizationRate,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Transaction metrics - comprehensive payment analytics
  static Future<Map<String, dynamic>> _getTransactionMetrics() async {
    try {
      // Get all orders (actual transactions)
      final ordersSnapshot = await _firestore.collection('orders').get();

      double totalVolume = 0;
      int totalTransactions = ordersSnapshot.docs.length;
      int successfulTransactions = 0;
      int failedTransactions = 0;
      double platformFees = 0;

      // Revenue breakdown (we'll determine type by checking if productId or ticketId exists)
      double productRevenue = 0;
      double ticketRevenue = 0;

      // Time period analysis
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));

      int transactionsToday = 0;
      int transactionsWeek = 0;
      int transactionsMonth = 0;
      double volumeToday = 0;
      double volumeWeek = 0;
      double volumeMonth = 0;

      // Vendor revenue tracking
      Map<String, double> vendorRevenue = {};

      // Analyze orders as transactions
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final status = data['status'] as String?;
        final vendorId = data['vendorId'] as String?;
        final productId = data['productId'] as String?;
        final ticketId = data['ticketId'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final fee = (data['platformFee'] as num?)?.toDouble() ?? 0;

        // Only count paid/successful orders
        if (status == 'paid' || status == 'confirmed' || status == 'preparing' ||
            status == 'ready_for_pickup' || status == 'picked_up') {
          totalVolume += total;
          platformFees += fee;
          successfulTransactions++;

          // Determine revenue type
          if (productId != null) {
            productRevenue += total;
          } else if (ticketId != null) {
            ticketRevenue += total;
          }

          // Vendor revenue
          if (vendorId != null) {
            vendorRevenue[vendorId] = (vendorRevenue[vendorId] ?? 0) + total;
          }

          // Time period analysis
          if (createdAt != null) {
            if (createdAt.isAfter(todayStart)) {
              transactionsToday++;
              volumeToday += total;
            }
            if (createdAt.isAfter(weekAgo)) {
              transactionsWeek++;
              volumeWeek += total;
            }
            if (createdAt.isAfter(monthAgo)) {
              transactionsMonth++;
              volumeMonth += total;
            }
          }
        } else if (status == 'cancelled' || status == 'refunded' || status == 'failed') {
          failedTransactions++;
        }
      }

      // Calculate success rate
      double successRate = totalTransactions > 0
          ? (successfulTransactions / totalTransactions) * 100
          : 0;

      // Calculate average transaction value
      double averageValue = successfulTransactions > 0 ? totalVolume / successfulTransactions : 0;

      // Get top revenue generating vendors
      final sortedVendors = vendorRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      List<Map<String, dynamic>> topVendors = [];
      for (int i = 0; i < sortedVendors.length && i < 10; i++) {
        final vendorId = sortedVendors[i].key;
        final revenue = sortedVendors[i].value;

        try {
          final vendorDoc = await _firestore.collection('managed_vendors').doc(vendorId).get();
          if (vendorDoc.exists) {
            final vendorData = vendorDoc.data()!;
            topVendors.add({
              'id': vendorId,
              'name': vendorData['businessName'] ?? 'Unknown Vendor',
              'revenue': revenue,
            });
          }
        } catch (e) {
          // Skip if vendor not found
        }
      }

      // Get subscriptions revenue from user_subscriptions
      final subscriptionsSnapshot = await _firestore.collection('user_subscriptions')
          .where('status', isEqualTo: 'active')
          .get();

      double subscriptionRevenue = 0;
      for (final doc in subscriptionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        subscriptionRevenue += amount;
      }

      return {
        'totalVolume': totalVolume,
        'totalTransactions': successfulTransactions,
        'successfulTransactions': successfulTransactions,
        'failedTransactions': failedTransactions,
        'successRate': successRate,
        'averageValue': averageValue,
        'platformFees': platformFees,
        'counts': {
          'today': transactionsToday,
          'week': transactionsWeek,
          'month': transactionsMonth,
        },
        'volume': {
          'today': volumeToday,
          'week': volumeWeek,
          'month': volumeMonth,
        },
        'revenueByType': {
          'products': productRevenue,
          'tickets': ticketRevenue,
          'subscriptions': subscriptionRevenue,
        },
        'topVendors': topVendors,
        'abandonedBaskets': {
          'count': 0, // TODO: Implement if basket tracking is added
          'value': 0,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get Key Performance Indicators (KPIs) - CEO's most important metrics
  static Future<Map<String, dynamic>> _getKeyPerformanceIndicators() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final weekAgo = now.subtract(const Duration(days: 7));
      final lastWeekStart = weekAgo.subtract(const Duration(days: 7));

      // 1. New Signups
      final newSignupsResult = await _getNewSignupsKPI(todayStart, yesterdayStart, weekAgo, lastWeekStart);

      // 2. Returning Users
      final returningUsersResult = await _getReturningUsersKPI(todayStart, yesterdayStart, weekAgo, lastWeekStart);

      // 3. Posts Created
      final postsCreatedResult = await _getPostsCreatedKPI(todayStart, yesterdayStart, weekAgo, lastWeekStart);

      // 4. Products Listed
      final productsListedResult = await _getProductsListedKPI(todayStart, yesterdayStart, weekAgo, lastWeekStart);

      // 5. Item Preorders
      final itemPreordersResult = await _getItemPreordersKPI(todayStart, yesterdayStart, weekAgo, lastWeekStart);

      // 6. Tickets Purchased
      final ticketsPurchasedResult = await _getTicketsPurchasedKPI(todayStart, yesterdayStart, weekAgo, lastWeekStart);

      return {
        'newSignups': newSignupsResult,
        'returningUsers': returningUsersResult,
        'postsCreated': postsCreatedResult,
        'productsListed': productsListedResult,
        'itemPreorders': itemPreordersResult,
        'ticketsPurchased': ticketsPurchasedResult,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Get new signups KPI
  static Future<Map<String, dynamic>> _getNewSignupsKPI(DateTime todayStart, DateTime yesterdayStart, DateTime weekAgo, DateTime lastWeekStart) async {
    final userProfilesSnapshot = await _firestore.collection('user_profiles').get();

    int todayCount = 0;
    int yesterdayCount = 0;
    int thisWeekCount = 0;
    int lastWeekCount = 0;

    for (final doc in userProfilesSnapshot.docs) {
      final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        if (createdAt.isAfter(todayStart)) {
          todayCount++;
        } else if (createdAt.isAfter(yesterdayStart) && createdAt.isBefore(todayStart)) {
          yesterdayCount++;
        }

        if (createdAt.isAfter(weekAgo)) {
          thisWeekCount++;
        } else if (createdAt.isAfter(lastWeekStart) && createdAt.isBefore(weekAgo)) {
          lastWeekCount++;
        }
      }
    }

    double dailyChange = yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100) : 0;
    double weeklyChange = lastWeekCount > 0 ? ((thisWeekCount - lastWeekCount) / lastWeekCount * 100) : 0;

    return {
      'today': todayCount,
      'yesterday': yesterdayCount,
      'thisWeek': thisWeekCount,
      'lastWeek': lastWeekCount,
      'dailyChange': dailyChange,
      'weeklyChange': weeklyChange,
    };
  }

  /// Get returning users KPI
  static Future<Map<String, dynamic>> _getReturningUsersKPI(DateTime todayStart, DateTime yesterdayStart, DateTime weekAgo, DateTime lastWeekStart) async {
    final userProfilesSnapshot = await _firestore.collection('user_profiles').get();

    int todayCount = 0;
    int yesterdayCount = 0;
    int thisWeekCount = 0;
    int lastWeekCount = 0;

    for (final doc in userProfilesSnapshot.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final lastActive = (data['lastActive'] as Timestamp?)?.toDate();

      // Only count as returning if they were created before today and are active
      if (createdAt != null && lastActive != null && createdAt.isBefore(todayStart)) {
        if (lastActive.isAfter(todayStart)) {
          todayCount++;
        } else if (lastActive.isAfter(yesterdayStart) && lastActive.isBefore(todayStart)) {
          yesterdayCount++;
        }

        if (lastActive.isAfter(weekAgo)) {
          thisWeekCount++;
        } else if (lastActive.isAfter(lastWeekStart) && lastActive.isBefore(weekAgo)) {
          lastWeekCount++;
        }
      }
    }

    double dailyChange = yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100) : 0;
    double weeklyChange = lastWeekCount > 0 ? ((thisWeekCount - lastWeekCount) / lastWeekCount * 100) : 0;

    return {
      'today': todayCount,
      'yesterday': yesterdayCount,
      'thisWeek': thisWeekCount,
      'lastWeek': lastWeekCount,
      'dailyChange': dailyChange,
      'weeklyChange': weeklyChange,
    };
  }

  /// Get posts created KPI
  static Future<Map<String, dynamic>> _getPostsCreatedKPI(DateTime todayStart, DateTime yesterdayStart, DateTime weekAgo, DateTime lastWeekStart) async {
    final vendorPostsSnapshot = await _firestore.collection('vendor_posts').get();

    int todayCount = 0;
    int yesterdayCount = 0;
    int thisWeekCount = 0;
    int lastWeekCount = 0;

    for (final doc in vendorPostsSnapshot.docs) {
      final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        if (createdAt.isAfter(todayStart)) {
          todayCount++;
        } else if (createdAt.isAfter(yesterdayStart) && createdAt.isBefore(todayStart)) {
          yesterdayCount++;
        }

        if (createdAt.isAfter(weekAgo)) {
          thisWeekCount++;
        } else if (createdAt.isAfter(lastWeekStart) && createdAt.isBefore(weekAgo)) {
          lastWeekCount++;
        }
      }
    }

    double dailyChange = yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100) : 0;
    double weeklyChange = lastWeekCount > 0 ? ((thisWeekCount - lastWeekCount) / lastWeekCount * 100) : 0;

    return {
      'today': todayCount,
      'yesterday': yesterdayCount,
      'thisWeek': thisWeekCount,
      'lastWeek': lastWeekCount,
      'dailyChange': dailyChange,
      'weeklyChange': weeklyChange,
    };
  }

  /// Get products listed KPI
  static Future<Map<String, dynamic>> _getProductsListedKPI(DateTime todayStart, DateTime yesterdayStart, DateTime weekAgo, DateTime lastWeekStart) async {
    final productsSnapshot = await _firestore.collection('products').get();

    int todayCount = 0;
    int yesterdayCount = 0;
    int thisWeekCount = 0;
    int lastWeekCount = 0;

    for (final doc in productsSnapshot.docs) {
      final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        if (createdAt.isAfter(todayStart)) {
          todayCount++;
        } else if (createdAt.isAfter(yesterdayStart) && createdAt.isBefore(todayStart)) {
          yesterdayCount++;
        }

        if (createdAt.isAfter(weekAgo)) {
          thisWeekCount++;
        } else if (createdAt.isAfter(lastWeekStart) && createdAt.isBefore(weekAgo)) {
          lastWeekCount++;
        }
      }
    }

    double dailyChange = yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100) : 0;
    double weeklyChange = lastWeekCount > 0 ? ((thisWeekCount - lastWeekCount) / lastWeekCount * 100) : 0;

    return {
      'today': todayCount,
      'yesterday': yesterdayCount,
      'thisWeek': thisWeekCount,
      'lastWeek': lastWeekCount,
      'dailyChange': dailyChange,
      'weeklyChange': weeklyChange,
    };
  }

  /// Get item preorders KPI
  static Future<Map<String, dynamic>> _getItemPreordersKPI(DateTime todayStart, DateTime yesterdayStart, DateTime weekAgo, DateTime lastWeekStart) async {
    // Get all orders with productId (product orders)
    final ordersSnapshot = await _firestore.collection('orders').get();

    int todayCount = 0;
    int yesterdayCount = 0;
    int thisWeekCount = 0;
    int lastWeekCount = 0;

    for (final doc in ordersSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      final productId = data['productId'] as String?;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      // Only count product orders with successful status
      if (productId != null &&
          (status == 'paid' || status == 'confirmed' || status == 'preparing' ||
           status == 'ready_for_pickup' || status == 'picked_up') &&
          createdAt != null) {
        if (createdAt.isAfter(todayStart)) {
          todayCount++;
        } else if (createdAt.isAfter(yesterdayStart) && createdAt.isBefore(todayStart)) {
          yesterdayCount++;
        }

        if (createdAt.isAfter(weekAgo)) {
          thisWeekCount++;
        } else if (createdAt.isAfter(lastWeekStart) && createdAt.isBefore(weekAgo)) {
          lastWeekCount++;
        }
      }
    }

    double dailyChange = yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100) : 0;
    double weeklyChange = lastWeekCount > 0 ? ((thisWeekCount - lastWeekCount) / lastWeekCount * 100) : 0;

    return {
      'today': todayCount,
      'yesterday': yesterdayCount,
      'thisWeek': thisWeekCount,
      'lastWeek': lastWeekCount,
      'dailyChange': dailyChange,
      'weeklyChange': weeklyChange,
    };
  }

  /// Get tickets purchased KPI
  static Future<Map<String, dynamic>> _getTicketsPurchasedKPI(DateTime todayStart, DateTime yesterdayStart, DateTime weekAgo, DateTime lastWeekStart) async {
    // Get all orders with ticketId (ticket orders)
    final ordersSnapshot = await _firestore.collection('orders').get();

    int todayCount = 0;
    int yesterdayCount = 0;
    int thisWeekCount = 0;
    int lastWeekCount = 0;

    for (final doc in ordersSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      final ticketId = data['ticketId'] as String?;
      final quantity = data['quantity'] as int? ?? 1;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      // Only count ticket orders with successful status
      if (ticketId != null &&
          (status == 'paid' || status == 'confirmed' || status == 'preparing' ||
           status == 'ready_for_pickup' || status == 'picked_up') &&
          createdAt != null) {
        if (createdAt.isAfter(todayStart)) {
          todayCount += quantity;
        } else if (createdAt.isAfter(yesterdayStart) && createdAt.isBefore(todayStart)) {
          yesterdayCount += quantity;
        }

        if (createdAt.isAfter(weekAgo)) {
          thisWeekCount += quantity;
        } else if (createdAt.isAfter(lastWeekStart) && createdAt.isBefore(weekAgo)) {
          lastWeekCount += quantity;
        }
      }
    }

    double dailyChange = yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100) : 0;
    double weeklyChange = lastWeekCount > 0 ? ((thisWeekCount - lastWeekCount) / lastWeekCount * 100) : 0;

    return {
      'today': todayCount,
      'yesterday': yesterdayCount,
      'thisWeek': thisWeekCount,
      'lastWeek': lastWeekCount,
      'dailyChange': dailyChange,
      'weeklyChange': weeklyChange,
    };
  }

  /// Get growth trends over time
  static Future<Map<String, dynamic>> getGrowthTrends() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      // Daily user growth
      Map<String, int> dailyNewUsers = {};
      Map<String, double> dailyRevenue = {};
      
      // Get users created in last 30 days
      final usersSnapshot = await _firestore
          .collection('user_profiles')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      for (final doc in usersSnapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyNewUsers[dateKey] = (dailyNewUsers[dateKey] ?? 0) + 1;
        }
      }
      
      // Get revenue trends
      final transactionsSnapshot = await _firestore
          .collection('transactions')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        
        if (createdAt != null) {
          final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + amount;
        }
      }
      
      return {
        'dailyNewUsers': dailyNewUsers,
        'dailyRevenue': dailyRevenue,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}