import '../../../core/constants/app_strings.dart';
import '../../../data/models/match_result_model.dart';
import 'share_story_model.dart';

/// Sample stories for the debug preview. The categories, the TOP badges and
/// the scores are all computed from the lineups, never written by hand: the
/// duel score is the best 5 of the 6 players (the 6th man only replaces the
/// weakest starter when he scores more), plus 3 for Chef Curry. The real
/// story takes the final score from the server.
class ShareStorySamples {
  ShareStorySamples._();

  static final _date = DateTime(2026, 10, 28);

  static PlayerSelection _p(String id, String name, int score) =>
      PlayerSelection(id: id, name: name, position: '', score: score);

  // Court order: left wing, center, right wing, left guard, right guard.
  static PlayerScore _team(
    String name,
    String logo,
    int jersey,
    List<PlayerSelection> players, {
    String? bonus,
    bool isMe = false,
  }) => PlayerScore(
    playerId: isMe ? 1 : 2,
    teamName: name,
    username: '',
    totalPoints: players.fold(0, (a, p) => a + p.score),
    selection: players,
    teamLogo: logo,
    jerseyIndex: jersey,
    isMe: isMe,
    bonus: bonus,
  );

  // Five starters whose points add up to [total] (the center takes the rest),
  // plus Brown, the 6th man, when that bonus is used.
  static List<PlayerSelection> _lineup(
    String prefix,
    List<String> names,
    int total,
    String? bonus, {
    int sixthPoints = 11,
  }) {
    const shares = [0.22, 0.31, 0.18, 0.17, 0.12];
    final pts = [for (final s in shares) (total * s).floor()];
    pts[1] += total - pts.fold(0, (a, b) => a + b);
    return [
      for (var i = 0; i < 5; i++) _p('$prefix${i + 1}', names[i], pts[i]),
      if (bonus == 'sixth_man')
        PlayerSelection(
          id: '${prefix}6',
          name: 'Brown',
          position: '',
          score: sixthPoints,
          isSixthMan: true,
        ),
    ];
  }

  /// Best 5 of the 6 players, +3 with Chef Curry.
  static int score(PlayerScore t) {
    final pts = [for (final p in t.selection) p.score]
      ..sort((a, b) => b.compareTo(a));
    final best = pts.take(5).fold(0, (a, b) => a + b);
    return best + (t.bonus == 'chef_curry' ? 3 : 0);
  }

  static const _mine = ['Tatum', 'Jokic', 'Durant', 'Curry', 'Haliburton'];
  static const _theirs = ['Embiid', 'Davis', 'Booker', 'Doncic', 'Brunson'];

  static PlayerScore _me(int starters, {String? bonus}) => _team(
    'Robin Hoops',
    'lakers',
    2,
    _lineup('a', _mine, starters, bonus),
    bonus: bonus,
    isMe: true,
  );

  static PlayerScore _opponent(
    String name,
    int starters, {
    String? bonus,
    int sixthPoints = 11,
  }) => _team(
    name,
    'chicago_bulls',
    4,
    _lineup('b', _theirs, starters, bonus, sixthPoints: sixthPoints),
    bonus: bonus,
  );

  // [iAmHome] false puts me on the bottom half and on the right of the score.
  static ShareStoryData _duel(
    PlayerScore me,
    PlayerScore opponent, {
    bool iAmHome = true,
  }) {
    final home = iAmHome ? me : opponent;
    final away = iAmHome ? opponent : me;
    return ShareStoryData.duel(
      leagueName: 'Les Potes du Lundi',
      matchDay: 8,
      date: _date,
      home: home,
      away: away,
      homeScore: score(home),
      awayScore: score(away),
      iAmHome: iAmHome,
    );
  }

  static List<({String label, ShareStoryData data})> variants() => [
    (
      label: AppString.shareVariantBigWin,
      data: _duel(_me(186), _opponent('Dunk Stars', 141)),
    ),
    (
      label: AppString.shareVariantCloseWin,
      data: _duel(_me(152), _opponent('Dunk Stars', 147)),
    ),
    (
      label: AppString.shareVariantCloseLoss,
      data: _duel(_me(139), _opponent('Dunk Stars', 144)),
    ),
    (
      label: AppString.shareVariantBigLoss,
      data: _duel(_me(112), _opponent('Dunk Stars', 171)),
    ),
    (
      label: AppString.shareVariantTieWon,
      data: _duel(_me(150), _opponent('Dunk Stars', 150)),
    ),
    (
      label: AppString.shareVariantTieLost,
      data: _duel(_me(150), _opponent('Dunk Stars', 150), iAmHome: false),
    ),
    (
      label: AppString.shareVariantChefCurry,
      // Brown (22) beats the weakest starter (15): he counts, 133 - 15 + 22.
      data: _duel(
        _me(146, bonus: 'chef_curry'),
        _opponent(
          'Les bon gros Clebz',
          133,
          bonus: 'sixth_man',
          sixthPoints: 22,
        ),
      ),
    ),
    // Brown (11) does not beat the weakest starter: he adds nothing.
    (
      label: AppString.shareVariantBonusBoth1,
      data: _duel(
        _me(140, bonus: 'sixth_man'),
        _opponent('Dunk Stars', 130, bonus: 'chef_curry'),
      ),
    ),
    (
      label: AppString.shareVariantBonusBoth2,
      data: _duel(
        _me(138, bonus: 'luxury_tax'),
        _opponent('Les bon gros Clebz', 141, bonus: 'sixth_man'),
      ),
    ),
    (
      label: AppString.shareVariantNoOpponent,
      data: _duel(
        _me(131),
        _team('Les Fantômes', 'chicago_bulls', 4, const []),
      ),
    ),
    for (final (label, pts) in [
      (AppString.shareVariantWorldLow, 72),
      (AppString.shareVariantWorldMid, 104),
      (AppString.shareVariantWorldHigh, 146),
    ])
      (
        label: label,
        data: ShareStoryData.world(
          matchDay: 8,
          date: _date,
          me: _me(pts),
          score: pts,
        ),
      ),
  ];
}
