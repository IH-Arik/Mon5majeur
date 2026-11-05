// lib/core/utils/lineup_rules.dart
import '../../data/models/live_score_model.dart';
import '../../data/models/match_result_model.dart';
import '../../data/models/substitution_model.dart';
import '../../data/models/player.dart';

/// The substitute ("remplaçant") of a lineup. These numbers are the server's
/// (substitution.py: SUBSTITUTE_MAX_PRICE / REPLACEABLE_MIN_PRICE).
const double substituteMaxPrice = 10.0; // M, checked by the server on save
const double replaceableMinPrice = 10.0; // M, a starter must cost at least this

/// What the five starters cost against the budget. The substitute is outside
/// the budget (and so is any 6th Man the caller adds on top, explicitly).
double budgetUsedByStarters(Iterable<Player?> starters) =>
    starters.fold(0.0, (sum, p) => sum + (p?.price ?? 0.0));

/// The picker lists players of [substituteMaxPrice] or less, except the
/// starters (and the 6th Man, where there is one).
bool canBeSubstitute(Player candidate, Set<String> excludedIds) {
  if (candidate.id != null && excludedIds.contains(candidate.id)) return false;
  return candidate.price <= substituteMaxPrice;
}

/// The points of a lineup as the server counts them: the starter the substitute
/// replaced counts for nothing (he is flagged absent) and the substitute counts
/// once he has really come in. A substitute who did not enter, or whose entry
/// is not decided yet (live), never counts.
int lineupPointsTotal(PlayerScore team) {
  var sum = 0;
  for (final p in team.selection) {
    if (!p.absent) sum += p.score;
  }
  final sub = team.substitute;
  if (sub != null && (team.substitution?.isEntered ?? false)) sum += sub.score;
  return sum;
}

/// Name of the starter the substitute came in for, when he did.
String? replacedStarterName(PlayerScore team) {
  final id = team.substitution?.replacedId;
  if (id == null) return null;
  for (final p in team.selection) {
    if (p.id == id) return p.name;
  }
  return null;
}

/// Live total of a lineup (the same rule as the server's): the starters except
/// the one the substitute replaced, plus the substitute once he has come in
/// (never before every game of the lineup is final), plus the 6th Man if any,
/// and the best five of them count.
int liveLineupTotal({
  required List<LivePlayerScore> starters,
  List<LivePlayerScore> sixth = const [],
  LivePlayerScore? substitute,
  SubstitutionState? substitution,
}) {
  final comesIn = (substitution?.isEntered ?? false) && substitute != null;
  final counted = <LivePlayerScore>[
    ...starters.where((p) => !p.isAbsent),
    if (comesIn) substitute,
    ...sixth,
  ];
  final scores = [for (final p in counted) p.fantasyScoreLive.round()]
    ..sort((a, b) => b.compareTo(a));
  return scores.take(5).fold(0, (sum, v) => sum + v);
}
