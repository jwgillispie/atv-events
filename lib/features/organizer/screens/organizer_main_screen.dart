import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/organizer/screens/post_management_screen.dart';
import 'package:hipop/features/organizer/screens/vendors/organizer_vendors_tab.dart';
import 'package:hipop/features/organizer/screens/ratings/organizer_ratings_tab.dart';
import 'package:hipop/features/organizer/screens/profile/organizer_profile_tab.dart';
import 'package:hipop/features/shared/widgets/common/loading_widget.dart';

/// Main organizer screen with 5-tab bottom navigation
/// Implements Material Design 3 principles with HiPop's organizer-focused design system
/// Features bidirectional rating system and seamless vendor management
class OrganizerMainScreen extends StatefulWidget {
  const OrganizerMainScreen({super.key});

  @override
  State<OrganizerMainScreen> createState() => _OrganizerMainScreenState();
}

class _OrganizerMainScreenState extends State<OrganizerMainScreen> {
  int _selectedIndex = 0; // Default to Post tab (first)

  // Store page keys to maintain state
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // Screen widgets - using IndexedStack to preserve state
  // Order: Post, Vendors, Reviews, Profile
  late final List<Widget> _screens = [
    const PostManagementScreen(), // Post - first/important
    const OrganizerVendorsTab(), // Vendors management
    const OrganizerRatingsTab(), // Reviews (Ratings)
    const OrganizerProfileTab(), // Profile
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // If tapping the same tab, pop to first route
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
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

        // Verify user is a market organizer
        if (state.userType != 'market_organizer') {
          return const Scaffold(
            body: Center(
              child: Text('Access restricted to market organizers only'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
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
              selectedItemColor: HiPopColors.organizerAccent,
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
              items: [
                // Post Tab (Markets & Events) - FIRST/IMPORTANT
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.campaign_outlined,
                    size: 24,
                    color: _selectedIndex == 0
                        ? HiPopColors.organizerAccent
                        : HiPopColors.darkTextTertiary,
                  ),
                  activeIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.organizerAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.campaign,
                      size: 24,
                      color: HiPopColors.organizerAccent,
                    ),
                  ),
                  label: 'Post',
                ),
                // Vendors Tab
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.groups_outlined,
                    size: 24,
                    color: _selectedIndex == 1
                        ? HiPopColors.organizerAccent
                        : HiPopColors.darkTextTertiary,
                  ),
                  activeIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.organizerAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.groups,
                      size: 24,
                      color: HiPopColors.organizerAccent,
                    ),
                  ),
                  label: 'Vendors',
                ),
                // Reviews Tab (was Ratings)
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.star_outline,
                    size: 24,
                    color: _selectedIndex == 2
                        ? HiPopColors.organizerAccent
                        : HiPopColors.darkTextTertiary,
                  ),
                  activeIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.organizerAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.star,
                      size: 24,
                      color: HiPopColors.organizerAccent,
                    ),
                  ),
                  label: 'Reviews',
                ),
                // Profile Tab
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.person_outline,
                    size: 24,
                    color: _selectedIndex == 3
                        ? HiPopColors.organizerAccent
                        : HiPopColors.darkTextTertiary,
                  ),
                  activeIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: HiPopColors.organizerAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 24,
                      color: HiPopColors.organizerAccent,
                    ),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}