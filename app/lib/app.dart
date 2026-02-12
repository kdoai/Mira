/// Mira App — MaterialApp with go_router navigation.
/// Ref: PLAN.md Section 7.1 (Navigation Route Map)
///
/// Routes:
///   /splash → SplashScreen (no auth)
///   /onboarding → OnboardingScreen (no auth)
///   /home → HomeScreen (auth, bottom nav tab 1)
///   /history → HistoryScreen (auth, bottom nav tab 2)
///   /profile → ProfileScreen (auth, bottom nav tab 3)
///   /chat/:coachId → ChatScreen (auth, new conversation)
///   /chat/:coachId/:conversationId → ChatScreen (auth, resume)
///   /voice/:coachId → VoiceSessionScreen (auth, Pro only)
///   /report/:conversationId → ReportScreen (auth)
///   /about-me → AboutMeScreen (auth)
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mira/providers/auth_provider.dart';
import 'package:mira/screens/chat/chat_screen.dart';
import 'package:mira/screens/history/history_screen.dart';
import 'package:mira/screens/home/home_screen.dart';
import 'package:mira/screens/onboarding/onboarding_screen.dart';
import 'package:mira/screens/profile/profile_screen.dart';
import 'package:mira/screens/voice/voice_session_screen.dart';
import 'package:mira/screens/history/report_screen.dart';
import 'package:mira/screens/profile/about_me_screen.dart';
import 'package:mira/screens/splash_screen.dart';
import 'package:mira/theme/app_theme.dart';
import 'package:mira/widgets/shell_scaffold.dart';

/// Shell route key for bottom navigation
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable that notifies GoRouter when auth state changes
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      final currentPath = state.uri.path;

      // Don't redirect while loading auth state
      if (isLoading) return null;

      // Allow splash always
      if (currentPath == '/splash') return null;

      // Allow onboarding without auth
      if (currentPath == '/onboarding') {
        return isLoggedIn ? '/home' : null;
      }

      // Redirect unauthenticated users to onboarding
      if (!isLoggedIn) return '/onboarding';

      return null;
    },
    routes: [
      // Splash (no auth)
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding (no auth)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Shell route for bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Chat (auth required)
      GoRoute(
        path: '/chat/:coachId',
        builder: (context, state) {
          final coachId = state.pathParameters['coachId']!;
          final conversationId = state.uri.queryParameters['conversationId'];
          return ChatScreen(
            coachId: coachId,
            conversationId: conversationId,
          );
        },
      ),

      // Voice session (auth required, Pro only)
      GoRoute(
        path: '/voice/:coachId',
        builder: (context, state) {
          final coachId = state.pathParameters['coachId']!;
          return VoiceSessionScreen(coachId: coachId);
        },
      ),

      // Session report
      GoRoute(
        path: '/report/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final coachId = state.uri.queryParameters['coachId'];
          return ReportScreen(
            conversationId: conversationId,
            coachId: coachId,
          );
        },
      ),

      // About Me
      GoRoute(
        path: '/about-me',
        builder: (context, state) => const AboutMeScreen(),
      ),
    ],
  );
});

/// Main app widget
class MiraApp extends ConsumerWidget {
  const MiraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Mira',
      theme: MiraTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
