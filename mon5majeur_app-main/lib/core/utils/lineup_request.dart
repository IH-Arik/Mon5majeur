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

/// The body of a duel league lineup save: the five starters, the three bonus
/// flags (the 6th Man only counts while that bonus is on) and the substitute
/// (always sent: null removes it).
Map<String, dynamic> duelLineupRequestBody({
  required List<Player?> starters,
  required bool luxuryTax,
  required bool chefCurry,
  required bool sixthManActive,
  required Player? sixthMan,
  required Player? substitute,
}) {
  return {
    'selected_players': [for (final p in starters) if (p != null) p.toApiJson()],
    'luxury_tax': luxuryTax,
    'chef_curry': chefCurry,
    'sixth_man_player': sixthManActive ? sixthMan?.toApiJson() : null,
    ...substituteRequestField(substitute, send: true),
  };
}
