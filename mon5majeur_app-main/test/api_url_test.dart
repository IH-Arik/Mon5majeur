// The server address, the release guard and the analytics switch.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/core/services/analytics_service.dart';
import 'package:mon5majeur_app/data/services/api_url.dart';

void main() {
  const prod = 'https://api.mon5majeur.com';

  group('default address', () {
    test('without --dart-define the app talks to production', () {
      // flutter test runs without API_BASE_URL: this is what a normal build gets.
      expect(ApiUrl.baseUrl, prod);
      expect(ApiUrl.productionBaseUrl, prod);
      expect(ApiUrl.isProduction, isTrue);
      expect(ApiUrl.imageBaseUrl, prod);
    });
  });

  group('release guard', () {
    test('a release build on production starts', () {
      ApiUrl.assertSafeForRelease(url: prod, isRelease: true);
    });

    for (final url in [
      'http://127.0.0.1:8000',
      'http://10.0.2.2:8000',
      'http://localhost:8000',
      'https://energize-dyslexic-frisbee.ngrok-free.dev',
      'https://api.mon5majeur.com/', // trailing slash: not the exact address
      'http://api.mon5majeur.com', // plain http
      'https://staging.mon5majeur.com',
      '', // --dart-define=API_BASE_URL= (empty)
    ]) {
      test('a release build refuses to start on "$url"', () {
        expect(
          () => ApiUrl.assertSafeForRelease(url: url, isRelease: true),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Refusing to start'),
            ),
          ),
        );
      });

      test('a debug build may use "$url"', () {
        ApiUrl.assertSafeForRelease(url: url, isRelease: false);
      });
    }

    test('the guard runs first in main(), before Firebase and everything else', () {
      final file = File('lib/main.dart').readAsStringSync();
      final body = file.substring(file.indexOf('Future<void> main()'));
      final guard = body.indexOf('ApiUrl.assertSafeForRelease()');
      expect(guard, greaterThan(0));
      // nothing but the Flutter binding comes before it
      expect(guard, lessThan(body.indexOf('SharedPreferences.getInstance')));
      expect(guard, lessThan(body.indexOf('Firebase.initializeApp')));
      expect(guard, lessThan(body.indexOf('RevenueCatService.instance.init')));
      expect(guard, lessThan(body.indexOf('runApp(')));
    });
  });

  group('analytics', () {
    test('collected only against production', () {
      expect(AnalyticsService.collectionEnabledFor(prod), isTrue);
      expect(AnalyticsService.collectionEnabledFor('http://127.0.0.1:8000'), isFalse);
      expect(AnalyticsService.collectionEnabledFor('http://10.0.2.2:8000'), isFalse);
      expect(AnalyticsService.collectionEnabledFor(''), isFalse);
    });

    test('main() switches it right after Firebase starts', () {
      final file = File('lib/main.dart').readAsStringSync();
      final body = file.substring(file.indexOf('Future<void> main()'));
      final init = body.indexOf('Firebase.initializeApp');
      final switchOff = body.indexOf('AnalyticsService.configureForEnvironment()');
      expect(switchOff, greaterThan(init));
      expect(switchOff, lessThan(body.indexOf('runApp(')));
    });
  });
}
