import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/models/match_result_model.dart';
import '../../../data/models/player_today_score_model.dart';
import '../../../data/services/night_top_scores.dart';

/// Largest score gap (in points) that still counts as a "close" result.
const int kShareCloseMargin = 15;

/// World League night score: under [kShareWorldLow] is a poor night, up to
/// [kShareWorldHigh] an ordinary one, above it a great one.
const int kShareWorldLow = 80;
const int kShareWorldHigh = 120;

enum ShareCategory {
  bigWin,
  closeWin,
  tieWon,
  tieLost,
  closeLoss,
  bigLoss,
  worldLow,
  worldMid,
  worldHigh,
}

extension ShareCategoryX on ShareCategory {
  bool get isWin =>
      this == ShareCategory.bigWin ||
      this == ShareCategory.closeWin ||
      this == ShareCategory.tieWon;

  bool get isWorld =>
      this == ShareCategory.worldLow ||
      this == ShareCategory.worldMid ||
      this == ShareCategory.worldHigh;

  // A defeat, or a poor World League night: the grey, subdued look.
  bool get isLoss =>
      this == ShareCategory.closeLoss ||
      this == ShareCategory.bigLoss ||
      this == ShareCategory.tieLost ||
      this == ShareCategory.worldLow;

  bool get isTie =>
      this == ShareCategory.tieWon || this == ShareCategory.tieLost;

  String get humor {
    final key = switch (this) {
        ShareCategory.bigWin => AppString.shareHumorBigWin,
        ShareCategory.closeWin => AppString.shareHumorCloseWin,
        ShareCategory.tieWon => AppString.shareHumorTieWon,
        ShareCategory.tieLost => AppString.shareHumorTieLost,
        ShareCategory.closeLoss => AppString.shareHumorCloseLoss,
        ShareCategory.bigLoss => AppString.shareHumorBigLoss,
        ShareCategory.worldLow => AppString.shareHumorWorldLow,
        ShareCategory.worldMid => AppString.shareHumorWorldMid,
        ShareCategory.worldHigh => AppString.shareHumorWorldHigh,
      };
    return key.tr;
  }
}

ShareCategory shareWorldCategory(int score) => score < kShareWorldLow
    ? ShareCategory.worldLow
    : (score <= kShareWorldHigh
          ? ShareCategory.worldMid
          : ShareCategory.worldHigh);

/// A tie goes to the home team (the duel's team A, shown on the left).
ShareCategory shareDuelCategory({
  required int myScore,
  required int opponentScore,
  required bool iAmHome,
}) {
  final gap = myScore - opponentScore;
  if (gap == 0) return iAmHome ? ShareCategory.tieWon : ShareCategory.tieLost;
  final close = gap.abs() <= kShareCloseMargin;
  if (gap > 0) return close ? ShareCategory.closeWin : ShareCategory.bigWin;
  return close ? ShareCategory.closeLoss : ShareCategory.bigLoss;
}

/// Gold / silver / bronze for the five-a-side players shown, ranked by the
/// points shown (the same ranking as [NightTopScores.medalRanks]: equal scores
/// share a rank, so a tie for 1st gives two golds and no silver).
///
/// The preview ranks only the players it draws. The real story must give the
/// night's top 3 over ALL the NBA players instead (see [NightTopScores]).
Map<String, int> shareMedals(Iterable<PlayerSelection> players) =>
    NightTopScores.medalRanks([
      for (final p in players)
        if (!p.isSixthMan)
          PlayerTodayScore(
            id: p.id,
            name: p.name,
            position: p.position,
            team: '',
            score: p.score,
          ),
    ]);

/// Everything a share story shows. The home team (the duel's team A) is
/// ALWAYS drawn on the top half and on the left of the score, whoever "me" is.
class ShareStoryData {
  final ShareCategory category;
  final String leagueName; // duels only; the World League has its own title
  final int? matchDay; // null when the server sends no number
  // "Semi-final"... instead of "Matchday N" for a playoff day.
  final String? phaseLabel;
  final DateTime date;
  final PlayerScore home;
  final PlayerScore? away; // null for the World League
  final int homeScore;
  final int awayScore;
  final bool iAmHome;
  // Night top 3: player id -> 1, 2 or 3.
  final Map<String, int> medals;

  const ShareStoryData._({
    required this.category,
    required this.matchDay,
    this.phaseLabel,
    required this.date,
    required this.home,
    required this.homeScore,
    required this.iAmHome,
    required this.medals,
    this.leagueName = '',
    this.away,
    this.awayScore = 0,
  });

  /// The category comes from the scores and from who is at home, never given.
  factory ShareStoryData.duel({
    required String leagueName,
    required int? matchDay,
    String? phaseLabel,
    required DateTime date,
    required PlayerScore home,
    required PlayerScore away,
    required int homeScore,
    required int awayScore,
    required bool iAmHome,
    Map<String, int>? medals,
  }) {
    return ShareStoryData._(
      category: shareDuelCategory(
        myScore: iAmHome ? homeScore : awayScore,
        opponentScore: iAmHome ? awayScore : homeScore,
        iAmHome: iAmHome,
      ),
      leagueName: leagueName,
      matchDay: matchDay,
      phaseLabel: phaseLabel,
      date: date,
      home: home,
      away: away,
      homeScore: homeScore,
      awayScore: awayScore,
      iAmHome: iAmHome,
      medals:
          medals ?? shareMedals([...home.selection, ...away.selection]),
    );
  }

  factory ShareStoryData.world({
    required int? matchDay,
    required DateTime date,
    required PlayerScore me,
    required int score,
    Map<String, int>? medals,
  }) {
    return ShareStoryData._(
      category: shareWorldCategory(score),
      matchDay: matchDay,
      date: date,
      home: me,
      homeScore: score,
      iAmHome: true,
      medals: medals ?? shareMedals(me.selection),
    );
  }

  bool get isDuel => !category.isWorld;

  PlayerScore get me => iAmHome ? home : away!;
  PlayerScore? get opponent => iAmHome ? away : home;
  int get myScore => iAmHome ? homeScore : awayScore;
  int get opponentScore => iAmHome ? awayScore : homeScore;

  String get dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
