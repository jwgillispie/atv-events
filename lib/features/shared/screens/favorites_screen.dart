import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/blocs/favorites/favorites_bloc.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';

import '../../market/models/market.dart';
import '../../vendor/models/managed_vendor.dart';
import '../../vendor/models/vendor_product.dart';
import '../../market/services/market_service.dart';
import '../../vendor/services/core/managed_vendor_service.dart';
import '../../vendor/services/products/vendor_product_service.dart';
import '../widgets/common/loading_widget.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);  // Changed to 3 tabs
    // Initialize favorites on first load
    _initializeFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeFavorites() {
    // Initialize favorites loading when screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        context.read<FavoritesBloc>().add(LoadFavorites(userId: authState.user.uid));
      }
    });
  }

  Future<List<ManagedVendor>> _loadFavoriteVendors(List<String> vendorIds) async {
    if (vendorIds.isEmpty) {
      return [];
    }

    try {
      // Use batch loading with concurrent requests and timeout
      final vendorFutures = vendorIds.map((vendorId) => 
        ManagedVendorService.getVendor(vendorId).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        ).catchError((_) => null));
      
      final vendorResults = await Future.wait(vendorFutures);
      return vendorResults.whereType<ManagedVendor>().toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading favorite vendors: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                setState(() {}); // Trigger rebuild to retry
              },
            ),
          ),
        );
      }
      return [];
    }
  }

  Future<List<Market>> _loadFavoriteMarkets(List<String> marketIds) async {
    if (marketIds.isEmpty) {
      return [];
    }

    try {
      // Use batch loading with concurrent requests and timeout
      final marketFutures = marketIds.map((marketId) =>
        MarketService.getMarket(marketId).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        ).catchError((_) => null));

      final marketResults = await Future.wait(marketFutures);
      return marketResults.whereType<Market>().toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading favorite markets: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                setState(() {}); // Trigger rebuild to retry
              },
            ),
          ),
        );
      }
      return [];
    }
  }

  Future<List<VendorProduct>> _loadFavoriteProducts(List<String> productIds) async {
    if (productIds.isEmpty) {
      return [];
    }

    try {
      // Use batch loading with concurrent requests and timeout
      final productFutures = productIds.map((productId) =>
        VendorProductService.getProduct(productId).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        ).catchError((_) => null));

      final productResults = await Future.wait(productFutures);
      return productResults.whereType<VendorProduct>().toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading favorite products: ${e.toString()}'),
            backgroundColor: HiPopColors.errorPlum,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                setState(() {}); // Trigger rebuild to retry
              },
            ),
          ),
        );
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return const Scaffold(
            body: LoadingWidget(message: 'Loading...'),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('My Favorites'),
            backgroundColor: HiPopColors.primaryDeepSage,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  // Reload favorites from BLoC
                  context.read<FavoritesBloc>().add(
                    LoadFavorites(userId: authState.user.uid),
                  );
                },
                tooltip: 'Refresh favorites',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: HiPopColors.premiumGold,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity( 0.7),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.store),
                  text: 'Vendors',
                ),
                Tab(
                  icon: Icon(Icons.location_on),
                  text: 'Markets',
                ),
                Tab(
                  icon: Icon(Icons.shopping_bag),
                  text: 'Products',
                ),
              ],
            ),
          ),
          body: BlocBuilder<FavoritesBloc, FavoritesState>(
            builder: (context, favoritesState) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildFavoriteVendorsList(favoritesState),
                  _buildFavoriteMarketsList(favoritesState),
                  _buildFavoriteProductsList(favoritesState),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFavoriteVendorsList(FavoritesState favoritesState) {
    // Show loading only for initial load
    if (favoritesState.status == FavoritesStatus.loading && 
        favoritesState.favoriteVendorIds.isEmpty) {
      return const LoadingWidget(message: 'Loading favorite vendors...');
    }

    // Real-time update using FutureBuilder with the current favorite IDs
    return FutureBuilder<List<ManagedVendor>>(
      future: _loadFavoriteVendors(favoritesState.favoriteVendorIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return const LoadingWidget(message: 'Loading favorite vendors...');
        }

        final vendors = snapshot.data ?? [];
        
        if (vendors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.store,
            title: 'No Favorite Vendors',
            subtitle: 'Vendors you favorite will appear here.\nStart exploring markets to find vendors you love!',
          );
        }

        return RefreshIndicator(
          color: HiPopColors.primaryDeepSage,
          onRefresh: () async {
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              context.read<FavoritesBloc>().add(
                LoadFavorites(userId: authState.user.uid),
              );
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return _buildVendorCard(vendor);
            },
          ),
        );
      },
    );
  }

  Widget _buildFavoriteMarketsList(FavoritesState favoritesState) {
    // Show loading only for initial load
    if (favoritesState.status == FavoritesStatus.loading && 
        favoritesState.favoriteMarketIds.isEmpty) {
      return const LoadingWidget(message: 'Loading favorite markets...');
    }

    // Real-time update using FutureBuilder with the current favorite IDs
    return FutureBuilder<List<Market>>(
      future: _loadFavoriteMarkets(favoritesState.favoriteMarketIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return const LoadingWidget(message: 'Loading favorite markets...');
        }

        final markets = snapshot.data ?? [];
        
        if (markets.isEmpty) {
          return _buildEmptyState(
            icon: Icons.location_on,
            title: 'No Favorite Markets',
            subtitle: 'Markets you favorite will appear here.\nExplore nearby markets and save the ones you love!',
          );
        }

        return RefreshIndicator(
          color: HiPopColors.primaryDeepSage,
          onRefresh: () async {
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              context.read<FavoritesBloc>().add(
                LoadFavorites(userId: authState.user.uid),
              );
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: markets.length,
            itemBuilder: (context, index) {
              final market = markets[index];
              return _buildMarketCard(market);
            },
          ),
        );
      },
    );
  }

  Widget _buildVendorCard(ManagedVendor vendor) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HiPopColors.lightBorder.withOpacity( 0.5),
          width: 1,
        ),
      ),
      elevation: 0,
      color: theme.cardColor,
      child: InkWell(
        onTap: () {
          try {
            // Navigate to vendor detail if available
            context.pushNamed('vendorDetail', extra: vendor);
          } catch (e) {
            // Fallback if route doesn't exist
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${vendor.businessName} details'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          HiPopColors.vendorAccent.withOpacity( 0.15),
                          HiPopColors.vendorAccentLight.withOpacity( 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: HiPopColors.vendorAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vendor.categoriesDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _removeFavoriteVendor(vendor.id),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.favorite,
                          color: HiPopColors.accentDustyRose,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                vendor.description,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (vendor.products.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Products: ${vendor.products.take(3).join(', ')}${vendor.products.length > 3 ? '...' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: HiPopColors.lightTextSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              // Contact information with clickable links
              if (vendor.email != null || vendor.website != null || vendor.instagramHandle != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (vendor.email != null) ...[
                      Icon(Icons.email, size: 14, color: HiPopColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () => _launchEmail(vendor.email!),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              vendor.email!,
                              style: TextStyle(
                                fontSize: 12,
                                color: HiPopColors.primaryDeepSage,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (vendor.email != null && vendor.website != null)
                      const SizedBox(width: 16),
                    if (vendor.website != null) ...[
                      Icon(Icons.language, size: 14, color: HiPopColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () => _launchWebsite(vendor.website!),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              vendor.website!,
                              style: TextStyle(
                                fontSize: 12,
                                color: HiPopColors.primaryDeepSage,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              
              if (vendor.instagramHandle != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.camera_alt, size: 14, color: HiPopColors.lightTextSecondary),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _launchInstagram(vendor.instagramHandle!),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '@${vendor.instagramHandle!}',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.primaryDeepSage,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketCard(Market market) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HiPopColors.lightBorder.withOpacity( 0.5),
          width: 1,
        ),
      ),
      elevation: 0,
      color: theme.cardColor,
      child: InkWell(
        onTap: () {
          context.pushNamed('marketDetail', extra: market);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          HiPopColors.primaryDeepSage.withOpacity( 0.15),
                          HiPopColors.secondarySoftSage.withOpacity( 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: HiPopColors.primaryDeepSage,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${market.city}, ${market.state}',
                          style: TextStyle(
                            fontSize: 14,
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _removeFavoriteMarket(market.id),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.favorite,
                          color: HiPopColors.accentDustyRose,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: HiPopColors.lightTextTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      market.eventDisplayInfo,
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (market.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  market.description!,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Show Instagram handle if available
              if (market.instagramHandle != null && market.instagramHandle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.camera_alt, size: 14, color: HiPopColors.lightTextSecondary),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _launchInstagram(market.instagramHandle!),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '@${market.instagramHandle!}',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.primaryDeepSage,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: HiPopColors.lightTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: HiPopColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // Navigate back to markets discovery
                context.pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: HiPopColors.primaryDeepSage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Explore Markets',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFavoriteProductsList(FavoritesState favoritesState) {
    // Show loading only for initial load
    if (favoritesState.status == FavoritesStatus.loading &&
        favoritesState.favoriteProductIds.isEmpty) {
      return const LoadingWidget(message: 'Loading favorite products...');
    }

    // Real-time update using FutureBuilder with the current favorite IDs
    return FutureBuilder<List<VendorProduct>>(
      future: _loadFavoriteProducts(favoritesState.favoriteProductIds),
      builder: (context, snapshot) {
        // Show loading during the fetch
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LoadingWidget(message: 'Loading favorite products...');
        }

        // Handle error case
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                    size: 64,
                    color: HiPopColors.lightTextTertiary),
                  const SizedBox(height: 16),
                  Text('Error loading products',
                    style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final products = snapshot.data ?? [];

        // Show empty state if no favorites
        if (products.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No favorite products yet',
            subtitle: 'Browse products and tap the heart icon to save them here',
          );
        }

        // Show the list of favorite products
        return RefreshIndicator(
          color: HiPopColors.primaryDeepSage,
          onRefresh: () async {
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              context.read<FavoritesBloc>().add(
                LoadFavorites(userId: authState.user.uid),
              );
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(VendorProduct product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to product detail if needed
          // context.pushNamed('productDetail', extra: product);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: HiPopColors.lightSurface,
                ),
                child: product.photoUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.photoUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.shopping_bag,
                                color: HiPopColors.lightTextTertiary),
                        ),
                      )
                    : Icon(Icons.shopping_bag,
                        color: HiPopColors.lightTextTertiary),
              ),
              const SizedBox(width: 16),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (product.description != null)
                      Text(
                        product.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: HiPopColors.lightTextSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    if (product.basePrice != null)
                      Text(
                        '\$${product.basePrice!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.primaryDeepSage,
                        ),
                      ),
                  ],
                ),
              ),
              // Favorite button
              IconButton(
                onPressed: () => _removeFavoriteProduct(product.id),
                icon: const Icon(
                  Icons.favorite,
                  color: HiPopColors.accentDustyRose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeFavoriteProduct(String productId) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.user.uid : null;

    context.read<FavoritesBloc>().add(
      ToggleProductFavorite(productId: productId, userId: userId),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Product removed from favorites'),
        backgroundColor: HiPopColors.primaryDeepSageDark,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: HiPopColors.premiumGold,
          onPressed: () {
            // Toggle back to re-add
            context.read<FavoritesBloc>().add(
              ToggleProductFavorite(productId: productId, userId: userId),
            );
          },
        ),
      ),
    );
  }

  void _removeFavoriteVendor(String vendorId) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.user.uid : null;
    
    context.read<FavoritesBloc>().add(
      ToggleVendorFavorite(vendorId: vendorId, userId: userId),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Vendor removed from favorites'),
        backgroundColor: HiPopColors.primaryDeepSageDark,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: HiPopColors.premiumGold,
          onPressed: () {
            // Toggle back to re-add
            context.read<FavoritesBloc>().add(
              ToggleVendorFavorite(vendorId: vendorId, userId: userId),
            );
          },
        ),
      ),
    );
  }

  void _removeFavoriteMarket(String marketId) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is Authenticated ? authState.user.uid : null;
    
    context.read<FavoritesBloc>().add(
      ToggleMarketFavorite(marketId: marketId, userId: userId),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Market removed from favorites'),
        backgroundColor: HiPopColors.primaryDeepSageDark,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: HiPopColors.premiumGold,
          onPressed: () {
            // Toggle back to re-add
            context.read<FavoritesBloc>().add(
              ToggleMarketFavorite(marketId: marketId, userId: userId),
            );
          },
        ),
      ),
    );
  }


  Future<void> _launchWebsite(String website) async {
    try {
      // Add https:// if not present
      final url = website.startsWith('http') ? website : 'https://$website';
      await UrlLauncherService.launchWebsite(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open website: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    try {
      await UrlLauncherService.launchEmail(email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open email app: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  Future<void> _launchInstagram(String handle) async {
    try {
      await UrlLauncherService.launchInstagram(handle);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Instagram: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
}