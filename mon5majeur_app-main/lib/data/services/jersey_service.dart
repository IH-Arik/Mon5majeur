import 'package:flutter/foundation.dart';

import '../../core/local_db/local_db.dart';
import 'api_service.dart';
import 'api_url.dart';

/// The team jersey chosen with "Change jersey", stored on the user account
/// (QA 28/09 #5: it lived in screen state and reset on restart, league switch
/// or matchday change). One value for the whole account, shared by every
/// league screen. The last known value is also kept locally so a screen can
/// show the right jersey before the network answers.
class JerseyService {
  JerseyService._();

  static const _prefsKey = 'jersey_index';
  static const jerseyCount = 6;

  static int _clamp(int v) => v >= 0 && v < jerseyCount ? v : 0;

  /// Locally remembered jersey (0 when nothing stored yet).
  static Future<int> cached() async {
    final v = await SharedPrefsHelper.getInt(_prefsKey); // -1 when unset
    return _clamp(v);
  }

  /// Account jersey from the server; falls back to the local copy offline.
  static Future<int> load() async {
    try {
      final response = await ApiClient()
          .get(url: '${ApiUrl.baseUrl}${ApiUrl.jersey}');
      if (response.statusCode == 200 && response.body is Map) {
        final v = _clamp((response.body['jersey_index'] as num?)?.toInt() ?? 0);
        await SharedPrefsHelper.setInt(_prefsKey, v);
        return v;
      }
    } catch (e) {
      debugPrint('⚠️ jersey load failed: $e');
    }
    return cached();
  }

  /// Saves on the account. The local copy is written first so the choice
  /// survives even if the request fails; returns whether the server has it.
  static Future<bool> save(int index) async {
    final v = _clamp(index);
    await SharedPrefsHelper.setInt(_prefsKey, v);
    try {
      final response = await ApiClient().patch(
        url: '${ApiUrl.baseUrl}${ApiUrl.jersey}',
        body: {'jersey_index': v},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ jersey save failed: $e');
      return false;
    }
  }
}
