import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/data/models/match_result_model.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_button.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_capture.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_from_duel.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_from_global.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_model.dart';

Map<String, dynamic> _night({bool available = true, int? number = 8}) => {
  'available': available,
  'nba_date': '2026-10-27',
  'night_number': number,
  'team_name': 'Robin Hoops',
  'team_logo': 'lakers',
  'jersey_index': 2,
  'selection': [
    {'id': 'g1', 'name': 'Curry', 'position': 'PG', 'score': 24},
    {'id': 'w1', 'name': 'Tatum', 'position': 'SF', 'score': 32},
    {'id': 'c1', 'name': 'Jokic', 'position': 'C', 'score': 47},
    {'id': 'g2', 'name': 'Haliburton', 'position': 'SG', 'score': 17},
    {'id': 'w2', 'name': 'Durant', 'position': 'PF', 'score': 26},
  ],
};

void main() {
  testWidgets('the share button shows a spinner as soon as it is tapped', (
    tester,
  ) async {
    final building = Completer<ShareStoryData?>();
    final button = find.byWidgetPredicate((w) => w is TextButton);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(402, 874),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: ShareStoryButton(buildStory: () => building.future),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(button);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // disabled while it works: a second tap does nothing
    expect(tester.widget<TextButton>(button).onPressed, isNull);

    building.complete(null); // nothing to share: back to normal
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
  });

  test('the story is encoded as a JPEG, far lighter than raw pixels', () {
    const w = 108, h = 192;
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      rgba[i * 4] = i % 256;
      rgba[i * 4 + 1] = (i ~/ 7) % 256;
      rgba[i * 4 + 2] = 40;
      rgba[i * 4 + 3] = 255;
    }
    final jpg = encodeShareStoryJpeg(rgba, w, h);
    expect(jpg.sublist(0, 2), [0xFF, 0xD8]); // JPEG start marker
    expect(jpg.length, lessThan(rgba.length ~/ 4));
  });

  group('duel category', () {
    ShareCategory c(int mine, int theirs, {bool home = true}) =>
        shareDuelCategory(myScore: mine, opponentScore: theirs, iAmHome: home);

    test('close means a gap of 15 or less', () {
      expect(c(155, 140), ShareCategory.closeWin);
      expect(c(156, 140), ShareCategory.bigWin);
      expect(c(140, 155), ShareCategory.closeLoss);
      expect(c(140, 156), ShareCategory.bigLoss);
    });

    test('a tie goes to the home team', () {
      expect(c(150, 150), ShareCategory.tieWon);
      expect(c(150, 150, home: false), ShareCategory.tieLost);
    });
  });

  test('World League category follows the night score', () {
    expect(shareWorldCategory(79), ShareCategory.worldLow);
    expect(shareWorldCategory(80), ShareCategory.worldMid);
    expect(shareWorldCategory(120), ShareCategory.worldMid);
    expect(shareWorldCategory(121), ShareCategory.worldHigh);
  });

  group('story from the published World League night', () {
    test('score is the sum of the players, lineup in court order', () {
      final s = shareStoryFromGlobalResult(_night())!;
      expect(s.myScore, 146);
      expect(s.category, ShareCategory.worldHigh);
      expect(s.matchDay, 8);
      expect(s.dateLabel, '27/10');
      // wing, center, wing, guard, guard
      expect([for (final p in s.me.selection) p.name], [
        'Tatum',
        'Jokic',
        'Durant',
        'Curry',
        'Haliburton',
      ]);
    });

    test('medals are the ones given, none when the night cannot be ranked', () {
      expect(
        shareStoryFromGlobalResult(_night(), medals: {'c1': 1})!.medals,
        {'c1': 1},
      );
      expect(shareStoryFromGlobalResult(_night())!.medals, isEmpty);
    });

    test('no number: only the date', () {
      expect(shareStoryFromGlobalResult(_night(number: null))!.matchDay, isNull);
    });

    test('nothing to share without a published night', () {
      expect(shareStoryFromGlobalResult(_night(available: false)), isNull);
      expect(shareStoryFromGlobalResult({'available': true}), isNull);
    });
  });

  group('story from a finished duel', () {
    PlayerScore team(int id, String name, {bool empty = false, String? bonus}) =>
        PlayerScore(
          playerId: id,
          teamName: name,
          username: name,
          totalPoints: 0,
          bonus: bonus,
          selection: empty
              ? const []
              : [
                  for (var i = 0; i < 5; i++)
                    PlayerSelection(id: '$id$i', name: 'J$i', position: 'PG', score: 20 + i),
                ],
        );

    MatchResultModel result({String status = 'completed', bool hidden = false}) =>
        MatchResultModel(
          id: 1,
          leagueId: 3,
          leagueName: 'Les Potes du Lundi',
          matchDay: 8,
          matchType: 'league',
          matchDate: '2026-10-27',
          status: status,
          playerScores: const [],
          pairs: const [],
          createdAt: '',
          scoresHidden: hidden,
        );

    MatchPair pair(int a, int b) => MatchPair(
      playerAId: 1,
      playerAName: 'Moi',
      playerBId: 2,
      playerBName: 'Eux',
      scoreA: a,
      scoreB: b,
    );

    ShareStoryData? story({
      MatchResultModel? r,
      required MatchPair p,
      PlayerScore? a,
      PlayerScore? b,
      bool home = true,
      Map<String, int> medals = const {},
    }) => shareStoryFromDuel(
      result: r ?? result(),
      pair: p,
      teamA: a ?? team(1, 'Moi'),
      teamB: b ?? team(2, 'Eux'),
      iAmHome: home,
      medals: medals,
      phaseLabel: 'Demi-finale',
    );

    test('home team is player A, scores and details come from the server', () {
      final s = story(p: pair(149, 140))!;
      expect(s.home.teamName, 'Moi');
      expect(s.iAmHome, isTrue);
      expect([s.homeScore, s.awayScore], [149, 140]);
      expect(s.category, ShareCategory.closeWin);
      expect(s.leagueName, 'Les Potes du Lundi');
      expect(s.phaseLabel, 'Demi-finale');
      expect(s.dateLabel, '27/10');
    });

    test('a tie is won at home and lost away', () {
      expect(story(p: pair(150, 150))!.category, ShareCategory.tieWon);
      final away = story(p: pair(150, 150), home: false)!;
      expect(away.iAmHome, isFalse);
      expect(away.me.teamName, 'Eux');
      expect(away.home.teamName, 'Moi'); // home still on top
      expect(away.category, ShareCategory.tieLost);
    });

    test('an opponent with no lineup is shown as such', () {
      final s = story(p: pair(131, 0), b: team(2, 'Eux', empty: true))!;
      expect(s.away!.selection, isEmpty);
      final missing = shareStoryFromDuel(
        result: result(),
        pair: pair(131, 0),
        teamA: team(1, 'Moi'),
        teamB: null,
        iAmHome: true,
      )!;
      expect(missing.away!.teamName, 'Eux');
      expect(missing.category, ShareCategory.bigWin);
    });

    test('medals are the ones given', () {
      expect(story(p: pair(149, 140), medals: {'10': 1})!.medals, {'10': 1});
      expect(story(p: pair(149, 140))!.medals, isEmpty);
    });

    test('nothing to share', () {
      expect(story(r: result(status: 'live'), p: pair(1, 2)), isNull);
      expect(story(r: result(hidden: true), p: pair(1, 2)), isNull);
      // my own lineup is empty (home, then away)
      expect(story(p: pair(1, 2), a: team(1, 'Moi', empty: true)), isNull);
      expect(story(p: pair(1, 2), b: team(2, 'Eux', empty: true), home: false), isNull);
    });
  });
}
