/// RevenueCat subscription service.
/// Ref: PLAN.md Section 3.2 (Pricing), Section 4 (Architecture)
///
/// Free: General Coach only, 10 msg/day, no voice
/// Pro: $9.99/mo or $79.99/yr, all coaches, unlimited, voice
library;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static const String _apiKey = 'goog_tefpQLJTfzEXcivPQOrHvduhYfe';
  static const String _entitlementId = 'pro';

  bool _isInitialized = false;

  /// Initialize RevenueCat SDK and optionally log in user.
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
    final config = PurchasesConfiguration(_apiKey);
    if (userId != null) {
      config.appUserID = userId;
    }
    await Purchases.configure(config);
    _isInitialized = true;
  }

  /// Log in with Firebase UID after auth
  Future<CustomerInfo> logIn(String userId) async {
    final result = await Purchases.logIn(userId);
    return result.customerInfo;
  }

  /// Check if user has Pro entitlement
  Future<bool> isPro() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get available offerings (packages)
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Purchase a package
  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    try {
      final result = await Purchases.restorePurchases();
      return result.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Listen for subscription changes
  void addListener(void Function(CustomerInfo) listener) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// Log out
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
  }
}
