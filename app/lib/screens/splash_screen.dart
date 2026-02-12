/// Splash screen — shown on app launch.
/// Ref: PLAN.md Section 7.1 (2s then check auth state), Section 0.8 (App Polish)
///
/// Displays Mira logo on warm white background for 2 seconds,
/// then navigates based on auth state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mira/providers/auth_provider.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/providers/subscription_provider.dart';
import 'package:mira/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    // Navigate after 2 seconds
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    final user = authState.valueOrNull;

    if (user != null) {
      // Initialize RevenueCat with Firebase UID
      await ref.read(isProProvider.notifier).initialize(user.uid);
      // Load custom coaches from backend
      final api = ref.read(apiServiceProvider);
      await ref.read(coachesProvider.notifier).loadCustomCoaches(api);
      if (mounted) context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo — circle icon representing Mira
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: MiraColors.forestGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.circle_outlined,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: MiraSpacing.lg),
              Text(
                'Mira',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: MiraColors.forestGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: MiraSpacing.sm),
              Text(
                'Think clearly. Move forward.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MiraColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
