


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/features/organizer/screens/analytics/organizer_analytics_screen.dart';
import 'package:hipop/features/organizer/screens/auth/market_organizer_comprehensive_signup_screen.dart';
import 'package:hipop/features/organizer/screens/auth/organizer_onboarding_screen.dart';
import 'package:hipop/features/organizer/screens/calendar/organizer_calendar_screen.dart';
import 'package:hipop/features/organizer/screens/dashboard/organizer_premium_dashboard.dart';
import 'package:hipop/features/organizer/screens/organizer_main_screen.dart';
import 'package:hipop/features/organizer/screens/post_management_screen.dart';
import 'package:hipop/features/organizer/screens/events/organizer_event_management_screen.dart';
import 'package:hipop/features/organizer/screens/events/create_event_screen.dart';
import 'package:hipop/features/organizer/screens/events/edit_event_screen.dart';
import 'package:hipop/features/organizer/screens/events/ticket_scanner_screen.dart';
import 'package:hipop/features/organizer/screens/markets/create_market_screen.dart';
import 'package:hipop/features/organizer/screens/markets/edit_market_screen.dart';
import 'package:hipop/features/organizer/screens/markets/organizer_market_ratings_screen.dart';
import 'package:hipop/features/organizer/screens/messaging/organizer_bulk_messaging_screen.dart';
import 'package:hipop/features/organizer/screens/profile/organizer_edit_profile_screen.dart';
import 'package:hipop/features/organizer/screens/profile/organizer_profile_screen.dart';
import 'package:hipop/features/organizer/screens/profile/organizer_detail_screen.dart';
import 'package:hipop/features/organizer/screens/vendors/create_vendor_recruitment_post_screen.dart';
import 'package:hipop/features/organizer/screens/vendors/organizer_vendor_discovery_screen.dart';
import 'package:hipop/features/organizer/screens/vendors/organizer_vendor_posts_screen.dart';
import 'package:hipop/features/organizer/screens/vendors/vendor_post_responses_screen.dart';
import 'package:hipop/features/organizer/screens/vendors/vendor_directory_screen.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../features/shared/models/event.dart';
import '../../features/shared/models/vendor_application.dart';
import '../../features/shared/services/data/event_service.dart';
import '../../repositories/vendor/vendor_posts_repository.dart';
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
import '../../features/tickets/screens/my_tickets_screen.dart';
import '../../features/shopper/screens/my_waitlists_screen.dart';
// Vendor screens
import '../../features/vendor/screens/vendor_main_screen.dart';
import '../../features/vendor/screens/markets/organizer_market_discovery.dart';
import '../../features/vendor/screens/popups/vendor_my_popups_screen.dart';
import '../../features/vendor/screens/profile/vendor_profile_screen.dart';
import '../../features/vendor/screens/profile/vendor_settings_screen.dart';
import '../../features/vendor/screens/popups/vendor_post_detail_screen.dart';
import '../../features/vendor/screens/markets/vendor_applications_screen.dart';
import '../../features/vendor/screens/markets/vendor_application_form.dart';
import '../../features/vendor/screens/auth/vendor_management_screen.dart';
import '../../features/vendor/screens/profile/vendor_detail_screen.dart';
import '../../features/vendor/screens/markets/vendor_application_status_screen.dart';
import '../../features/vendor/screens/popups/popup_creation_type_selector_screen.dart';
import '../../features/vendor/screens/auth/vendor_quick_signup_screen.dart';
import '../../features/vendor/screens/auth/vendor_verification_pending_screen.dart';
import '../../features/auth/screens/phone_verification_screen.dart';
import '../../features/vendor/screens/popups/edit_popup_screen.dart';
import '../../features/vendor/screens/sales/vendor_sales_tracker_screen.dart';
import '../../features/vendor/screens/dashboard/vendor_premium_dashboard.dart';
import '../../features/vendor/screens/qr/vendor_qr_display_screen.dart';
import '../../features/vendor/screens/products_management/vendor_products_management_screen_refactored.dart';
import '../../features/vendor/screens/markets/vendor_market_discovery_optimized.dart';
import '../../features/vendor/screens/markets/vendor_markets_unified_screen.dart';
import '../../features/vendor/screens/markets/select_market_screen.dart';
import '../../features/vendor/screens/reviews/vendor_market_reviews_screen.dart';
import '../../features/vendor/screens/analytics/vendor_comprehensive_analytics_screen.dart';
import '../../features/organizer/screens/reviews/organizer_vendor_reviews_screen.dart';
import '../../features/vendor/screens/waitlist/waitlist_management_screen.dart';
import '../../features/vendor/screens/waitlist/waitlist_overview_screen.dart';
import '../../features/vendor/screens/applications/vendor_applications_list_screen.dart';
import '../../features/vendor/screens/applications/vendor_application_payment_screen.dart';
// Shared screens
import '../../features/vendor/screens/popups/create_popup_screen_refactored.dart';
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
// Payment screens
import '../../features/shopper/screens/checkout/payment_checkout_screen.dart';
import '../../features/shopper/screens/checkout/preorder_checkout_screen.dart';
import '../../features/shopper/screens/checkout/order_confirmation_screen.dart';
import '../../features/shopper/screens/orders/shopper_orders_screen.dart';
// Premium screens
import '../../features/premium/screens/premium_onboarding_screen.dart';
import '../../features/premium/screens/subscription_success_screen.dart';
import '../../features/premium/screens/subscription_cancel_screen.dart';
import '../../features/premium/screens/subscription_management_screen.dart';
import '../../features/market/models/market.dart';
import '../../features/vendor/models/vendor_post.dart';
import '../../features/shared/screens/reviews/vendor_reviews_screen.dart';
import '../../features/shared/screens/reviews/market_reviews_screen.dart';
import '../../features/shared/screens/reviews/my_reviews_screen.dart';
import '../../features/shared/screens/reviews/qr_review_flow_screen.dart';
import '../../features/shared/screens/reviews/market_qr_review_flow_screen.dart';
import '../../features/shared/blocs/application/application_bloc.dart';
import '../../features/shared/services/applications/vendor_application_service.dart';
import '../../features/shared/services/applications/application_payment_service.dart';

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

        // Ticket checkout callback routes
        GoRoute(
          path: '/tickets/success',
          name: 'ticketsSuccess',
          redirect: (context, state) {
            // Redirect to My Tickets screen after successful purchase
            return '/shopper/my-tickets';
          },
        ),
        GoRoute(
          path: '/tickets/cancel',
          name: 'ticketsCancel',
          redirect: (context, state) {
            // Redirect back to shopper home if cancelled
            return '/shopper';
          },
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
          path: '/vendor/:vendorId/reviews',
          name: 'vendor_reviews',
          builder: (context, state) {
            final vendorId = state.pathParameters['vendorId']!;
            final filter = state.uri.queryParameters['filter'];
            return VendorReviewsScreen(
              vendorId: vendorId,
              initialFilter: filter,
            );
          },
        ),
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
          path: '/review/vendor/:vendorId',
          name: 'qrVendorReview',
          builder: (context, state) {
            final vendorId = state.pathParameters['vendorId']!;

            // Check auth state
            final authState = authBloc.state;
            if (authState is! Authenticated) {
              // Redirect to login with return path
              // The router redirect will handle the return after successful auth
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/login?type=shopper&returnPath=/review/vendor/$vendorId');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // User is authenticated, show market selection screen
            return QRReviewFlowScreen(vendorId: vendorId);
          },
        ),
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
            } else if (userType == 'vendor') {
              return const VendorQuickSignupScreen(); // New fast signup!
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
          path: '/phone-verification',
          name: 'phoneVerification',
          builder: (context, state) => const PhoneVerificationScreen(),
        ),
        GoRoute(
          path: '/vendor-verification-pending',
          name: 'vendorVerificationPending',
          builder: (context, state) => const VendorVerificationPendingScreen(),
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
        // Order detail route (for deep linking from emails)
        GoRoute(
          path: '/order/:orderId',
          name: 'orderDetail',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId']!;
            return OrderConfirmationScreen(
              orderId: orderId,
              items: const [], // Will load from Firestore
            );
          },
        ),
        // Orders history route
        GoRoute(
          path: '/orders',
          name: 'orders',
          builder: (context, state) => const ShopperOrdersScreen(),
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
              path: 'vendor-post-detail',
              name: 'vendorPostDetail',
              builder: (context, state) {
                final vendorPost = state.extra as VendorPost;
                return VendorPostDetailScreen(vendorPost: vendorPost);
              },
            ),
            GoRoute(
              path: 'favorites',
              name: 'favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
            GoRoute(
              path: 'waitlists',
              name: 'myWaitlists',
              builder: (context, state) => const MyWaitlistsScreen(),
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
              path: 'checkout',
              name: 'checkout',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>?;
                if (args == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('Error: Missing checkout data'),
                    ),
                  );
                }
                // Use new preorder checkout for single product
                if (args.containsKey('product')) {
                  return PreorderCheckoutScreen(
                    product: args['product'],
                    vendorId: args['vendorId'],
                    vendorName: args['vendorName'],
                    popupId: args['popupId'],
                    popupLocation: args['popupLocation'],
                    popupStartTime: args['popupStartTime'],
                    popupEndTime: args['popupEndTime'],
                  );
                }
                // Legacy basket checkout (will be removed)
                return PaymentCheckoutScreen(
                  items: args['items'],
                  marketId: args['marketId'],
                  marketName: args['marketName'],
                  vendorId: args['vendorId'],
                  vendorName: args['vendorName'],
                );
              },
            ),
            GoRoute(
              path: 'order-confirmation',
              name: 'orderConfirmation',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>?;
                if (args == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('Error: Missing order data'),
                    ),
                  );
                }
                return OrderConfirmationScreen(
                  orderId: args['orderId'],
                  items: args['items'],
                );
              },
            ),
            GoRoute(
              path: 'vendor-detail/:vendorId',
              name: 'vendorDetail',
              builder: (context, state) {
                final vendorId = state.pathParameters['vendorId']!;
                // Extract popup location from query parameters if available
                final popupLocation = state.uri.queryParameters['popupLocation'];
                final popupLatitudeStr = state.uri.queryParameters['popupLatitude'];
                final popupLongitudeStr = state.uri.queryParameters['popupLongitude'];
                
                final popupLatitude = popupLatitudeStr != null 
                    ? double.tryParse(popupLatitudeStr) 
                    : null;
                final popupLongitude = popupLongitudeStr != null 
                    ? double.tryParse(popupLongitudeStr) 
                    : null;
                
                return VendorDetailScreen(
                  vendorId: vendorId,
                  popupLocation: popupLocation,
                  popupLatitude: popupLatitude,
                  popupLongitude: popupLongitude,
                );
              },
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
              path: 'my-tickets',
              name: 'myTickets',
              builder: (context, state) => const MyTicketsScreen(),
            ),
            GoRoute(
              path: 'change-password',
              name: 'shopperChangePassword',
              builder: (context, state) => const ChangePasswordScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/vendor',
          name: 'vendor',
          builder: (context, state) => const VendorMainScreen(),
          routes: [
            GoRoute(
              path: 'organizer-discovery',
              builder: (context, state) => const OrganizerMarketDiscovery(),
            ),
            GoRoute(
              path: 'market-reviews',
              builder: (context, state) => const VendorMarketReviewsScreen(),
            ),
            GoRoute(
              path: 'create-popup',
              name: 'createPopup',
              builder: (context, state) {
                // Extract marketId from query parameters
                final marketId = state.uri.queryParameters['marketId'];
                return CreatePopupScreenRefactored(
                  postsRepository: context.read<IVendorPostsRepository>(),
                  marketId: marketId, // Pass marketId to the screen
                );
              },
            ),
            GoRoute(
              path: 'my-popups',
              name: 'myPopups',
              builder: (context, state) => const VendorMyPopupsScreen(),
            ),
            GoRoute(
              path: 'profile',
              name: 'vendorProfile',
              builder: (context, state) => const VendorProfileScreen(),
            ),
            GoRoute(
              path: 'change-password',
              name: 'changePassword',
              builder: (context, state) => const ChangePasswordScreen(),
            ),
            GoRoute(
              path: 'popup-creation',
              name: 'vendorPopupCreation',
              builder: (context, state) => const PopupCreationTypeSelectorScreen(),
            ),
            GoRoute(
              path: 'edit-popup',
              name: 'editPopup',
              builder: (context, state) {
                final vendorPost = state.extra as VendorPost;
                return EditPopupScreen(vendorPost: vendorPost);
              },
            ),
            GoRoute(
              path: 'sales-tracker',
              name: 'vendorSalesTracker',
              builder: (context, state) => const VendorSalesTrackerScreen(),
            ),
            GoRoute(
              path: 'premium-dashboard',
              name: 'vendorPremiumDashboard',
              builder: (context, state) => const VendorPremiumDashboard(),
            ),
            GoRoute(
              path: 'market-discovery',
              name: 'vendorMarketDiscovery',
              builder: (context, state) => const VendorMarketDiscoveryOptimized(),
            ),
            GoRoute(
              path: 'markets',
              name: 'vendor_markets',
              builder: (context, state) => const VendorMarketsUnifiedScreen(),
            ),
            GoRoute(
              path: 'analytics',
              name: 'vendorAnalytics',
              builder: (context, state) => const VendorComprehensiveAnalyticsScreen(),
            ),
            GoRoute(
              path: 'products-management',
              name: 'vendorProductsManagement',
              builder: (context, state) => const VendorProductsManagementScreen(),
            ),
            GoRoute(
              path: 'select-market',
              name: 'selectMarket',
              builder: (context, state) => const SelectMarketScreen(),
            ),
            GoRoute(
              path: 'settings',
              name: 'vendorSettings',
              builder: (context, state) => const VendorSettingsScreen(),
            ),
            GoRoute(
              path: 'qr-code',
              name: 'vendorQRCode',
              builder: (context, state) => const VendorQRDisplayScreen(),
            ),
            GoRoute(
              path: 'waitlist-management',
              name: 'vendorWaitlistManagement',
              builder: (context, state) => const WaitlistOverviewScreen(),
              routes: [
                GoRoute(
                  path: ':productId',
                  name: 'vendorWaitlistProduct',
                  builder: (context, state) {
                    final productId = state.pathParameters['productId']!;
                    final extra = state.extra as Map<String, dynamic>?;

                    return WaitlistManagementScreen(
                      productId: productId,
                      productName: extra?['productName'] ?? 'Product',
                      popupId: extra?['popupId'] ?? '',
                      vendorId: extra?['vendorId'] ?? '',
                    );
                  },
                ),
              ],
            ),
            // Vendor Applications Routes
            GoRoute(
              path: 'applications',
              name: 'vendorApplications',
              builder: (context, state) => BlocProvider(
                create: (context) => ApplicationBloc(
                  applicationService: VendorApplicationService(),
                  paymentService: ApplicationPaymentService(),
                ),
                child: const VendorApplicationsListScreen(),
              ),
              routes: [
                GoRoute(
                  path: ':applicationId/payment',
                  name: 'vendorApplicationPayment',
                  builder: (context, state) {
                    final applicationId = state.pathParameters['applicationId']!;
                    final application = state.extra as VendorApplication;
                    return VendorApplicationPaymentScreen(
                      applicationId: applicationId,
                      application: application,
                    );
                  },
                ),
              ],
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
              path: 'vendor-reviews',
              name: 'organizerVendorReviews',
              builder: (context, state) => const OrganizerVendorReviewsScreen(),
            ),
            GoRoute(
              path: 'vendor-management',
              name: 'vendorManagement',
              builder: (context, state) {
                final marketId = state.uri.queryParameters['marketId'];
                return VendorManagementScreen(marketId: marketId);
              },
            ),
            GoRoute(
              path: 'vendor-applications',
              name: 'organizerVendorApplications',
              builder: (context, state) => const VendorApplicationsScreen(),
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
              path: 'ticket-scanner/:eventId',
              name: 'ticketScanner',
              builder: (context, state) {
                final eventId = state.pathParameters['eventId']!;
                final eventTitle = state.uri.queryParameters['title'] ?? 'Event';
                return TicketScannerScreen(
                  eventId: eventId,
                  eventTitle: eventTitle,
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
            GoRoute(
              path: 'premium-dashboard',
              name: 'organizerPremiumDashboard',
              builder: (context, state) {
                // Allow all organizers to access - the screen itself handles upgrade vs premium content
                return const OrganizerPremiumDashboard();
              },
            ),
            GoRoute(
              path: 'vendor-recruitment/create',
              name: 'createVendorRecruitment',
              builder: (context, state) => const CreateVendorRecruitmentPostScreen(),
            ),
            GoRoute(
              path: 'vendor-discovery',
              name: 'organizerVendorDiscovery',
              builder: (context, state) => const OrganizerVendorDiscoveryScreen(),
            ),
            GoRoute(
              path: 'vendor-communications',
              name: 'organizerVendorCommunications',
              builder: (context, state) => const OrganizerBulkMessagingScreen(),
            ),
            GoRoute(
              path: 'vendor-posts',
              name: 'organizerVendorPosts',
              builder: (context, state) => const OrganizerVendorPostsScreen(),
            ),
            // Routes for vendor recruitment posts
            GoRoute(
              path: 'vendors/posts/:postId',
              name: 'organizerVendorPostDetail',
              builder: (context, state) {
                final postId = state.pathParameters['postId']!;
                return VendorPostResponsesScreen(postId: postId);
              },
            ),
            GoRoute(
              path: 'vendor-directory',
              name: 'vendorDirectory',
              builder: (context, state) {
                // Market info can be passed via extra if needed
                return const VendorDirectoryScreen();
              },
              routes: [
                GoRoute(
                  path: ':postId/edit',
                  name: 'editOrganizerVendorPost',
                  builder: (context, state) {
                    // final postId = state.pathParameters['postId']!;
                    // TODO: Pass postId to CreateVendorRecruitmentPostScreen for editing
                    return const CreateVendorRecruitmentPostScreen();
                  },
                ),
                GoRoute(
                  path: ':postId/responses',
                  name: 'organizerVendorPostResponses',
                  builder: (context, state) {
                    final postId = state.pathParameters['postId']!;
                    return VendorPostResponsesScreen(postId: postId);
                  },
                ),
              ],
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
        // Vendor application form (in-app applications)
        GoRoute(
          path: '/vendor/apply/:marketId',
          name: 'vendorApplication',
          builder: (context, state) {
            final marketId = state.pathParameters['marketId']!;
            return VendorApplicationForm(
              marketId: marketId,
            );
          },
        ),
        
        
        // Premium onboarding route
        GoRoute(
          path: '/premium/onboarding',
          name: 'premiumOnboarding',
          builder: (context, state) {
            final userId = state.uri.queryParameters['userId'] ?? '';
            final userType = state.uri.queryParameters['userType'] ?? 'vendor';
            
            if (userId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: User ID is required for premium onboarding'),
                ),
              );
            }
            
            return PremiumOnboardingScreen(
              userId: userId,
              userType: userType,
            );
          },
        ),
        // Subscription success route
        GoRoute(
          path: '/subscription/success',
          name: 'subscriptionSuccess',
          builder: (context, state) {
            final sessionId = state.uri.queryParameters['session_id'] ?? '';
            final userId = state.uri.queryParameters['user_id'] ?? '';
            
            
            if (sessionId.isEmpty || userId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: Missing subscription parameters'),
                ),
              );
            }
            
            return SubscriptionSuccessScreen(
              sessionId: sessionId,
              userId: userId,
            );
          },
        ),
        
        // Subscription cancel route
        GoRoute(
          path: '/subscription/cancel',
          name: 'subscriptionCancel',
          builder: (context, state) {
            final reason = state.uri.queryParameters['reason'];
            
            
            return SubscriptionCancelScreen(reason: reason);
          },
        ),
        
        // Subscription management route
        GoRoute(
          path: '/subscription-management/:userId',
          name: 'subscriptionManagement',
          builder: (context, state) {
            final userId = state.pathParameters['userId'] ?? '';
            return SubscriptionManagementScreen(userId: userId);
          },
        ),
        
        // Backward compatible subscription management route (redirects to parameterized version)
        GoRoute(
          path: '/subscription/management',
          name: 'subscriptionManagementCompat',
          builder: (context, state) {
            final authBloc = context.read<AuthBloc>();
            final authState = authBloc.state;
            if (authState is Authenticated) {
              // Redirect to the proper route with userId
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/subscription-management/${authState.user.uid}');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            } else {
              return const Scaffold(
                body: Center(
                  child: Text('Please log in to access subscription management'),
                ),
              );
            }
          },
        ),
        
        // Premium upgrade route (handles upgrade flow)
        GoRoute(
          path: '/premium/upgrade',
          name: 'premiumUpgrade',
          builder: (context, state) {
            final targetTier = state.uri.queryParameters['tier'];
            final userId = state.uri.queryParameters['userId'];
            
            
            // Get userId from query params or auth context
            String? effectiveUserId = userId;
            if (effectiveUserId == null || effectiveUserId.isEmpty) {
              final authBloc = context.read<AuthBloc>();
              final authState = authBloc.state;
              if (authState is Authenticated) {
                effectiveUserId = authState.user.uid;
              }
            }
            
            if (effectiveUserId == null || effectiveUserId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: User ID is required for premium upgrade'),
                ),
              );
            }
            
            // Map tier to actual user type
            String userType = 'vendor'; // default to vendor since most users upgrading are vendors
            if (targetTier == 'marketOrganizerPremium' || targetTier == 'market_organizer' || targetTier == 'organizer') {
              userType = 'market_organizer';
            } else if (targetTier == 'vendorPremium' || targetTier == 'vendor') {
              userType = 'vendor';
            } else if (targetTier == 'shopperPremium' || targetTier == 'shopper') {
              userType = 'shopper';
            }
            
            
            return PremiumOnboardingScreen(
              userId: effectiveUserId,
              userType: userType,
            );
          },
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
          
          // Check verification status for vendors and market organizers
          if (userProfile != null && (userProfile.userType == 'vendor' || userProfile.userType == 'market_organizer')) {
            final verificationPendingRoutes = [
              '/account-verification-pending',
              '/vendor-verification-pending', 
              '/organizer-verification-pending'
            ];
            
            if (!userProfile.isVerified && !verificationPendingRoutes.contains(state.matchedLocation)) {
              // Redirect unverified users to pending screen, unless they're already there
              return '/account-verification-pending';
            }
            
            if (userProfile.isVerified && verificationPendingRoutes.contains(state.matchedLocation)) {
              // Redirect verified users away from pending screen
              switch (userProfile.userType) {
                case 'vendor':
                  return '/vendor';
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
              case 'vendor':
                return '/vendor';
              case 'market_organizer':
                return '/organizer';
              default:
                return '/shopper';
            }
          }
          
          // Skip onboarding for vendors, organizers, and shoppers - they go straight to dashboard
          if ((authState.userType == 'vendor' || authState.userType == 'market_organizer' || authState.userType == 'shopper') && 
              state.matchedLocation == '/onboarding') {
            switch (authState.userType) {
              case 'vendor':
                return '/vendor';
              case 'market_organizer':
                return '/organizer';
              case 'shopper':
                return '/shopper';
              default:
                return '/shopper';
            }
          }
          
          // Prevent wrong user type from accessing wrong routes
          // EXCEPTION: Allow vendors and organizers to access /shopper (shopping experience)
          if (authState.userType == 'vendor' && 
              state.matchedLocation.startsWith('/organizer')) {
            return '/vendor';
          }
          if (authState.userType == 'market_organizer' && 
              state.matchedLocation.startsWith('/vendor')) {
            return '/organizer';
          }
          if (authState.userType == 'shopper' && 
              (state.matchedLocation.startsWith('/vendor') || state.matchedLocation.startsWith('/organizer'))) {
            return '/shopper';
          }
          // Note: Vendors and organizers CAN access /shopper routes - they are shoppers too!
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
            '/vendor-verification-pending',
            '/organizer-verification-pending',
            '/phone-verification',
            '/ceo-verification-dashboard',
            '/ceo-email-blast'
          ];
          final isVendorApplication = state.matchedLocation.startsWith('/apply/');
          
          if (!publicRoutes.contains(state.matchedLocation) && !isVendorApplication) {
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