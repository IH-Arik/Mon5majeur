// Plain-HTTP exceptions for the local test servers exist in DEBUG builds only,
// never in a release build, and never as a blanket "allow everything".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  const androidSrc = 'android/app/src';

  group('Android', () {
    test('the cleartext exception is in the debug source set only', () {
      expect(File('$androidSrc/debug/res/xml/network_security_config.xml').existsSync(), isTrue);
      expect(read('$androidSrc/debug/AndroidManifest.xml'),
          contains('android:networkSecurityConfig="@xml/network_security_config"'));
      for (final other in ['main', 'profile']) {
        expect(File('$androidSrc/$other/res/xml/network_security_config.xml').existsSync(), isFalse,
            reason: '$other must not carry a network security config');
        final manifest = read('$androidSrc/$other/AndroidManifest.xml');
        expect(manifest, isNot(contains('networkSecurityConfig')), reason: other);
        expect(manifest, isNot(contains('usesCleartextTraffic')), reason: other);
      }
    });

    test('the debug config allows exactly the local test hosts, nothing else', () {
      // comments explain the file and may name the forbidden tags: ignore them
      final xml = read('$androidSrc/debug/res/xml/network_security_config.xml')
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      final hosts = RegExp(r'<domain[^>]*>([^<]+)</domain>').allMatches(xml).map((m) => m.group(1)).toSet();
      expect(hosts, {'10.0.2.2', '127.0.0.1', 'localhost'});
      expect(xml, isNot(contains('<base-config')));
      expect(xml, isNot(contains('trust-anchors')));
      expect(RegExp(r'cleartextTrafficPermitted="true"').allMatches(xml).length, 1);
      expect(xml, isNot(contains('includeSubdomains="true"')));
    });
  });

  group('iOS', () {
    test('Info.plist has no App Transport Security exception at all', () {
      final plist = read('ios/Runner/Info.plist');
      expect(plist, isNot(contains('NSAppTransportSecurity')));
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
      expect(plist, isNot(contains('NSAllowsLocalNetworking')));
    });
  });
}
