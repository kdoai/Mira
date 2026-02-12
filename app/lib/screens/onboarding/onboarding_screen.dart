/// Onboarding screen — 2 pages + Google Sign-In.
/// Ref: PLAN.md Section 3.3 (2-page onboarding), Section 7.1
///
/// Page 1: Welcome + value proposition
/// Page 2: Google Sign-In button
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mira/providers/auth_provider.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/providers/subscription_provider.dart';
import 'package:mira/theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      final authService = ref.read(authServiceProvider);
      final credential = await authService.signInWithGoogle();
      if (credential != null && mounted) {
        // Initialize RevenueCat with Firebase UID
        final uid = credential.user?.uid;
        if (uid != null) {
          await ref.read(isProProvider.notifier).initialize(uid);
          final api = ref.read(apiServiceProvider);
          await ref.read(coachesProvider.notifier).loadCustomCoaches(api);
        }
        // Mark as first sign-in to show About Me prompt
        ref.read(isFirstSignInProvider.notifier).state = true;
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildWelcomePage(context),
                  _buildSignInPage(context),
                ],
              ),
            ),

            // Page indicator + button
            Padding(
              padding: const EdgeInsets.all(MiraSpacing.lg),
              child: Column(
                children: [
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (index) {
                      return Container(
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(
                          horizontal: MiraSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? MiraColors.forestGreen
                              : MiraColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: MiraSpacing.lg),

                  // CTA button
                  if (_currentPage == 0)
                    ElevatedButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Get Started'),
                    )
                  else
                    _buildGoogleSignInButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MiraSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: MiraColors.forestGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.circle_outlined,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: MiraSpacing.xl),

          Text(
            'Everyone deserves\na great coach',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: MiraSpacing.base),

          Text(
            'AI coaching that helps you think clearly, make better decisions, and move forward with intention.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: MiraColors.textSecondary,
                ),
          ),
          const SizedBox(height: MiraSpacing.xxl),

          // Feature highlights
          _buildFeatureRow(
            Icons.chat_bubble_outline,
            'Talk through anything',
            'Career, creativity, wellness, relationships',
          ),
          const SizedBox(height: MiraSpacing.base),
          _buildFeatureRow(
            Icons.mic_none,
            'Voice coaching sessions',
            'Like talking to a real coach, anytime',
          ),
          const SizedBox(height: MiraSpacing.base),
          _buildFeatureRow(
            Icons.auto_awesome_outlined,
            'Personal & private',
            'Your coach remembers you and adapts',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: MiraColors.forestGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(MiraRadius.md),
          ),
          child: Icon(icon, color: MiraColors.forestGreen),
        ),
        const SizedBox(width: MiraSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignInPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MiraSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 64,
            color: MiraColors.forestGreen,
          ),
          const SizedBox(height: MiraSpacing.lg),

          Text(
            'Sign in to start',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: MiraSpacing.sm),

          Text(
            'Your conversations are private and secure. Sign in with Google to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: MiraColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isSigningIn ? null : _signIn,
        icon: _isSigningIn
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.g_mobiledata, size: 24),
        label: Text(_isSigningIn ? 'Signing in...' : 'Continue with Google'),
      ),
    );
  }
}
