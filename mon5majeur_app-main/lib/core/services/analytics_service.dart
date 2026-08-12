import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Thin wrapper around FirebaseAnalytics so callers never touch the
/// Firebase SDK directly and a logging failure never crashes a user flow.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

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
