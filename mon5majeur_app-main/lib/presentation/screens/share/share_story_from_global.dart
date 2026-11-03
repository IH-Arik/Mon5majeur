import '../../../core/utils/lineup_positions.dart';
import '../../../data/models/match_result_model.dart';
import 'share_story_model.dart';

/// The story of a published World League night, from the very answer the
/// Results tab shows (`globalPublishedResult`). Null when the night has no
/// published result or no lineup, so nothing is offered to share.
///
/// The score is the sum of the players' points, like the Results tab. [medals]
/// is the night's top 3 over all the NBA players ([NightTopScores]); empty
/// when the night cannot be ranked (an older night): no badges then.
ShareStoryData? shareStoryFromGlobalResult(
  Map<String, dynamic> d, {
  Map<String, int> medals = const {},
}) {
  if (d['available'] != true) return null;
  final date = DateTime.tryParse('${d['nba_date']}');
  if (date == null) return null;

  final items = [
    for (final e in (d['selection'] as List? ?? const []))
      PlayerSelection.fromJson(Map<String, dynamic>.from(e as Map)),
  ];
  final selection = inCourtOrder(items, (p) => p.position);
  if (selection.isEmpty) return null;

  final me = PlayerScore(
    playerId: 0,
    teamName: d['team_name'] ?? '',
    username: '',
    totalPoints: (d['total_points'] as num?)?.toInt() ?? 0,
    selection: selection,
    teamLogo: d['team_logo'] ?? '',
    jerseyIndex: (d['jersey_index'] as num?)?.toInt() ?? 0,
    isMe: true,
  );
  return ShareStoryData.world(
    matchDay: (d['night_number'] as num?)?.toInt(),
    date: date,
    me: me,
    score: selection.fold<int>(0, (a, p) => a + p.score),
    medals: medals,
  );
}
