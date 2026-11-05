import 'package:get/get.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../constants/app_strings.dart';

/// Why a team could not be saved, as far as the player is concerned.
enum TeamSaveFailure { offline, sessionExpired, server }

/// False only when the check itself says there is no internet. A check that
/// fails to run never blocks the player: the request is sent and its own
/// answer decides.
Future<bool> hasInternetForTeamSave() async {
  try {
    return await InternetConnection().hasInternetAccess;
  } catch (_) {
    return true;
  }
}

/// GetConnect does not throw when the network drops or times out: it answers
/// with a null status code. A 401 that reaches this point already went
/// through the token refresh in ApiClient.
TeamSaveFailure teamSaveFailureFor(int? statusCode) {
  if (statusCode == null) return TeamSaveFailure.offline;
  if (statusCode == 401) return TeamSaveFailure.sessionExpired;
  return TeamSaveFailure.server;
}

String teamSaveFailureMessage(TeamSaveFailure failure) => switch (failure) {
      TeamSaveFailure.offline => AppString.teamSaveOffline.tr,
      TeamSaveFailure.sessionExpired => AppString.teamSaveSessionExpired.tr,
      TeamSaveFailure.server => AppString.teamSaveServerError.tr,
    };

/// The server's `detail` as text, whatever its shape (string, list, absent,
/// or a body that is not even JSON). For logs and for the server's own
/// refusal reasons; never shown as is.
String? safeServerDetail(dynamic body) {
  if (body is! Map) return null;
  final detail = body['detail'];
  if (detail == null) return null;
  return detail is String ? detail : detail.toString();
}
