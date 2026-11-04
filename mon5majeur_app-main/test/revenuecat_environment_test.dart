// RevenueCat is used only against the production server.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mon5majeur_app/core/services/revenuecat_service.dart';
import 'package:mon5majeur_app/data/services/api_url.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prod = 'https://api.mon5majeur.com';
  const local = 'http://127.0.0.1:8000';

  // A signed-in user: without a stored id, loginUser has nothing to send anyway.
  setUp(() => SharedPreferences.setMockInitialValues({'userId': 'user-42'}));

  group('production (the default address)', () {
    test('RevenueCat stays ACTIVE with the default address', () {
      expect(ApiUrl.baseUrl, prod);
      expect(RevenueCatService.isEnabledFor(ApiUrl.baseUrl), isTrue);
      expect(RevenueCatService.instance.enabled, isTrue);
    });

    test('and really talks to the SDK: init reaches the Purchases plugin', () async {
      // In a test there is no native plugin: reaching it is what proves it is active.
      await expectLater(
        RevenueCatService.forBaseUrl(prod).init(),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('main() still starts it, unconditionally', () {
      final file = File('lib/main.dart').readAsStringSync();
      final body = file.substring(file.indexOf('Future<void> main()'));
      expect(body, contains('await RevenueCatService.instance.init();'));
      expect(body, contains('RevenueCatService.instance.loginUser()'));
      expect(body, isNot(contains('if (ApiUrl')), reason: 'the switch lives in the service');
    });

    test('login and logout reach the SDK too', () async {
      final svc = RevenueCatService.forBaseUrl(prod);
      await expectLater(svc.loginUser(), throwsA(isA<MissingPluginException>()));
      await expectLater(svc.logoutUser(), throwsA(isA<MissingPluginException>()));
    });

    test('store calls are allowed (they fail only for lack of a native plugin here)', () async {
      await expectLater(
        RevenueCatService.forBaseUrl(prod).fetchOfferings(),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('any other address (local test servers)', () {
    for (final url in [local, 'http://10.0.2.2:8000', 'http://localhost:8000', '']) {
      test('"$url": switched off', () {
        expect(RevenueCatService.isEnabledFor(url), isFalse);
        expect(RevenueCatService.forBaseUrl(url).enabled, isFalse);
      });
    }

    test('init never reaches the SDK', () async {
      await RevenueCatService.forBaseUrl(local).init(); // no MissingPluginException
    });

    test('login and logout are silent no-ops, even with a signed-in user', () async {
      final svc = RevenueCatService.forBaseUrl(local);
      await svc.loginUser(); // would throw MissingPluginException if it reached the SDK
      await svc.logoutUser();
    });

    test('store calls refuse clearly instead of reaching the SDK', () async {
      final svc = RevenueCatService.forBaseUrl(local);
      expect(svc.fetchOfferings, throwsA(isA<StateError>()));
      expect(svc.restorePurchases, throwsA(isA<StateError>()));
      expect(svc.getCustomerInfo, throwsA(isA<StateError>()));
      expect(() => svc.getProducts(['x']), throwsA(isA<StateError>()));
    });
  });
}
