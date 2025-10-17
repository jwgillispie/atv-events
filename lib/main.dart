import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'core/theme/atv_theme.dart';
import 'repositories/auth/auth_repository.dart';
// TODO: Removed for ATV MVP - import 'repositories/vendor/vendor_posts_repository.dart';
import 'repositories/shopper/favorites_repository.dart';
import 'repositories/organizer/organizer_profile_repository.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/favorites/favorites_bloc.dart';
import 'features/organizer/blocs/profile/organizer_profile_bloc.dart';
import 'features/shopper/blocs/shopper_feed/shopper_feed_bloc.dart';
import 'features/shopper/blocs/enhanced_map/enhanced_map_bloc.dart';
import 'features/shopper/blocs/product_feed/product_feed_bloc.dart';
import 'features/shopper/blocs/basket/basket_bloc.dart';
import 'features/shopper/blocs/basket/basket_event.dart';
import 'features/shopper/services/product_reservation_service.dart';
import 'features/shared/services/data/cache_service.dart';
import 'core/routing/app_router.dart';
import 'features/shared/services/utilities/remote_config_service.dart';
import 'features/shared/services/analytics/real_time_analytics_service.dart';
import 'features/shared/services/push_notification_service.dart';
import 'core/utils/timezone_utils.dart';
import 'features/shared/services/theme_preferences_service.dart';
import 'features/shared/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await _initializeApp();
    runApp(const ATVEventsApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

Future<void> _initializeApp() async {
  try {
    // Initialize Firebase
    await _initializeFirebase();

    // Initialize timezone utilities for Eastern Time handling
    await TimezoneUtils.initialize();

    // Initialize Remote Config
    try {
      await RemoteConfigService.instance;
    } catch (e) {
      debugPrint('RemoteConfig initialization failed: $e');
    }

    // Initialize Analytics with consent
    await _initializeAnalytics();

    // Initialize Push Notifications
    await _initializePushNotifications();
  } catch (e) {
    // Continue with app startup even if some services fail
    debugPrint('App initialization warning: $e');
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      // Firebase already initialized, which is fine
      return;
    }
    rethrow;
  }
}

Future<void> _initializeAnalytics() async {
  try {
    // Initialize analytics service and request consent
    await RealTimeAnalyticsService.initialize();
    await RealTimeAnalyticsService.requestTrackingConsent();
  } catch (e) {
    // Continue without analytics rather than crash the app
    debugPrint('Analytics initialization failed: $e');
  }
}

Future<void> _initializePushNotifications() async {
  try {
    // Initialize push notification service
    // Note: We don't pass router here as it's not created yet
    // The router will be passed when the app widget builds
    // Timezone is already initialized at this point for Eastern Time handling
    final notificationService = PushNotificationService();
    await notificationService.initialize();
  } catch (e) {
    // Continue without push notifications rather than crash the app
    debugPrint('Push notifications initialization failed: $e');
  }
}

class ATVEventsApp extends StatefulWidget {
  const ATVEventsApp({super.key});

  @override
  State<ATVEventsApp> createState() => _ATVEventsAppState();
}

class _ATVEventsAppState extends State<ATVEventsApp> {
  late GoRouter _router;
  final PushNotificationService _notificationService = PushNotificationService();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    // Router will be initialized in build method where we have access to AuthBloc
  }

  Future<void> _loadThemePreference() async {
    final mode = await ThemePreferencesService.getThemeMode();
    if (mounted) {
      setState(() {
        _themeMode = mode;
      });
    }
  }

  void _updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    ThemePreferencesService.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IAuthRepository>(
          create: (context) => AuthRepository(),
        ),
        // TODO: Removed for ATV MVP - RepositoryProvider<IVendorPostsRepository>
        RepositoryProvider<FavoritesRepository>(
          create: (context) => FavoritesRepository(),
        ),
        RepositoryProvider<IOrganizerProfileRepository>(
          create: (context) => OrganizerProfileRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<IAuthRepository>(),
            )..add(AuthStarted()),
          ),
          BlocProvider<FavoritesBloc>(
            create: (context) => FavoritesBloc(
              favoritesRepository: context.read<FavoritesRepository>(),
            ),
          ),
          BlocProvider<OrganizerProfileBloc>(
            create: (context) => OrganizerProfileBloc(
              repository: context.read<IOrganizerProfileRepository>(),
              authBloc: context.read<AuthBloc>(),
            ),
          ),
          // TODO: Removed for ATV MVP - ShopperFeedBloc needs vendor posts repository
          // BlocProvider<ShopperFeedBloc>(
          //   create: (context) => ShopperFeedBloc(
          //     vendorPostsRepository: context.read<IVendorPostsRepository>(),
          //     cacheService: CacheService(),
          //   ),
          // ),
          BlocProvider<BasketBloc>(
            create: (context) {
              // Get userId from AuthBloc if available
              final authState = context.read<AuthBloc>().state;
              final userId = authState is Authenticated ? authState.user.uid : null;

              return BasketBloc(
                reservationService: ProductReservationService(),
                userId: userId,
              );
            },
          ),
          BlocProvider<EnhancedMapBloc>(
            create: (context) => EnhancedMapBloc(),
          ),
          BlocProvider<ProductFeedBloc>(
            create: (context) => ProductFeedBloc(),
          ),
        ],
        child: Builder(
          builder: (context) {
            final authBloc = context.read<AuthBloc>();
            // Create router
            _router = AppRouter.createRouter(authBloc);
            // Initialize notification service with router
            _notificationService.initialize(router: _router);
            
            return BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                // Automatically reload favorites and basket when auth state changes
                if (state is Authenticated) {
                  context.read<FavoritesBloc>().add(LoadFavorites(userId: state.user.uid));
                  // Reload basket with user ID - need to recreate BasketBloc with userId
                  // This will be handled by rebuilding the BlocProvider
                } else if (state is Unauthenticated) {
                  context.read<FavoritesBloc>().add(const LoadFavorites());
                  // Clear basket when logged out
                  context.read<BasketBloc>().add(ClearBasket());
                }
              },
              child: ThemeProvider(
                themeMode: _themeMode,
                updateThemeMode: _updateThemeMode,
                child: MaterialApp.router(
                  title: 'ATV Events',
                  debugShowCheckedModeBanner: false,
                  theme: ATVTheme.lightTheme,
                  darkTheme: ATVTheme.darkTheme,
                  themeMode: _themeMode,
                // builder: (context, child) {
                //   return Banner(
                //     message: 'STAGING',
                //     location: BannerLocation.topStart,
                //     color: Colors.pink,
                //     textStyle: const TextStyle(
                //       color: Colors.white,
                //       fontSize: 12,
                //       fontWeight: FontWeight.bold,
                //     ),
                //     child: child!,
                //   );
                // },
                  routerConfig: _router,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ATV Events - Error',
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.red, Colors.redAccent],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to initialize the app: $error',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      main();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}