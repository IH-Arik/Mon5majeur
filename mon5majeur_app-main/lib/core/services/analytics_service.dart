import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';

import '../../data/services/api_url.dart';

final _logger = Logger();

/// Thin wrapper around FirebaseAnalytics so callers never touch the
/// Firebase SDK directly and a logging failure never crashes a user flow.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Usage statistics are collected only against the production server: a test
  /// build pointed at a local backend must not pollute the real Analytics.
  static bool collectionEnabledFor(String baseUrl) =>
      ApiUrl.isProductionUrl(baseUrl);

  /// Call once, right after Firebase is initialised.
  static Future<void> configureForEnvironment() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(
        collectionEnabledFor(ApiUrl.baseUrl),
      );
    } catch (e) {
      _logger.e('AnalyticsService.configureForEnvironment failed: $e');
    }
  }

  static Future<void> logEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      _logger.e('AnalyticsService.logEvent($name) failed: $e');
    }
  }
}
