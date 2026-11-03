import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mon5majeur_app/core/constants/api_constants.dart';
import 'package:mon5majeur_app/core/local_db/local_db.dart';
import 'package:mon5majeur_app/core/services/notification_service.dart';

/// Stands in for the phone and the API: records what would be sent.
class _Fake {
  final posts = <String>[];
  int deletes = 0;

  void install() {
    PushDeps.permission = () async => PushPermission.granted;
    PushDeps.fcmToken = () async => 'device-token';
    PushDeps.postToken = (t) async {
      posts.add(t);
      return 200;
    };
    PushDeps.deleteToken = () async {
      deletes++;
      return true;
    };
    PushDeps.isOptOut = () async => false;
    PushDeps.retryDelays = const [Duration.zero, Duration.zero, Duration.zero];
  }
}

Future<void> _login() async {
  await SharedPrefsHelper.setString(AppConstants.token, 'access');
  await SharedPrefsHelper.setString(AppConstants.refreshToken, 'refresh');
}

Future<void> _eraseSession() async {
  await SharedPrefsHelper.remove(AppConstants.token);
  await SharedPrefsHelper.remove(AppConstants.refreshToken);
}

void main() {
  late _Fake fake;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PushDeps.reset();
    fake = _Fake()..install();
  });
  tearDown(PushDeps.reset);

  test('login -> token sent -> logout (DELETE) -> login -> same token sent again',
      () async {
    await _login();
    await syncPushToken(reason: 'login', force: true);
    expect(fake.posts, ['device-token']);

    // Logout: one DELETE, before the session is erased.
    await unregisterPushToken();
    expect(fake.deletes, 1);
    await _eraseSession();

    // The server forgot the token, so the same token must go up again.
    await _login();
    await syncPushToken(reason: 'login', force: true);
    expect(fake.posts, ['device-token', 'device-token']);
  });

  test('logout asks the server once, even if called twice', () async {
    await _login();
    final first = unregisterPushToken();
    final second = unregisterPushToken(); // double tap
    await Future.wait([first, second]);
    expect(fake.deletes, 1);

    await _eraseSession();
    await unregisterPushToken(); // session already gone
    expect(fake.deletes, 1);
  });

  test('a stuck sync does not stop the next login from sending the token',
      () async {
    await _login();
    final never = Completer<String?>();
    PushDeps.fcmToken = () => never.future; // the plugin never answers
    unawaited(syncPushToken(reason: 'home opened'));
    await Future<void>.delayed(Duration.zero);

    // A plain call joins the stuck run...
    unawaited(syncPushToken(reason: 'app resumed'));
    expect(fake.posts, isEmpty);

    // ...but a login replaces it.
    PushDeps.fcmToken = () async => 'device-token';
    await syncPushToken(reason: 'login', force: true);
    expect(fake.posts, ['device-token']);
  });

  test('the lock is released by itself if a run never ends', () async {
    await _login();
    PushDeps.maxRun = const Duration(milliseconds: 50);
    final never = Completer<String?>();
    PushDeps.fcmToken = () => never.future;
    await syncPushToken(reason: 'stuck');

    PushDeps.fcmToken = () async => 'device-token';
    await syncPushToken(reason: 'later');
    expect(fake.posts, ['device-token']);
  });

  test('a sync in flight cannot put the token back after the logout', () async {
    await _login();
    final gate = Completer<String?>();
    PushDeps.fcmToken = () => gate.future;
    final running = syncPushToken(reason: 'app resumed');
    await Future<void>.delayed(Duration.zero);

    await unregisterPushToken(); // logout while that sync waits
    await _eraseSession();
    gate.complete('device-token'); // the plugin answers late
    await running;

    expect(fake.posts, isEmpty);
    expect(fake.deletes, 1);
  });

  test('no token from the phone yet: it asks again by itself', () async {
    await _login();
    PushDeps.noTokenRetryDelay = const Duration(milliseconds: 20);
    var asked = 0;
    PushDeps.fcmToken = () async => ++asked == 1 ? null : 'device-token';
    await syncPushToken(reason: 'cold start');
    expect(fake.posts, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(fake.posts, ['device-token']);
  });

  test('no session: nothing is sent', () async {
    await syncPushToken(reason: 'cold start');
    expect(fake.posts, isEmpty);
  });
}
