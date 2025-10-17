import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shopper/screens/home/shopper_home.dart';
import 'package:atv_events/features/shopper/screens/shop/shop_feed_screen.dart';
import 'package:atv_events/features/shopper/screens/profile/shopper_profile_screen.dart';
import 'package:atv_events/features/shopper/screens/basket/reservation_basket_screen.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_bloc.dart';
import 'package:atv_events/features/shopper/blocs/basket/basket_state.dart';
import 'package:atv_events/features/shared/widgets/common/loading_widget.dart';

/// Main shopper screen with bottom navigation
/// Implements adaptive navigation based on user type:
/// - Shoppers: 3 tabs (Home, Shop, Profile)
/// - Vendors: 2 tabs (Home, Shop) with Shopping Mode indicator and back button
/// - Organizers: 2 tabs (Home, Shop) with back button
class ShopperMainScreen extends StatefulWidget {
  final int? initialTab;

  const ShopperMainScreen({super.key, this.initialTab});

  @override
  State<ShopperMainScreen> createState() => _ShopperMainScreenState();
}

class _ShopperMainScreenState extends State<ShopperMainScreen> {
  late int _selectedIndex;

  // Store page keys to maintain state
  // We'll initialize this based on user type in build method
  List<GlobalKey<NavigatorState>>? _navigatorKeys;

  // Screen widgets - will be set based on user type
  List<Widget>? _screens;

  // User type variables
  String? _userType;
  bool _isShopperOnly = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab ?? 0;
  }

  void _onItemTapped(int index) {
    if (_navigatorKeys != null && _selectedIndex == index) {
      // If tapping the same tab, pop to first route
      _navigatorKeys![index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _initializeScreensForUserType(String userType) {
    _userType = userType;
    _isShopperOnly = userType == 'shopper';

    if (_isShopperOnly) {
      // Shopper gets all four tabs
      _screens = [
        const ShopperHome(),
        const ShopFeedScreen(),
        const ReservationBasketScreen(),
        const ShopperProfileScreen(),
      ];
      _navigatorKeys = [
        GlobalKey<NavigatorState>(),
        GlobalKey<NavigatorState>(),
        GlobalKey<NavigatorState>(),
        GlobalKey<NavigatorState>(),
      ];
    } else {
      // Vendors and organizers get Home, Shop, and Basket tabs
      _screens = [
        const ShopperHome(),
        const ShopFeedScreen(),
        const ReservationBasketScreen(),
      ];
      _navigatorKeys = [
        GlobalKey<NavigatorState>(),
        GlobalKey<NavigatorState>(),
        GlobalKey<NavigatorState>(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: LoadingWidget(message: 'Loading...'),
          );
        }

        // Initialize screens based on user type if not already done
        if (_screens == null || _userType != state.userType) {
          _initializeScreensForUserType(state.userType);
        }

        // Determine the accent color based on user type
        final Color accentColor = _getAccentColorForUserType(state.userType);

        // No need for special handling - all users get same interface

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          // Remove the custom app bar - ShopperHome has its own Discover app bar
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens!,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity( 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: HiPopColors.darkSurface,
              selectedItemColor: accentColor,
              unselectedItemColor: HiPopColors.darkTextTertiary,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
              elevation: 0,
              items: _buildNavigationItems(accentColor),
            ),
          ),
        );
      },
    );
  }

  /// Get the appropriate accent color based on user type
  Color _getAccentColorForUserType(String userType) {
    switch (userType) {
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'market_organizer':
        return HiPopColors.organizerAccent;
      case 'shopper':
      default:
        return HiPopColors.shopperAccent;
    }
  }


  /// Build navigation items based on user type
  List<BottomNavigationBarItem> _buildNavigationItems(Color accentColor) {
    final List<BottomNavigationBarItem> items = [
      // Home tab - always present
      BottomNavigationBarItem(
        icon: Icon(
          Icons.home_outlined,
          size: 24,
          color: _selectedIndex == 0 ? accentColor : HiPopColors.darkTextTertiary,
        ),
        activeIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.home,
            size: 24,
            color: accentColor,
          ),
        ),
        label: 'Home',
      ),
      // Shop tab - always present
      BottomNavigationBarItem(
        icon: Icon(
          Icons.shopping_bag_outlined,
          size: 24,
          color: _selectedIndex == 1 ? accentColor : HiPopColors.darkTextTertiary,
        ),
        activeIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.shopping_bag,
            size: 24,
            color: accentColor,
          ),
        ),
        label: 'Shop',
      ),
      // Basket tab with badge
      BottomNavigationBarItem(
        icon: BlocBuilder<BasketBloc, BasketState>(
          builder: (context, basketState) {
            final itemCount = basketState is BasketLoaded ? basketState.totalItems : 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.shopping_basket_outlined,
                  size: 24,
                  color: _selectedIndex == 2 ? accentColor : HiPopColors.darkTextTertiary,
                ),
                if (itemCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: HiPopColors.shopperAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          itemCount > 99 ? '99+' : itemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        activeIcon: BlocBuilder<BasketBloc, BasketState>(
          builder: (context, basketState) {
            final itemCount = basketState is BasketLoaded ? basketState.totalItems : 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.shopping_basket,
                    size: 24,
                    color: accentColor,
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: HiPopColors.shopperAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            itemCount > 99 ? '99+' : itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        label: 'Basket',
      ),
    ];

    // Add Profile tab only for shoppers
    if (_isShopperOnly) {
      items.add(
        BottomNavigationBarItem(
          icon: Icon(
            Icons.person_outline,
            size: 24,
            color: _selectedIndex == 3 ? accentColor : HiPopColors.darkTextTertiary,
          ),
          activeIcon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.person,
              size: 24,
              color: accentColor,
            ),
          ),
          label: 'Profile',
        ),
      );
    }

    return items;
  }
}