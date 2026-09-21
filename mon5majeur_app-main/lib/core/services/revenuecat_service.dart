import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../constants/api_constants.dart';
import '../local_db/local_db.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// RevenueCat Service — the single place that talks to the Purchases SDK.
///
/// • Call [init] once at app start (in main.dart).
/// • Call [loginUser] after auth so RevenueCat knows who it is.
/// • The Paywall reads [fetchOfferings] to show real store prices.
/// • [purchasePackage] triggers the native payment sheet.
/// ─────────────────────────────────────────────────────────────────────────────
final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  // ── API keys ──────────────────────────────────────────────────────────────
  static const _appleApiKey = 'appl_KAyxZwXTxwQrOmZozDfmKWyuvQW';
  static const _testApiKey = 'test_GpLhznVNgMabYduuksOyuvOZKqL';

  bool _initialized = false;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    await Purchases.setLogLevel(LogLevel.debug);

    late final PurchasesConfiguration config;

    if (kDebugMode) {
      // Use the test/sandbox key during development
      config = PurchasesConfiguration(_testApiKey);
    } else if (Platform.isIOS || Platform.isMacOS) {
      config = PurchasesConfiguration(_appleApiKey);
    } else {
      // Android production — uses the Apple key as the default public key
      // (RevenueCat routes to the right store via the platform). Replace
      // with a dedicated Google API key once created in the RC dashboard.
      config = PurchasesConfiguration(_appleApiKey);
    }

    await Purchases.configure(config);
    _initialized = true;
    _log.i('✅ RevenueCat initialised (debug=$kDebugMode)');
  }

  // ── User identification ───────────────────────────────────────────────────
  /// Call after successful login / registration so RevenueCat links the
  /// subscription history to the backend user id.
  Future<void> loginUser() async {
    final userId = await SharedPrefsHelper.getString(AppConstants.userId);
    if (userId != null && userId.isNotEmpty) {
      final result = await Purchases.logIn(userId);
      _log.i('🔑 RevenueCat user logged in — id=$userId, '
          'created=${result.created}');
    }
  }

  /// Call on logout so a new anonymous ID is created.
  Future<void> logoutUser() async {
    if (await Purchases.isAnonymous) return;
    await Purchases.logOut();
    _log.i('🔓 RevenueCat user logged out');
  }

  // ── Offerings ─────────────────────────────────────────────────────────────
  Future<Offerings> fetchOfferings() async {
    final offerings = await Purchases.getOfferings();
    _log.i('📦 Offerings fetched — ${offerings.all.length} offering(s)');
    return offerings;
  }

  // ── Purchase ──────────────────────────────────────────────────────────────
  /// Triggers the native payment sheet.  Returns the [CustomerInfo] from the
  /// completed [PurchaseResult] after a successful transaction, or null if
  /// the user cancelled.
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      _log.i('💳 Purchase successful — ${package.identifier}');
      return result.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        _log.w('🚫 Purchase cancelled by user');
        return null;
      }
      _log.e('❌ Purchase error: $errorCode');
      rethrow;
    }
  }

  // ── Products ──────────────────────────────────────────────────────────────
  Future<List<StoreProduct>> getProducts(List<String> productIdentifiers) async {
    try {
      final products = await Purchases.getProducts(productIdentifiers);
      _log.i('📦 Products fetched directly — ${products.length} product(s)');
      return products;
    } catch (e) {
      _log.w('⚠️ Direct product fetch fallback: $e');
      return [];
    }
  }

  /// Triggers the native payment sheet for a StoreProduct directly.
  Future<CustomerInfo?> purchaseStoreProduct(StoreProduct product) async {
    try {
      final result = await Purchases.purchaseStoreProduct(product);
      _log.i('💳 Purchase successful — ${product.identifier}');
      return result.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        _log.w('🚫 Purchase cancelled by user');
        return null;
      }
      _log.e('❌ Purchase error: $errorCode');
      rethrow;
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────
  Future<CustomerInfo> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    _log.i('♻️ Purchases restored');
    return info;
  }

  // ── Customer Info ─────────────────────────────────────────────────────────
  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }
}
