// lib/core/utils/lineup_request.dart
import '../../data/models/player.dart';

/// The `substitute_player` field of a lineup save request (duels and Global
/// League). It has three meanings on the server, so the caller says which:
///
///  * [send] false (default) - the field is left out: the server keeps the
///    substitute it already has. An older app behaves like this.
///  * [send] true with a player - set or change the substitute.
///  * [send] true with null - an explicit null: the substitute is removed.
Map<String, dynamic> substituteRequestField(
  Player? substitute, {
  required bool send,
}) {
  if (!send) return const {};
  return {'substitute_player': substitute?.toApiJson()};
}
