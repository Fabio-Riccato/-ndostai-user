import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/circle_onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/circle/trip_history_screen.dart';
import '../screens/driving/driving_report_screen.dart';
import '../../data/repositories/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Usiamo un notifier listenable per trigger i redirect GoRouter
  final routerNotifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final authenticated = ref.read(authProvider).isAuthenticated;
      final loading       = ref.read(authProvider).loading;
      final loc           = state.matchedLocation;

      // Non redirigere durante il loading o sulla splash
      if (loading || loc == '/splash') return null;

      final onPublicRoute = loc == '/login' || loc == '/register';

      // Non autenticato → manda al login (solo se non è già lì)
      if (!authenticated && !onPublicRoute) return '/login';

      // Autenticato → non lasciare sulla schermata di login/register
      // (la navigazione esplicita in login_screen gestisce /home e /onboarding)
      if (authenticated && onPublicRoute) return null; // lascia che sia lo screen a navigare

      return null;
    },
    routes: [
      GoRoute(path: '/splash',     builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',      builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register',   builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const CircleOnboardingScreen()),
      GoRoute(path: '/home',       builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/settings',   builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/trips/:userId',
        builder: (_, state) => TripHistoryScreen(
          userId:   state.pathParameters['userId']!,
          circleId: state.uri.queryParameters['circleId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/driving/:circleId',
        builder: (_, state) => DrivingReportScreen(
          circleId: state.pathParameters['circleId']!,
        ),
      ),
    ],
  );
});

/// Notifica GoRouter quando lo stato auth cambia
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
