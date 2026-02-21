import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/incidents/incident_detail_screen.dart';
import '../features/incidents/incidents_list_screen.dart';
import '../features/my_items/my_items_screen.dart';

/// Centralized route definitions and auth guard behavior.
class AppRouter {
  AppRouter._();

  /// Builds the app router.
  ///
  /// Redirect rules:
  /// - Anonymous users can only access `/login`.
  /// - Authenticated users are redirected away from `/login`.
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/incidents',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final atLogin = state.matchedLocation == '/login';

        if (!isAuthenticated && !atLogin) {
          return '/login';
        }
        if (isAuthenticated && atLogin) {
          return '/incidents';
        }
        return null;
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/incidents',
          builder: (context, state) => const IncidentsListScreen(),
        ),
        GoRoute(
          path: '/incidents/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return IncidentDetailScreen(incidentId: id);
          },
        ),
        GoRoute(
          path: '/my-items',
          builder: (context, state) => const MyItemsScreen(),
        ),
        GoRoute(path: '/outbox', redirect: (context, state) => '/my-items'),
      ],
    );
  }
}
