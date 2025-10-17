import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hipop/core/constants/ui_constants.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/shared/models/market_rating.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';
import 'package:intl/intl.dart';


/// Tab for organizers to view market ratings from vendors
class MarketRatingsTab extends StatefulWidget {
  const MarketRatingsTab({super.key});

  @override
  State<MarketRatingsTab> createState() => _MarketRatingsTabState();
}

class _MarketRatingsTabState extends State<MarketRatingsTab> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _error;
  List<_MarketWithRatings> _marketsWithRatings = [];
  String? _selectedMarketId;
  List<MarketRating> _selectedMarketRatings = [];

  @override
  void initState() {
    super.initState();
    _loadOrganizerMarkets();
  }

  Future<void> _loadOrganizerMarkets() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get all markets for this organizer
      final marketsQuery = await _firestore
          .collection('markets')
          .where('organizerId', isEqualTo: userId)
          .get();

      final marketsList = <_MarketWithRatings>[];

      for (final marketDoc in marketsQuery.docs) {
        final marketId = marketDoc.id;
        final marketName = marketDoc.data()['name'] ?? 'Unknown Market';

        // Get all ratings for this market
        final ratingsQuery = await _firestore
            .collection('universal_ratings')
            .where('marketId', isEqualTo: marketId)
            .get();

        final ratings = ratingsQuery.docs
            .map((doc) => MarketRating.fromFirestore(doc))
            .toList();

        // Calculate average rating
        double averageRating = 0;
        if (ratings.isNotEmpty) {
          averageRating = ratings
              .map((r) => r.overallRating)
              .reduce((a, b) => a + b) / ratings.length;
        }

        marketsList.add(_MarketWithRatings(
          marketId: marketId,
          marketName: marketName,
          ratings: ratings,
          averageRating: averageRating,
        ));
      }

      // Sort by average rating (highest first)
      marketsList.sort((a, b) => b.averageRating.compareTo(a.averageRating));

      setState(() {
        _marketsWithRatings = marketsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load ratings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _selectMarket(String marketId) {
    final market = _marketsWithRatings.firstWhere((m) => m.marketId == marketId);
    setState(() {
      _selectedMarketId = marketId;
      _selectedMarketRatings = market.ratings;
    });
  }

  Future<void> _respondToRating(MarketRating rating, String response) async {
    try {
      await _firestore
          .collection('universal_ratings')
          .doc(rating.id)
          .update({
        'organizerResponse': response,
        'organizerResponseAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Response submitted successfully'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );

        // Reload the ratings
        _loadOrganizerMarkets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit response: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading market ratings...');
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_marketsWithRatings.isEmpty) {
      return _buildEmptyState();
    }

    // Show market details if one is selected
    if (_selectedMarketId != null) {
      return _buildMarketDetails();
    }

    // Show list of markets with average ratings
    return _buildMarketsList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: UIConstants.iconSizeExtraLarge,
              color: HiPopColors.errorPlum,
            ),
            const SizedBox(height: UIConstants.largeSpacing),
            Text(
              'Error Loading Ratings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: HiPopColors.darkTextPrimary,
                  ),
            ),
            const SizedBox(height: UIConstants.smallSpacing),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HiPopColors.darkTextSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: UIConstants.largeSpacing),
            ElevatedButton(
              onPressed: _loadOrganizerMarkets,
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.extraLargeSpacing),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: UIConstants.iconSizeExtraLarge,
              color: HiPopColors.darkTextTertiary,
            ),
            const SizedBox(height: UIConstants.largeSpacing),
            Text(
              'No Ratings Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: HiPopColors.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: UIConstants.smallSpacing),
            Text(
              'Ratings from vendors will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HiPopColors.darkTextSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketsList() {
    return RefreshIndicator(
      onRefresh: _loadOrganizerMarkets,
      backgroundColor: HiPopColors.darkSurface,
      color: HiPopColors.primaryDeepSage,
      child: ListView.builder(
        padding: const EdgeInsets.all(UIConstants.defaultPadding),
        itemCount: _marketsWithRatings.length,
        itemBuilder: (context, index) {
          final market = _marketsWithRatings[index];
          return _buildMarketCard(market);
        },
      ),
    );
  }

  Widget _buildMarketCard(_MarketWithRatings market) {
    return Container(
      margin: const EdgeInsets.only(bottom: UIConstants.defaultPadding),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(UIConstants.cardBorderRadius),
        border: Border.all(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(UIConstants.cardBorderRadius),
          onTap: () => _selectMarket(market.marketId),
          child: Padding(
            padding: const EdgeInsets.all(UIConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Market icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: HiPopColors.organizerAccent.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(UIConstants.mediumBorderRadius),
                      ),
                      child: Icon(
                        Icons.storefront,
                        color: HiPopColors.organizerAccent,
                        size: UIConstants.iconSizeDefault,
                      ),
                    ),
                    const SizedBox(width: UIConstants.contentSpacing),
                    
                    // Market info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            market.marketName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: HiPopColors.darkTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: UIConstants.extraSmallSpacing),
                          Text(
                            '${market.ratings.length} ${market.ratings.length == 1 ? 'rating' : 'ratings'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: HiPopColors.darkTextTertiary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Average rating
                    if (market.ratings.isNotEmpty) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: UIConstants.iconSizeMedium,
                                color: HiPopColors.premiumGold,
                              ),
                              const SizedBox(width: UIConstants.extraSmallSpacing),
                              Text(
                                market.averageRating.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: HiPopColors.darkTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          Text(
                            'Average',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: HiPopColors.darkTextTertiary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                
                // Category averages
                if (market.ratings.isNotEmpty) ...[
                  const SizedBox(height: UIConstants.defaultPadding),
                  _buildCategoryAverages(market.ratings),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryAverages(List<MarketRating> ratings) {
    final categoryAverages = <String, double>{};
    
    for (final category in RatingCategory.labels.keys) {
      double sum = 0;
      int count = 0;
      for (final rating in ratings) {
        final categoryRating = rating.categoryRatings[category];
        if (categoryRating != null && categoryRating > 0) {
          sum += categoryRating;
          count++;
        }
      }
      if (count > 0) {
        categoryAverages[category] = sum / count;
      }
    }

    return Wrap(
      spacing: UIConstants.smallSpacing,
      runSpacing: UIConstants.smallSpacing,
      children: categoryAverages.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UIConstants.contentSpacing,
            vertical: UIConstants.extraSmallSpacing,
          ),
          decoration: BoxDecoration(
            color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(UIConstants.tagBorderRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                RatingCategory.icons[entry.key],
                size: UIConstants.iconSizeExtraSmall,
                color: HiPopColors.primaryDeepSage,
              ),
              const SizedBox(width: UIConstants.extraSmallSpacing),
              Text(
                entry.value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: UIConstants.textSizeSmall,
                  color: HiPopColors.primaryDeepSage,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMarketDetails() {
    final market = _marketsWithRatings.firstWhere((m) => m.marketId == _selectedMarketId!);
    
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(UIConstants.defaultPadding),
          decoration: BoxDecoration(
            color: HiPopColors.darkSurface,
            border: Border(
              bottom: BorderSide(
                color: HiPopColors.darkBorder.withOpacity( 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedMarketId = null;
                    _selectedMarketRatings = [];
                  });
                },
                icon: Icon(
                  Icons.arrow_back,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(width: UIConstants.smallSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      market.marketName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: HiPopColors.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (market.ratings.isNotEmpty) ...[
                      const SizedBox(height: UIConstants.extraSmallSpacing),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: UIConstants.iconSizeSmall,
                            color: HiPopColors.premiumGold,
                          ),
                          const SizedBox(width: UIConstants.extraSmallSpacing),
                          Text(
                            '${market.averageRating.toStringAsFixed(1)} average · ${market.ratings.length} ratings',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: HiPopColors.darkTextSecondary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Ratings list
        Expanded(
          child: _selectedMarketRatings.isEmpty
              ? Center(
                  child: Text(
                    'No ratings yet',
                    style: TextStyle(color: HiPopColors.darkTextTertiary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(UIConstants.defaultPadding),
                  itemCount: _selectedMarketRatings.length,
                  itemBuilder: (context, index) {
                    final rating = _selectedMarketRatings[index];
                    return _buildRatingCard(rating);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRatingCard(MarketRating rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: UIConstants.defaultPadding),
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(UIConstants.cardBorderRadius),
        border: Border.all(
          color: HiPopColors.darkBorder.withOpacity( 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor info and rating
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.vendorBusinessName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: HiPopColors.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      rating.vendorName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HiPopColors.darkTextSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: _buildStarRating(rating.overallRating),
                  ),
                  Text(
                    DateFormat.yMMMd().format(rating.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HiPopColors.darkTextTertiary,
                        ),
                  ),
                ],
              ),
            ],
          ),
          
          // Category ratings
          if (rating.categoryRatings.isNotEmpty) ...[
            const SizedBox(height: UIConstants.contentSpacing),
            Wrap(
              spacing: UIConstants.smallSpacing,
              runSpacing: UIConstants.smallSpacing,
              children: rating.categoryRatings.entries.map((entry) {
                if (entry.value == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.smallSpacing,
                    vertical: UIConstants.extraSmallSpacing,
                  ),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkBackground,
                    borderRadius: BorderRadius.circular(UIConstants.tagBorderRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        RatingCategory.labels[entry.key] ?? entry.key,
                        style: TextStyle(
                          fontSize: UIConstants.textSizeSmall,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(width: UIConstants.extraSmallSpacing),
                      Text(
                        entry.value.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: UIConstants.textSizeSmall,
                          color: HiPopColors.primaryDeepSage,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          
          // Review text
          if (rating.review != null && rating.review!.isNotEmpty) ...[
            const SizedBox(height: UIConstants.contentSpacing),
            Text(
              rating.review!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HiPopColors.darkTextPrimary,
                  ),
            ),
          ],
          
          // Organizer response
          if (rating.organizerResponse != null) ...[
            const SizedBox(height: UIConstants.contentSpacing),
            Container(
              padding: const EdgeInsets.all(UIConstants.contentSpacing),
              decoration: BoxDecoration(
                color: HiPopColors.darkBackground,
                borderRadius: BorderRadius.circular(UIConstants.mediumBorderRadius),
                border: Border.all(
                  color: HiPopColors.organizerAccent.withOpacity( 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: UIConstants.iconSizeSmall,
                        color: HiPopColors.organizerAccent,
                      ),
                      const SizedBox(width: UIConstants.extraSmallSpacing),
                      Text(
                        'Organizer Response',
                        style: TextStyle(
                          fontSize: UIConstants.textSizeSmall,
                          color: HiPopColors.organizerAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: UIConstants.smallSpacing),
                  Text(
                    rating.organizerResponse!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HiPopColors.darkTextSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Add response button
            const SizedBox(height: UIConstants.contentSpacing),
            TextButton.icon(
              onPressed: () => _showResponseDialog(rating),
              icon: Icon(
                Icons.reply,
                size: UIConstants.iconSizeSmall,
              ),
              label: const Text('Respond to Review'),
              style: TextButton.styleFrom(
                foregroundColor: HiPopColors.organizerAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showResponseDialog(MarketRating rating) {
    final responseController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Text(
          'Respond to Review',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: TextField(
          controller: responseController,
          maxLines: 5,
          maxLength: 300,
          style: TextStyle(color: HiPopColors.darkTextPrimary),
          decoration: InputDecoration(
            hintText: 'Write your response...',
            hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
            filled: true,
            fillColor: HiPopColors.darkBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UIConstants.mediumBorderRadius),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (responseController.text.isNotEmpty) {
                Navigator.of(context).pop();
                _respondToRating(rating, responseController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.organizerAccent,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStarRating(double rating) {
    final stars = <Widget>[];
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;
    
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(
          Icons.star,
          size: UIConstants.iconSizeSmall,
          color: HiPopColors.premiumGold,
        ));
      } else if (i == fullStars && hasHalfStar) {
        stars.add(Icon(
          Icons.star_half,
          size: UIConstants.iconSizeSmall,
          color: HiPopColors.premiumGold,
        ));
      } else {
        stars.add(Icon(
          Icons.star_outline,
          size: UIConstants.iconSizeSmall,
          color: HiPopColors.darkTextTertiary,
        ));
      }
    }
    
    return stars;
  }
}

// Internal model for managing market and ratings data
class _MarketWithRatings {
  final String marketId;
  final String marketName;
  final List<MarketRating> ratings;
  final double averageRating;

  _MarketWithRatings({
    required this.marketId,
    required this.marketName,
    required this.ratings,
    required this.averageRating,
  });
}