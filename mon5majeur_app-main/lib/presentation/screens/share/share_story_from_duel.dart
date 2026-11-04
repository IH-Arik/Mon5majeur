import '../../../data/models/match_result_model.dart';
import 'share_story_model.dart';

/// The story of a finished duel of mine, from what the Results tab shows
/// (the day's [result], the duel's [pair] and each side's lineup). The home
/// team is the duel's player A: it is drawn on top, whoever "me" is. The caller
/// says whether I am that home player ([iAmHome]) and only offers this for a
/// duel of mine.
///
/// Null when there is nothing to share yet: the day is not published, the
/// scores are still hidden, or I have no lineup. The scores
/// are the server's. [medals] is the night's top 3 over all the NBA players;
/// empty when the night cannot be ranked (an older night): no badges then.
ShareStoryData? shareStoryFromDuel({
  required MatchResultModel result,
  required MatchPair pair,
  required PlayerScore? teamA,
  required PlayerScore? teamB,
  required bool iAmHome,
  Map<String, int> medals = const {},
  String? phaseLabel,
}) {
  if (result.status != 'completed' || result.scoresHidden) return null;
  final date = DateTime.tryParse(result.matchDate);
  if (date == null) return null;

  // A side with no score entry never set a lineup: shown as such.
  final home =
      teamA ?? _noLineup(pair.playerAId, pair.playerAName);
  final away =
      teamB ?? _noLineup(pair.playerBId, pair.playerBName);
  if (home.selectionHidden || away.selectionHidden) return null;

  if ((iAmHome ? home : away).selection.isEmpty) return null; // none of mine

  return ShareStoryData.duel(
    leagueName: result.leagueName,
    matchDay: result.matchDay > 0 ? result.matchDay : null,
    phaseLabel: phaseLabel,
    date: date,
    home: home,
    away: away,
    homeScore: pair.scoreA,
    awayScore: pair.scoreB,
    iAmHome: iAmHome,
    medals: medals,
  );
}

PlayerScore _noLineup(int id, String name) => PlayerScore(
  playerId: id,
  teamName: name,
  username: name,
  totalPoints: 0,
  selection: const [],
);
