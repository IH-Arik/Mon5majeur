import '../../data/models/playoff_bracket_model.dart';

/// A play-off round and the game number inside its series.
class PlayoffPhase {
  /// 'semi_final' or 'final' (PlayoffSeries.round).
  final String round;
  final int game;

  const PlayoffPhase(this.round, this.game);

  @override
  bool operator ==(Object other) =>
      other is PlayoffPhase && other.round == round && other.game == game;

  @override
  int get hashCode => Object.hash(round, game);

  @override
  String toString() => 'PlayoffPhase($round, $game)';
}

bool _knownRound(String round) => round == 'semi_final' || round == 'final';

/// The play-off phase of match day [day], or null (the caller then keeps
/// "Journée N"). Exact lookup by PlayoffGame.matchDay first; the deduction is
/// tried only for the current day ([day] == [lastMatchDay]) of a league that
/// is in play-offs, when no game matches exactly.
PlayoffPhase? playoffPhaseFor({
  required PlayoffBracketModel? bracket,
  required int day,
  required int? lastMatchDay,
  required bool inPlayoffs,
}) {
  if (bracket == null || !inPlayoffs) return null;
  final exact = _exactPhase(bracket, day);
  if (exact != null) return exact;
  if (_hasExactMatch(bracket, day)) return null; // found but ambiguous
  if (lastMatchDay != null && day == lastMatchDay) {
    return _deducedCurrentPhase(bracket);
  }
  return null;
}

bool _hasExactMatch(PlayoffBracketModel bracket, int day) => bracket.rounds.any(
      (r) => r.series.any((s) => s.games.any((g) => g.matchDay == day)),
    );

PlayoffPhase? _exactPhase(PlayoffBracketModel bracket, int day) {
  PlayoffPhase? found;
  for (final round in bracket.rounds) {
    for (final series in round.series) {
      for (final game in series.games) {
        if (game.matchDay != day) continue;
        if (!_knownRound(series.round) || game.gameNumber <= 0) return null;
        final phase = PlayoffPhase(series.round, game.gameNumber);
        if (found != null && found != phase) return null; // ambiguous
        found = phase;
      }
    }
  }
  return found;
}

// À supprimer quand le serveur enverra le match planifié dans games.
// Today the server only lists a game in `games` once it has been played, so
// the game scheduled for the current match day is missing. It is deduced as
// "the next game" of the open series of the last round, and only when that is
// unambiguous: every open series of that round has played the same number of
// games, and none has hidden scores (its real state is then unknown).
PlayoffPhase? _deducedCurrentPhase(PlayoffBracketModel bracket) {
  final rounds = bracket.rounds.where((r) => r.series.isNotEmpty).toList();
  if (rounds.isEmpty) return null;
  final series = rounds.last.series;
  if (series.any((s) => !_knownRound(s.round) || s.hasHiddenScores)) {
    return null;
  }
  final open = series.where((s) => !s.isComplete).toList();
  if (open.isEmpty) return null;
  final played = open.first.games.length;
  if (open.any((s) => s.games.length != played)) return null;
  return PlayoffPhase(open.first.round, played + 1);
}
