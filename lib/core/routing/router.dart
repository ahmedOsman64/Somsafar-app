import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/login_screen.dart';
import '../../auth/signup_screen.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/models/user_model.dart';
import '../../traveler/widgets/traveler_shell.dart';
import '../../provider/widgets/provider_shell.dart';
import '../../admin/widgets/admin_shell.dart';
import '../../shared/services/settings_repository.dart';
import '../../auth/onboarding_screen.dart';
import '../../auth/splash_screen.dart';
import '../../auth/forgot_password_screen.dart';
import '../../auth/reset_password_screen.dart';

// Screens
import '../../traveler/screens/home_screen.dart';
import '../../traveler/screens/search/search_screen.dart';
import '../../traveler/screens/bookings_screen.dart';
import '../../traveler/screens/profile_screen.dart';
import '../../traveler/screens/service_details_screen.dart';
import '../../shared/screens/notification_screen.dart';

import '../../provider/screens/dashboard_screen.dart';
import '../../provider/screens/services_list_screen.dart';
import '../../provider/screens/bookings_screen.dart';
import '../../provider/screens/discounts_screen.dart';
import '../../provider/screens/reports_screen.dart';
import '../../provider/screens/reviews_screen.dart';
import '../../provider/screens/profile_screen.dart';
import '../../provider/screens/settings_screen.dart';

import '../../admin/screens/dashboard_screen.dart';
import '../../admin/screens/users_screen.dart';
import '../../admin/screens/services_screen.dart';
import '../../admin/screens/financials_screen.dart';
import '../../admin/screens/support_screen.dart';
import '../../admin/screens/settings_screen.dart';
import '../../admin/screens/create_user_screen.dart';
import '../../admin/screens/admin_profile_screen.dart';
import '../../admin/screens/admin_banner_manager_screen.dart';
import '../../admin/screens/admin_bookings_screen.dart';
import '../../admin/screens/admin_reviews_screen.dart';
import '../../admin/screens/admin_logs_screen.dart';
import '../../admin/screens/admin_special_offers_screen.dart';
import '../../admin/screens/admin_taxes_screen.dart';
import '../../admin/screens/admin_security_screen.dart';
import '../../admin/screens/edit_user_screen.dart';
import '../../admin/screens/admin_helpers_screen.dart';
import '../../admin/screens/admin_region_manager_screen.dart';
import '../../admin/screens/admin_highlights_screen.dart';
import '../../admin/screens/admin_discounts_screen.dart';

import '../../provider/screens/provider_service_form_screen.dart';

