


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/organizer/screens/analytics/organizer_analytics_screen.dart';
import '../../features/organizer/screens/auth/market_organizer_comprehensive_signup_screen.dart';
import '../../features/organizer/screens/auth/organizer_onboarding_screen.dart';
import '../../features/organizer/screens/calendar/organizer_calendar_screen.dart';
import '../../features/organizer/screens/organizer_main_screen.dart';
import '../../features/organizer/screens/post_management_screen.dart';
import '../../features/organizer/screens/events/organizer_event_management_screen.dart';
import '../../features/organizer/screens/events/create_event_screen.dart';
import '../../features/organizer/screens/events/edit_event_screen.dart';
import '../../features/organizer/screens/markets/create_market_screen.dart';
import '../../features/organizer/screens/markets/edit_market_screen.dart';
import '../../features/organizer/screens/markets/organizer_market_ratings_screen.dart';
import '../../features/organizer/screens/profile/organizer_edit_profile_screen.dart';
import '../../features/organizer/screens/profile/organizer_profile_screen.dart';
import '../../features/organizer/screens/profile/organizer_detail_screen.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../features/shared/models/event.dart';
import '../../features/shared/services/data/event_service.dart';
// Auth screens
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/auth_landing_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/square_oauth_callback_screen.dart';
// Market screens
import '../../features/market/screens/market_detail_screen.dart';
import '../../features/market/screens/market_management_screen.dart';
// Shopper screens - using organized structure
import '../../features/shopper/screens/shopper_main_screen.dart';
import '../../features/shopper/screens/calendar/shopper_calendar_screen.dart';
import '../../features/shopper/screens/discovery/event_detail_screen.dart';
import '../../features/shopper/screens/profile/shopper_review_history_screen.dart';
// Shared screens
import '../../features/shared/screens/custom_items_screen.dart';
import '../../features/shared/screens/admin_fix_screen.dart';
import '../../features/shared/screens/favorites_screen.dart';
import '../../features/shared/screens/notifications_inbox_screen.dart';
import '../../features/shared/screens/notification_settings_screen.dart';
import '../../features/shared/screens/legal_documents_screen.dart';
import '../../features/shared/screens/help_support_screen.dart';
import '../../features/shared/screens/account_verification_pending_screen.dart';
import '../../features/shared/screens/ceo_verification_dashboard_screen.dart';
import '../../features/ceo/screens/ceo_metrics_dashboard.dart';
import '../../features/ceo/screens/ceo_email_blast_screen.dart';
import '../../features/market/models/market.dart';
import '../../features/shared/screens/reviews/market_reviews_screen.dart';
import '../../features/shared/screens/reviews/my_reviews_screen.dart';
import '../../features/shared/screens/reviews/market_qr_review_flow_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth',
          name: 'auth',
          builder: (context, state) => const AuthLandingScreen(),
        ),
        GoRoute(
          path: '/legal',
          name: 'legal',
          builder: (context, state) => const LegalDocumentsScreen(),
        ),
        GoRoute(
          path: '/support',
          name: 'support',
          builder: (context, state) => const HelpSupportScreen(),
        ),

        // Square OAuth callback route
        GoRoute(
          path: '/oauth/square/callback',
          name: 'squareOAuthCallback',
          builder: (context, state) {
            final code = state.uri.queryParameters['code'];
            final oauthState = state.uri.queryParameters['state'];
            final error = state.uri.queryParameters['error'];
            return SquareOAuthCallbackScreen(
              code: code,
              state: oauthState,
              error: error,
            );
          },
        ),

        // Review routes
        GoRoute(
          path: '/market/:marketId/reviews',
          name: 'market_reviews',
          builder: (context, state) {
            final marketId = state.pathParameters['marketId']!;
            final filter = state.uri.queryParameters['filter'];
            return MarketReviewsScreen(
              marketId: marketId,
              initialFilter: filter,
            );
          },
        ),
        GoRoute(
          path: '/my-reviews',
          name: 'my_reviews',
          builder: (context, state) {
            final type = state.uri.queryParameters['type'];
            return MyReviewsScreen(
              filterType: type,
            );
          },
        ),

        // QR Review Deep Link Route
        GoRoute(
          path: '/review/market/:marketId',
          name: 'qrMarketReview',
          builder: (context, state) {
            final marketId = state.pathParameters['marketId']!;

            // Check auth state
            final authState = authBloc.state;
            if (authState is! Authenticated) {
              // Redirect to login with return path
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/login?type=shopper&returnPath=/review/market/$marketId');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // User is authenticated, show market review screen
            return MarketQRReviewFlowScreen(marketId: marketId);
          },
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) {
            final userType = state.uri.queryParameters['type'] ?? 'shopper';
            return AuthScreen(userType: userType, isLogin: true);
          },
        ),
        GoRoute(
          path: '/forgot-password',
          name: 'forgot-password',
          builder: (context, state) {
            final userType = state.uri.queryParameters['type'];
            return ForgotPasswordScreen(userType: userType);
          },
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) {
            final userType = state.uri.queryParameters['type'] ?? 'shopper';
            if (userType == 'market_organizer') {
              return const MarketOrganizerComprehensiveSignupScreen();
            }
            return AuthScreen(userType: userType, isLogin: false);
          },
        ),
        GoRoute(
          path: '/account-verification-pending',
          name: 'accountVerificationPending',
          builder: (context, state) => const AccountVerificationPendingScreen(),
        ),
        GoRoute(
          path: '/organizer-verification-pending',
          name: 'organizerVerificationPending',
          builder: (context, state) => const AccountVerificationPendingScreen(),
        ),
        GoRoute(
          path: '/ceo-verification-dashboard',
          name: 'ceoVerificationDashboard',
          builder: (context, state) => const CeoVerificationDashboardScreen(),
        ),
        GoRoute(
          path: '/ceo-metrics-dashboard',
          name: 'ceoMetricsDashboard',
          builder: (context, state) => const CEOMetricsDashboard(),
        ),
        GoRoute(
          path: '/ceo-email-blast',
          name: 'ceoEmailBlast',
          builder: (context, state) => const CeoEmailBlastScreen(),
        ),
        GoRoute(
          path: '/shopper',
          name: 'shopper',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final initialTab = extra?['selectedTab'] as int?;
            return ShopperMainScreen(initialTab: initialTab);
          },
          routes: [
            GoRoute(
              path: 'market-detail',
              name: 'marketDetail',
              builder: (context, state) {
                final market = state.extra as Market;
                return MarketDetailScreen(market: market);
              },
            ),
            GoRoute(
              path: 'favorites',
              name: 'favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
            GoRoute(
              path: 'notifications',
              name: 'notificationsInbox',
              builder: (context, state) => const NotificationsInboxScreen(),
            ),
            GoRoute(
              path: 'notification-settings',
              name: 'notificationSettings',
              builder: (context, state) => const NotificationSettingsScreen(),
            ),
            GoRoute(
              path: 'calendar',
              name: 'shopperCalendar',
              builder: (context, state) => const ShopperCalendarScreen(),
            ),
            GoRoute(
              path: 'organizer-detail/:organizerId',
              name: 'organizerDetail',
              builder: (context, state) {
                final organizerId = state.pathParameters['organizerId']!;
                return OrganizerDetailScreen(
                  organizerId: organizerId,
                );
              },
            ),
            GoRoute(
              path: 'event-detail/:eventId',
              name: 'eventDetail',
              builder: (context, state) {
                final eventId = state.pathParameters['eventId']!;
                return EventDetailScreen(eventId: eventId);
              },
            ),
            GoRoute(
              path: 'review-history',
              name: 'shopperReviewHistory',
              builder: (context, state) => const ShopperReviewHistoryScreen(),
            ),
            GoRoute(
              path: 'change-password',
              name: 'shopperChangePassword',
              builder: (context, state) => const ChangePasswordScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/organizer',
          name: 'organizer',
          builder: (context, state) => const OrganizerMainScreen(),
          routes: [
            GoRoute(
              path: 'post-management',
              name: 'postManagement',
              builder: (context, state) => const PostManagementScreen(),
            ),
            GoRoute(
              path: 'market-management',
              name: 'marketManagement',
              builder: (context, state) => const MarketManagementScreen(),
            ),
            GoRoute(
              path: 'create-market',
              name: 'createMarket',
              builder: (context, state) => const CreateMarketScreen(),
            ),
            GoRoute(
              path: 'edit-market/:marketId',
              name: 'editMarket',
              builder: (context, state) {
                final marketId = state.pathParameters['marketId']!;
                return EditMarketScreen(marketId: marketId);
              },
            ),
            GoRoute(
              path: 'market-ratings',
              name: 'organizerMarketRatings',
              builder: (context, state) => const OrganizerMarketRatingsScreen(),
            ),
            GoRoute(
              path: 'event-management',
              name: 'eventManagement',
              builder: (context, state) => const OrganizerEventManagementScreen(),
            ),
            GoRoute(
              path: 'create-event',
              name: 'createEvent',
              builder: (context, state) => const CreateEventScreen(),
            ),
            GoRoute(
              path: 'edit-event/:eventId',
              name: 'editEvent',
              builder: (context, state) {
                final eventId = state.pathParameters['eventId']!;
                return FutureBuilder<Event?>(
                  future: EventService.getEvent(eventId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return Scaffold(
                        appBar: AppBar(title: const Text('Event Not Found')),
                        body: const Center(
                          child: Text('Unable to load event'),
                        ),
                      );
                    }

                    return EditEventScreen(event: snapshot.data!);
                  },
                );
              },
            ),
            GoRoute(
              path: 'custom-items',
              name: 'customItems',
              builder: (context, state) => const CustomItemsScreen(),
            ),
            GoRoute(
              path: 'analytics',
              name: 'analytics',
              builder: (context, state) => const OrganizerAnalyticsScreen(),
            ),
            GoRoute(
              path: 'profile',
              name: 'organizerProfile',
              builder: (context, state) => const OrganizerProfileScreen(),
            ),
            GoRoute(
              path: 'edit-profile',
              name: 'organizerEditProfile',
              builder: (context, state) => const OrganizerEditProfileScreen(),
            ),
            GoRoute(
              path: 'change-password',
              name: 'organizerChangePassword',
              builder: (context, state) => const ChangePasswordScreen(),
            ),
            GoRoute(
              path: 'calendar',
              name: 'organizerCalendar',
              builder: (context, state) => const OrganizerCalendarScreen(),
            ),
            GoRoute(
              path: 'onboarding',
              name: 'organizerOnboarding',
              builder: (context, state) => const OrganizerOnboardingScreen(),
            ),
            if (kDebugMode)
              GoRoute(
                path: 'admin-fix',
                name: 'adminFix',
                builder: (context, state) => const AdminFixScreen(),
              ),
            // 🔒 SECURITY: SubscriptionTestScreen removed for production security
          ],
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        if (authState is Authenticated) {
        }
        
        // If authenticated, redirect based on user type and verification status
        if (authState is Authenticated) {
          final userProfile = authState.userProfile;
          
          // Allow access to CEO dashboard for anyone (it has its own access control)
          if (state.matchedLocation == '/ceo-verification-dashboard') {
            return null;
          }
          
          // Check verification status for market organizers
          if (userProfile != null && userProfile.userType == 'market_organizer') {
            final verificationPendingRoutes = [
              '/account-verification-pending',
              '/organizer-verification-pending'
            ];

            if (!userProfile.isVerified && !verificationPendingRoutes.contains(state.matchedLocation)) {
              // Redirect unverified users to pending screen, unless they're already there
              return '/account-verification-pending';
            }

            if (userProfile.isVerified && verificationPendingRoutes.contains(state.matchedLocation)) {
              // Redirect verified users away from pending screen
              switch (userProfile.userType) {
                case 'market_organizer':
                  return '/organizer';
                default:
                  return '/shopper';
              }
            }
          }
          
          final isAuthRoute = ['/auth', '/login', '/signup', '/forgot-password'].contains(state.matchedLocation);
          if (isAuthRoute) {
            // Check if there's a returnPath in the query parameters
            final returnPath = state.uri.queryParameters['returnPath'];
            if (returnPath != null && returnPath.isNotEmpty) {
              return returnPath;
            }

            // Default navigation based on user type
            switch (authState.userType) {
              case 'market_organizer':
                return '/organizer';
              default:
                return '/shopper';
            }
          }

          // Skip onboarding for organizers and shoppers - they go straight to dashboard
          if ((authState.userType == 'market_organizer' || authState.userType == 'shopper') &&
              state.matchedLocation == '/onboarding') {
            switch (authState.userType) {
              case 'market_organizer':
                return '/organizer';
              case 'shopper':
                return '/shopper';
              default:
                return '/shopper';
            }
          }

          // Prevent wrong user type from accessing wrong routes
          if (authState.userType == 'shopper' &&
              state.matchedLocation.startsWith('/organizer')) {
            return '/shopper';
          }
          // Note: Organizers CAN access /shopper routes - they are shoppers too!
        }
        
        // If email verification required, redirect to auth screen
        if (authState is EmailVerificationRequired) {
          return '/auth';
        }
        
        // If unauthenticated and not on auth routes or public routes, go to auth landing
        if (authState is Unauthenticated) {
          final publicRoutes = [
            '/auth',
            '/login',
            '/signup',
            '/forgot-password',
            '/onboarding',
            '/legal',
            '/account-verification-pending',
            '/organizer-verification-pending',
            '/ceo-verification-dashboard',
            '/ceo-email-blast'
          ];

          if (!publicRoutes.contains(state.matchedLocation)) {
            return '/auth';
          }
        }
        
        return null;
      },
      errorBuilder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF2C2C2E),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.white70,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Page Not Found',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  state.error?.message ?? 'The page you are looking for does not exist',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Route: ${state.matchedLocation}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/auth');
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go('/auth');
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      refreshListenable: GoRouterRefreshStream(authBloc),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(AuthBloc authBloc) {
    authBloc.stream.listen((_) {
      notifyListeners();
    });
  }
}