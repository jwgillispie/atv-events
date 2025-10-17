import 'package:cloud_firestore/cloud_firestore.dart';

class VendorDiscoveryAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Track vendor discovery usage
  static Future<void> trackVendorDiscoveryUsage(
    String organizerId,
    Map<String, dynamic> searchParams,
    int resultsCount,
  ) async {
    try {
      await _firestore.collection('vendor_discovery_analytics').add({
        'organizerId': organizerId,
        'searchParams': searchParams,
        'resultsCount': resultsCount,
        'timestamp': Timestamp.now(),
        'date': DateTime.now().toIso8601String().substring(0, 10), // YYYY-MM-DD
      });
      
    } catch (e) {
    }
  }

  /// Track vendor invitation sent
  static Future<void> trackVendorInvitation(
    String organizerId,
    String vendorId,
    String marketId,
    String invitationType, // 'single' or 'bulk'
  ) async {
    try {
      await _firestore.collection('vendor_invitation_analytics').add({
        'organizerId': organizerId,
        'vendorId': vendorId,
        'marketId': marketId,
        'invitationType': invitationType,
        'timestamp': Timestamp.now(),
        'date': DateTime.now().toIso8601String().substring(0, 10),
      });
      
    } catch (e) {
    }
  }

  /// Get vendor discovery analytics for organizer
  static Future<Map<String, dynamic>> getVendorDiscoveryAnalytics(
    String organizerId,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 30));
      final end = endDate ?? now;

      // Get vendor discovery searches
      final searchesSnapshot = await _firestore
          .collection('vendor_discovery_analytics')
          .where('organizerId', isEqualTo: organizerId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Get vendor invitations
      final invitationsSnapshot = await _firestore
          .collection('vendor_invitation_analytics')
          .where('organizerId', isEqualTo: organizerId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      // Calculate metrics
      final totalSearches = searchesSnapshot.docs.length;
      final totalInvitations = invitationsSnapshot.docs.length;
      
      final singleInvitations = invitationsSnapshot.docs
          .where((doc) => doc.data()['invitationType'] == 'single')
          .length;
      
      final bulkInvitations = invitationsSnapshot.docs
          .where((doc) => doc.data()['invitationType'] == 'bulk')
          .length;

      // Calculate total results found
      int totalResultsFound = 0;
      for (final doc in searchesSnapshot.docs) {
        totalResultsFound += (doc.data()['resultsCount'] as int?) ?? 0;
      }

      // Calculate average results per search
      final averageResultsPerSearch = totalSearches > 0 
          ? totalResultsFound / totalSearches 
          : 0.0;

      // Calculate invitation rate (invitations per search)
      final invitationRate = totalSearches > 0 
          ? totalInvitations / totalSearches 
          : 0.0;

      // Get most searched categories
      final categorySearchCount = <String, int>{};
      for (final doc in searchesSnapshot.docs) {
        final searchParams = doc.data()['searchParams'] as Map<String, dynamic>?;
        if (searchParams != null && searchParams.containsKey('categories')) {
          final categories = List<String>.from(searchParams['categories'] ?? []);
          for (final category in categories) {
            categorySearchCount[category] = (categorySearchCount[category] ?? 0) + 1;
          }
        }
      }

      final topCategories = categorySearchCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get daily usage over time
      final dailyUsage = <String, Map<String, int>>{};
      for (final doc in searchesSnapshot.docs) {
        final date = doc.data()['date'] as String? ?? '';
        if (date.isNotEmpty) {
          dailyUsage[date] = dailyUsage[date] ?? {'searches': 0, 'invitations': 0};
          dailyUsage[date]!['searches'] = (dailyUsage[date]!['searches'] ?? 0) + 1;
        }
      }

      for (final doc in invitationsSnapshot.docs) {
        final date = doc.data()['date'] as String? ?? '';
        if (date.isNotEmpty) {
          dailyUsage[date] = dailyUsage[date] ?? {'searches': 0, 'invitations': 0};
          dailyUsage[date]!['invitations'] = (dailyUsage[date]!['invitations'] ?? 0) + 1;
        }
      }

      return {
        'period': {
          'startDate': start.toIso8601String(),
          'endDate': end.toIso8601String(),
        },
        'summary': {
          'totalSearches': totalSearches,
          'totalInvitations': totalInvitations,
          'singleInvitations': singleInvitations,
          'bulkInvitations': bulkInvitations,
          'totalResultsFound': totalResultsFound,
          'averageResultsPerSearch': averageResultsPerSearch,
          'invitationRate': invitationRate,
        },
        'topCategories': topCategories.take(5).map((entry) => {
          'category': entry.key,
          'searches': entry.value,
        }).toList(),
        'dailyUsage': dailyUsage,
      };

    } catch (e) {
      return {};
    }
  }

  /// Get vendor discovery insights and recommendations
  static Future<List<String>> getVendorDiscoveryInsights(String organizerId) async {
    try {
      final analytics = await getVendorDiscoveryAnalytics(organizerId, null, null);
      final insights = <String>[];
      
      final summary = analytics['summary'] as Map<String, dynamic>? ?? {};
      final totalSearches = summary['totalSearches'] as int? ?? 0;
      final totalInvitations = summary['totalInvitations'] as int? ?? 0;
      final averageResults = summary['averageResultsPerSearch'] as double? ?? 0.0;
      final invitationRate = summary['invitationRate'] as double? ?? 0.0;

      // Generate insights based on usage patterns
      if (totalSearches == 0) {
        insights.add('Start using Vendor Discovery to find qualified vendors for your markets.');
      } else {
        if (totalSearches >= 10) {
          insights.add('You\'re actively using Vendor Discovery! You\'ve performed $totalSearches searches this month.');
        }

        if (averageResults < 5) {
          insights.add('Try broadening your search criteria to find more vendor options.');
        } else if (averageResults > 20) {
          insights.add('Consider narrowing your search criteria to find the most relevant vendors.');
        }

        if (invitationRate < 0.2) {
          insights.add('Consider sending more invitations to increase your vendor recruitment success.');
        } else if (invitationRate > 1.0) {
          insights.add('Great job! You\'re actively inviting vendors you discover.');
        }

        if (totalInvitations > 0) {
          insights.add('You\'ve sent $totalInvitations vendor invitations this month. Track responses to measure success.');
        }
      }

      // Get category insights
      final topCategories = analytics['topCategories'] as List<dynamic>? ?? [];
      if (topCategories.isNotEmpty) {
        final topCategory = topCategories.first as Map<String, dynamic>;
        final categoryName = topCategory['category'] as String? ?? 'Unknown';
        insights.add('Your most searched vendor category is ${_formatCategoryName(categoryName)}.');
      }

      return insights;

    } catch (e) {
      return ['Error loading insights. Please try again later.'];
    }
  }

  /// Format category name for display
  static String _formatCategoryName(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  /// Get vendor invitation response analytics
  static Future<Map<String, dynamic>> getInvitationResponseAnalytics(String organizerId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      // Get all invitations sent in the last 30 days
      final invitationsSnapshot = await _firestore
          .collection('vendor_invitations')
          .where('organizerId', isEqualTo: organizerId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final totalInvitations = invitationsSnapshot.docs.length;
      
      if (totalInvitations == 0) {
        return {
          'totalInvitations': 0,
          'responseRate': 0.0,
          'acceptanceRate': 0.0,
          'pendingInvitations': 0,
          'acceptedInvitations': 0,
          'declinedInvitations': 0,
        };
      }

      final pending = invitationsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;
      
      final accepted = invitationsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'accepted')
          .length;
      
      final declined = invitationsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'declined')
          .length;

      final responded = accepted + declined;
      final responseRate = totalInvitations > 0 ? responded / totalInvitations : 0.0;
      final acceptanceRate = responded > 0 ? accepted / responded : 0.0;

      return {
        'totalInvitations': totalInvitations,
        'responseRate': responseRate,
        'acceptanceRate': acceptanceRate,
        'pendingInvitations': pending,
        'acceptedInvitations': accepted,
        'declinedInvitations': declined,
      };

    } catch (e) {
      return {};
    }
  }
}