// Booking Forms
import '../../traveler/screens/booking/hotel_booking_form.dart';
import '../../traveler/screens/booking/apartment_booking_form.dart';
import '../../traveler/screens/booking/tour_booking_form.dart';
import '../../shared/models/booking_forms_model.dart';
import '../../traveler/screens/booking/vehicle_booking_form.dart';
import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authServiceProvider);
  final refreshListenable = RouterRefreshListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = authNotifier.state;
      final isLoggedIn = authState != null;
      final settings = ref.read(settingsProvider);
      final hasSeenOnboarding = settings.hasSeenOnboarding;
      final path = state.uri.path;
      
      if (!authNotifier.initialized || !settings.initialized) {
        return null; // Wait for both services to initialize
      }

      // If hasn't seen onboarding, redirect there
      if (!hasSeenOnboarding && path != '/onboarding') {
        return '/onboarding';
      }

      if (!isLoggedIn) {
        // Paths allowed while logged out
        final publicPaths = {
          '/login',
          '/signup',
          '/forgot-password',
          '/reset-password',
          '/onboarding',
          '/splash',
        };
        final isPublic = publicPaths.contains(path);

        if (isPublic) return null;
        return '/login';
      }

      // If logged in and at public entry points, redirect to dashboard
      final authEntryPaths = {'/login', '/signup', '/splash'};
      if (authEntryPaths.contains(path)) {
        switch (authState.role) {
          case UserRole.traveler:
            return '/traveler/home';
          case UserRole.provider:
          case UserRole.providerHelper:
            return '/provider/dashboard';
          case UserRole.admin:
            return '/admin/dashboard';
        }
      }

      // Strict Role Guards & Hierarchy
      if (authState.role == UserRole.traveler) {
        if (path.startsWith('/provider') || path.startsWith('/admin')) {
          return '/access-denied';
        }
      } else if (authState.role == UserRole.provider || authState.role == UserRole.providerHelper) {
        if (path.startsWith('/traveler') || path.startsWith('/admin')) {
          return '/access-denied';
        }
      } else if (authState.role == UserRole.admin) {
        // Admin sub-role granular access
        final adminRole = authState.adminRole ?? AdminRole.superAdmin;

        if (adminRole == AdminRole.opsAdmin) {
          if (path.startsWith('/admin/financials') ||
              path.startsWith('/admin/settings')) {
            return '/access-denied';
          }
        } else if (adminRole == AdminRole.financeAdmin) {
          if (path.startsWith('/admin/users') ||
              path.startsWith('/admin/services') ||
              path.startsWith('/admin/support') ||
              path.startsWith('/admin/settings')) {
            return '/access-denied';
          }
        } else if (adminRole == AdminRole.supportAdmin) {
          if (path.startsWith('/admin/users') ||
              path.startsWith('/admin/financials') ||
              path.startsWith('/admin/settings')) {
            return '/access-denied';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (_, __) => '/login',
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/access-denied',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  '❌ Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('You do not have permission to access this page.'),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    final container = ProviderScope.containerOf(context);
                    final auth = container.read(authProvider);
                    if (auth == null) {
                      context.go('/login');
                    } else {
                      switch (auth.role) {
                        case UserRole.traveler:
                          context.go('/traveler/home');
                          break;
                        case UserRole.provider:
                        case UserRole.providerHelper:
                          context.go('/provider/dashboard');
                          break;
                        case UserRole.admin:
                          context.go('/admin/dashboard');
                          break;
                      }
                    }
                  },
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      ),

      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(email: state.extra as String? ?? ''),
      ),

      // Traveler Routes
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => 
            TravelerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/traveler/home',
                builder: (context, state) => const TravelerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/traveler/search',
                builder: (context, state) {
                  final category = state.uri.queryParameters['category'];
                  return TravelerSearchScreen(category: category);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/traveler/bookings',
                builder: (context, state) => const TravelerBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/traveler/profile',
                builder: (context, state) => const TravelerProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/traveler/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/traveler/booking',
        redirect: (context, state) => '/traveler/home',
      ),

      GoRoute(
        path: '/traveler/booking/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          Service? service;

          if (state.extra is Service) {
            service = state.extra as Service;
          } else {
            // Fallback: search in repository using the live context container
            try {
              final container = ProviderScope.containerOf(context);
              final services = container.read(serviceProvider);
              service = services.firstWhere((s) => s.id == id);
            } catch (_) {
              return const Scaffold(
                body: Center(child: Text('Service not found')),
              );
            }
          }

          final category = service.category.toLowerCase();

          if (category == 'hotel') {
            return HotelBookingForm(service: service);
          } else if (category == 'apartment' || category == 'home') {
            return ApartmentBookingForm(service: service);
          } else if (category == 'tour' || category == 'tours') {
            TourPackage package = TourPackage.jumma;
            if (state.extra is TourPackage) {
              package = state.extra as TourPackage;
            } else if (service.metadata['package'] != null) {
              final packageStr = service.metadata['package'] as String;
              package = TourPackage.values.firstWhere(
                (e) => e.name == packageStr,
                orElse: () => TourPackage.jumma,
              );
            }

            return TourBookingForm(
              service: service,
              initialPackage: package,
            );
          } else if (category == 'transport') {
            return VehicleBookingForm(service: service);
          }

          // Default fallback
          return HotelBookingForm(service: service);
        },
      ),
      GoRoute(
        path: '/traveler/service/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ServiceDetailsScreen(serviceId: state.pathParameters['id']!),
      ),

      // Provider Routes
      ShellRoute(
        builder: (context, state, child) => ProviderShell(child: child),
        routes: [
          GoRoute(
            path: '/provider/dashboard',
            builder: (context, state) => const ProviderDashboardScreen(),
          ),
          GoRoute(
            path: '/provider/services',
            builder: (context, state) => const ProviderServicesScreen(),
          ),
          GoRoute(
            path: '/provider/bookings',
            builder: (context, state) => const ProviderBookingsScreen(),
          ),
          GoRoute(
            path: '/provider/discounts',
            builder: (context, state) => const ProviderDiscountsScreen(),
          ),
          GoRoute(
            path: '/provider/reports',
            builder: (context, state) => const ProviderReportsScreen(),
          ),
          GoRoute(
            path: '/provider/reviews',
            builder: (context, state) => const ProviderReviewsScreen(),
          ),
          GoRoute(
            path: '/provider/profile',
            builder: (context, state) => const ProviderProfileScreen(),
          ),
          GoRoute(
            path: '/provider/settings',
            builder: (context, state) => const ProviderSettingsScreen(),
          ),
          GoRoute(
            path: '/provider/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/provider/services/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProviderServiceFormScreen(),
      ),
      GoRoute(
        path: '/provider/services/edit',
        redirect: (context, state) => '/provider/services',
      ),
      GoRoute(
        path: '/provider/services/edit/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ProviderServiceFormScreen(serviceId: state.pathParameters['id']),
      ),

      // Admin Routes
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/services',
            builder: (context, state) => const AdminServicesScreen(),
          ),
          GoRoute(
            path: '/admin/financials',
            builder: (context, state) => const AdminFinancialsScreen(),
          ),
          GoRoute(
            path: '/admin/support',
            builder: (context, state) => const AdminSupportScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (context, state) => const AdminProfileScreen(),
          ),
          GoRoute(
            path: '/admin/banners',
            builder: (context, state) => const AdminBannerManagerScreen(),
          ),
          GoRoute(
            path: '/admin/bookings',
            builder: (context, state) => const AdminBookingsScreen(),
          ),
          GoRoute(
            path: '/admin/reviews',
            builder: (context, state) => const AdminReviewsScreen(),
          ),
          GoRoute(
            path: '/admin/special-offers',
            builder: (context, state) => const AdminSpecialOffersScreen(),
          ),
          GoRoute(
            path: '/admin/logs',
            builder: (context, state) => const AdminLogsScreen(),
          ),
          GoRoute(
            path: '/admin/security',
            builder: (context, state) => const AdminSecurityScreen(),
          ),
          GoRoute(
            path: '/admin/taxes',
            builder: (context, state) => const AdminTaxesScreen(),
          ),
          GoRoute(
            path: '/admin/helpers',
            builder: (context, state) => const AdminHelpersScreen(),
          ),
          GoRoute(
            path: '/admin/regions',
            builder: (context, state) => const AdminRegionManagerScreen(),
          ),
          GoRoute(
            path: '/admin/highlights',
            builder: (context, state) => const AdminHighlightsScreen(),
          ),
          GoRoute(
            path: '/admin/discounts',
            builder: (context, state) => const AdminDiscountsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/users/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final role = state.uri.queryParameters['role'];
          return AdminCreateProviderScreen(initialRole: role);
        },
      ),
      GoRoute(
        path: '/admin/users/edit/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final user = state.extra as User;
          return AdminEditUserScreen(user: user);
        },
      ),
    ],
  );
});

/// A [Listenable] that combines multiple providers to trigger GoRouter redirects.
class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(Ref ref) {
    // Listen to auth changes
    ref.listen(authServiceProvider, (previous, next) {
      notifyListeners();
    });
    
    // Listen to settings changes (especially the 'initialized' flag)
    ref.listen(settingsProvider, (previous, next) {
      if (previous?.initialized != next.initialized || 
          previous?.hasSeenOnboarding != next.hasSeenOnboarding) {
        notifyListeners();
      }
    });
  }
}
