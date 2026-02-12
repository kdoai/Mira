/// Auth state provider (Riverpod).
/// Ref: PLAN.md Section 0.1 Rule 5 (Auth Required)
///
/// Manages Firebase auth state and provides AuthService to other providers.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/services/auth_service.dart';

/// Auth service singleton
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Stream of auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Whether the user is currently signed in
final isSignedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull != null;
});

/// Whether this is the user's first sign-in (show About Me prompt)
/// Ref: PLAN.md Section 3.5 (About Me Onboarding Flow)
final isFirstSignInProvider = StateProvider<bool>((ref) => false);
