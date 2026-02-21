import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'data/local/hive_service.dart';
import 'data/repositories/mock_incident_repository.dart';
import 'features/auth/auth_provider.dart';
import 'features/incidents/incidents_provider.dart';
import 'features/my_items/my_items_provider.dart';
import 'features/outbox/outbox_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.initialize();
  runApp(const IncidentCompanionApp());
}

class IncidentCompanionApp extends StatelessWidget {
  const IncidentCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MockIncidentRepository>(
          create: (_) => MockIncidentRepository(),
        ),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<IncidentsProvider>(
          create: (context) =>
              IncidentsProvider(context.read<MockIncidentRepository>()),
        ),
        ChangeNotifierProvider<OutboxProvider>(
          create: (context) =>
              OutboxProvider(context.read<MockIncidentRepository>()),
        ),
        ChangeNotifierProvider<MyItemsProvider>(
          create: (context) =>
              MyItemsProvider(context.read<MockIncidentRepository>()),
        ),
        Provider<GoRouter>(
          create: (context) =>
              AppRouter.createRouter(context.read<AuthProvider>()),
          dispose: (_, router) => router.dispose(),
        ),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'Incident Companion',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: context.read<GoRouter>(),
          );
        },
      ),
    );
  }
}
