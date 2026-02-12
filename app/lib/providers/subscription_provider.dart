/// Subscription state provider (Riverpod).
/// Ref: PLAN.md Section 3.2 (Pricing)
///
/// Tracks Pro/Free status via RevenueCat.
/// Initializes SDK on app start, syncs with Firebase Auth user ID.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:mira/providers/chat_provider.dart';
import 'package:mira/services/revenuecat_service.dart';

/// RevenueCat service singleton
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

/// Whether user has Pro subscription
final isProProvider = StateNotifierProvider<ProStatusNotifier, bool>((ref) {
  return ProStatusNotifier(ref);
});

class ProStatusNotifier extends StateNotifier<bool> {
  final Ref _ref;

  ProStatusNotifier(this._ref) : super(false);

  /// Initialize RevenueCat and check Pro status.
  /// Call after Firebase Auth sign-in.
  Future<void> initialize(String userId) async {
    final rc = _ref.read(revenueCatServiceProvider);
    await rc.initialize(userId: userId);
    await rc.logIn(userId);

    // Check current status
    state = await rc.isPro();

    // Listen for future changes
    rc.addListener((customerInfo) {
      state = customerInfo.entitlements.all['pro']?.isActive ?? false;
    });
  }

  /// Purchase a package and update state
  Future<bool> purchase(Package package) async {
    final rc = _ref.read(revenueCatServiceProvider);
    final success = await rc.purchase(package);
    if (success) {
      state = true;
      // Sync to backend (server verifies with RevenueCat API)
      try {
        final api = _ref.read(apiServiceProvider);
        await api.syncSubscription();
      } catch (_) {}
    }
    return success;
  }

  /// Restore purchases
  Future<bool> restore() async {
    final rc = _ref.read(revenueCatServiceProvider);
    final success = await rc.restorePurchases();
    state = success;
    if (success) {
      try {
        final api = _ref.read(apiServiceProvider);
        await api.syncSubscription();
      } catch (_) {}
    }
    return success;
  }
}
