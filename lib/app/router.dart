import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/incidents/incident_detail_screen.dart';
import '../features/incidents/incidents_list_screen.dart';
import '../features/outbox/outbox_screen.dart';

class AppRouter {
  AppRouter._();

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
          path: '/outbox',
          builder: (context, state) => const OutboxScreen(),
        ),
      ],
    );
  }
}
