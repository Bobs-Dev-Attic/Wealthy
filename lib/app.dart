import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/security_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/data/accounts_screen.dart';
import 'screens/data/expenses_screen.dart';
import 'screens/data/income_screen.dart';
import 'screens/data/plan_screen.dart';
import 'screens/data/profile_screen.dart';
import 'screens/projections/projections_screen.dart';
import 'state/providers.dart';

class WealthyApp extends ConsumerWidget {
  const WealthyApp({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initError != null) return StartupErrorApp(error: initError!);
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'Wealthy',
      debugShowCheckedModeBanner: false,
      theme: WealthyTheme.dark,
      routerConfig: router,
    );
  }
}

/// Shown when Supabase fails to initialize, so the app still paints a frame
/// instead of hanging on the HTML loading screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WealthyTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                const Text('Could not reach the Wealthy backend.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Please check your connection and refresh the page.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text('$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _GoRouterRefreshStream(auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final authRoute = loc == '/login' || loc == '/signup';
      if (!loggedIn && !authRoute) return '/login';
      if (loggedIn && authRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
      GoRoute(path: '/income', builder: (_, __) => const IncomeScreen()),
      GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
      GoRoute(path: '/plan', builder: (_, __) => const PlanScreen()),
      GoRoute(path: '/projections', builder: (_, __) => const ProjectionsScreen()),
      GoRoute(path: '/security', builder: (_, __) => const SecurityScreen()),
    ],
  );
});

/// Bridges a stream to [Listenable] so GoRouter re-evaluates redirects on auth
/// changes.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
