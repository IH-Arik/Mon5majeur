// The share card shows the SERVER's total: the same number as the Results tab and
// the ranking, with or without a substitute. It is never added up from the
// players drawn on the card (that gave 136 instead of 144 for a lineup whose
// substitute had come in).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/match_result_model.dart';
import 'package:mon5majeur_app/data/models/substitution_model.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/match_lineups_field.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/out_badge.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/substitute_widgets.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_from_duel.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_from_global.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_model.dart';
import 'package:mon5majeur_app/presentation/screens/share/share_story_widget.dart';

Map<String, dynamic> p(String id, String name, String pos, int score, {bool absent = false}) =>
    {'id': id, 'name': name, 'position': pos, 'score': score, 'absent': absent};

// The four published payloads of the local simulator (the real server's answers).
Map<String, dynamic> night(String team, int total, List<Map<String, dynamic>> five,
        {Map<String, dynamic>? sub, String? state, String? replaced}) =>
    {
      'available': true,
      'nba_date': '2026-11-04',
      'night_number': 3,
      'team_name': team,
      'team_logo': 'devil',
      'jersey_index': 0,
      'total_points': total,
      'selection': five,
      'substitute': ?sub,
      'substitution': ?(sub == null ? null : {'status': state, 'replaced_id': replaced}),
    };

final me = night('Local me', 144, [
  p('1', 'Lakers SF', 'SF', 0, absent: true), p('2', 'Bucks PG', 'PG', 35), p('3', 'Nuggets SG', 'SG', 31),
  p('4', 'Knicks PF', 'PF', 24), p('5', 'Bucks C', 'C', 46),
], sub: p('s', 'Nuggets SG b', 'SG', 8), state: 'entered', replaced: '1');
final r1 = night('Local r1', 235, [
  p('1', 'Lakers PG', 'PG', 64), p('2', 'Celtics SG', 'SG', 50), p('3', 'Warriors SF', 'SF', 61),
  p('4', 'Celtics PF', 'PF', 0, absent: true), p('5', 'Nuggets C', 'C', 60),
]);
final r2 = night('Local r2', 134, [
  p('1', 'Bucks PG', 'PG', 35), p('2', 'Warriors SG', 'SG', 0, absent: true), p('3', 'Nuggets SF', 'SF', 27),
  p('4', 'Knicks PF', 'PF', 24), p('5', 'Mavs C', 'C', 31),
], sub: p('s', 'Bucks PG b', 'PG', 17), state: 'entered', replaced: '2');
final r3 = night('Local r3', 219, [
  p('1', 'Bucks PG', 'PG', 35), p('2', 'Nuggets SG', 'SG', 31), p('3', 'Knicks SF', 'SF', 34),
  p('4', 'Bucks PF', 'PF', 59), p('5', 'Nuggets C', 'C', 60),
], sub: p('s', 'Warriors C', 'C', 11), state: 'not_entered');

int sumOfStarters(Map<String, dynamic> d) =>
    [for (final e in d['selection'] as List) (e as Map)['score'] as int].fold(0, (a, b) => a + b);

final overflows = <String>[];
void Function(FlutterErrorDetails)? _prevHandler;

Future<void> showCard(WidgetTester t, ShareStoryData data) async {
  overflows.clear();
  t.view.physicalSize = const Size(400, 700);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final prev = _prevHandler = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) {
      overflows.add(d.exceptionAsString().split('\n').first);
    } else {
      prev?.call(d);
    }
  };
  addTearDown(() => FlutterError.onError = prev);
  await t.pumpWidget(ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => GetMaterialApp(
      translations: Language(),
      locale: const Locale('fr', 'FR'),
      home: Scaffold(backgroundColor: Colors.black, body: Center(child: ShareStoryWidget(data: data))),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

const pendingState = SubstitutionState(status: 'pending');

void main() {
  final accounts = {'me': me, 'r1': r1, 'r2': r2, 'r3': r3};

  group('the World League card total is the server\'s', () {
    for (final e in accounts.entries) {
      test('${e.key}: ${e.value['total_points']}', () {
        final s = shareStoryFromGlobalResult(e.value)!;
        expect(s.myScore, e.value['total_points']);
        expect(s.homeScore, e.value['total_points']);
        expect(s.me.totalPoints, e.value['total_points']);
      });
    }

    test('with a substitute who came in, it is NOT the sum of the five drawn (136 vs 144)', () {
      expect(sumOfStarters(me), 136);
      expect(shareStoryFromGlobalResult(me)!.myScore, 144);
      expect(sumOfStarters(r2), 117);
      expect(shareStoryFromGlobalResult(r2)!.myScore, 134);
    });

    test('whatever the server says, the card says: nothing is added up', () {
      for (final total in [0, 77, 144, 151]) {
        final d = Map<String, dynamic>.from(me)..['total_points'] = total;
        expect(shareStoryFromGlobalResult(d)!.myScore, total);
        final plain = Map<String, dynamic>.from(r1)..['total_points'] = total;
        expect(shareStoryFromGlobalResult(plain)!.myScore, total);
      }
    });

    test('the category follows the server total too', () {
      final d = Map<String, dynamic>.from(r3)..['total_points'] = 79;
      expect(shareStoryFromGlobalResult(d)!.category, ShareCategory.worldLow);
      expect(shareStoryFromGlobalResult(me)!.category, ShareCategory.worldHigh);
    });

    test('no total from the server: nothing to share, never a guess', () {
      final d = Map<String, dynamic>.from(me)..remove('total_points');
      expect(shareStoryFromGlobalResult(d), isNull);
    });

    test('the substitute and his state are on the card', () {
      final s = shareStoryFromGlobalResult(r3)!;
      expect(s.me.substitute!.name, 'Warriors C');
      expect(s.me.substitution!.isNotEntered, isTrue);
      expect(shareStoryFromGlobalResult(me)!.me.substitution!.isEntered, isTrue);
      expect(shareStoryFromGlobalResult(r1)!.me.substitute, isNull);
    });
  });

  group('the drawn card (iPhone-sized canvas, 360 x 640)', () {
    for (final e in accounts.entries) {
      testWidgets('${e.key}: the big number is the server\'s total', (t) async {
        final total = e.value['total_points'];
        await showCard(t, shareStoryFromGlobalResult(e.value)!);
        expect(find.text('$total'), findsOneWidget);
        if (e.key == 'me' || e.key == 'r2') {
          expect(find.text('${sumOfStarters(e.value)}'), findsNothing, reason: 'not the sum of the five drawn');
        }
      });
    }

    final onCourt = find.byKey(const ValueKey('substitute-on-court'));

    testWidgets('me: substitute on the court with 🔄, the replaced starter OUT', (t) async {
      await showCard(t, shareStoryFromGlobalResult(me)!);
      expect(onCourt, findsOneWidget);
      expect(find.byType(SubstituteEnteredMark), findsOneWidget);
      expect(find.byType(OutBadge), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('(8)'), findsNothing);
    });

    for (final e in accounts.entries) {
      testWidgets('${e.key}: the court is long enough for everything it draws (nothing cut at the bottom)', (t) async {
        await showCard(t, shareStoryFromGlobalResult(e.value)!);
        // only the vertical ones: the court's height. (The test font is wider than the real one,
        // so a few texts overflow sideways in every card, with or without a substitute.)
        final found = [for (final o in overflows) if (o.contains('bottom') || o.contains('top')) o];
        FlutterError.onError = _prevHandler;   // before expect(): a failing expect must not leave the handler replaced
        expect(found, isEmpty, reason: found.join('; '));
      });
    }

    testWidgets('r1: no substitute, the OUT starter is shown, no 🔄', (t) async {
      await showCard(t, shareStoryFromGlobalResult(r1)!);
      expect(onCourt, findsNothing);
      expect(find.byType(SubstituteEnteredMark), findsNothing);
      expect(find.byType(OutBadge), findsOneWidget);
    });

    testWidgets('r2: entered', (t) async {
      await showCard(t, shareStoryFromGlobalResult(r2)!);
      expect(onCourt, findsOneWidget);
      expect(find.byType(SubstituteEnteredMark), findsOneWidget);
      expect(find.byType(OutBadge), findsOneWidget);
    });

    testWidgets('r3: not entered: in the shadow, (11), no 🔄, nobody OUT', (t) async {
      await showCard(t, shareStoryFromGlobalResult(r3)!);
      expect(find.descendant(of: onCourt, matching: find.byKey(const ValueKey('in-the-shadow'))), findsOneWidget);
      expect(find.text('(11)'), findsOneWidget);
      expect(find.byType(SubstituteEnteredMark), findsNothing);
      expect(find.byType(OutBadge), findsNothing);
    });
  });

  group('three looks for the World League score: poor grey, ordinary orange, great gold', () {
    Color? colorOf(WidgetTester t, String text) => t.widget<Text>(find.text(text)).style?.color;

    for (final c in {70: const Color(0xFF9A9A9A), 100: const Color(0xFFE8642F), 144: const Color(0xFFFFC83D)}.entries) {
      testWidgets('${c.key} points', (t) async {
        final d = Map<String, dynamic>.from(me)..['total_points'] = c.key;
        await showCard(t, shareStoryFromGlobalResult(d)!);
        // the "PTS" word and the stamp carry the look's colour
        expect(colorOf(t, 'PTS'), c.value);
        expect(colorOf(t, 'SCORE DE LA NUIT'), c.value);
        // the number: white, except on a great night
        expect(colorOf(t, '${c.key}'), c.key == 144 ? c.value : Colors.white);
      });
    }
  });

  group('duel cards keep the server\'s scores (bonuses included)', () {
    PlayerScore team(int id, String name, {String? bonus}) => PlayerScore(
          playerId: id, teamName: name, username: name, totalPoints: 0, bonus: bonus,
          selection: [for (var i = 0; i < 5; i++) PlayerSelection(id: '$id$i', name: 'J$i', position: 'PG', score: 20)],
        );

    test('Chef Curry +3 and the 6th Man are in the server\'s score, not re-added or dropped', () {
      // the five shown add up to 100; the server says 103 (Chef Curry) and 96
      final s = shareStoryFromDuel(
        result: MatchResultModel(
          id: 1, leagueId: 3, leagueName: 'Ligue', matchDay: 8, matchType: 'league', matchDate: '2026-11-04',
          status: 'completed', playerScores: const [], pairs: const [], createdAt: '', scoresHidden: false,
        ),
        pair: MatchPair(playerAId: 1, playerAName: 'Moi', playerBId: 2, playerBName: 'Eux', scoreA: 103, scoreB: 96),
        teamA: team(1, 'Moi', bonus: 'chef_curry'),
        teamB: team(2, 'Eux'),
        iAmHome: true,
      )!;
      expect(s.homeScore, 103);
      expect(s.awayScore, 96);
      expect(s.myScore, 103);
    });
  });

  group('the duel card carries the substitutes too', () {
    PlayerScore side(int n, String name, {SubstitutionState? state, bool out = false, bool hidden = false}) => PlayerScore(
          playerId: n, teamName: name, username: name, totalPoints: 0, jerseyIndex: n, selectionHidden: hidden,
          selection: [
            for (var i = 0; i < 5; i++)
              PlayerSelection(id: '$n$i', name: 'J$i', position: ['SF', 'C', 'PF', 'PG', 'SG'][i], score: 20 + i, absent: out && i == 4),
          ],
          substitute: state == null ? null : PlayerSelection(id: '${n}s', name: 'Sub$n', position: 'PG', score: 11),
          substitution: state,
        );

    ShareStoryData duel(PlayerScore a, PlayerScore b, {int scoreA = 147, int scoreB = 245}) => shareStoryFromDuel(
          result: MatchResultModel(
            id: 1, leagueId: 3, leagueName: 'Ligue', matchDay: 1, matchType: 'league', matchDate: '2026-11-03',
            status: 'completed', playerScores: const [], pairs: const [], createdAt: '', scoresHidden: false,
          ),
          pair: MatchPair(playerAId: 1, playerAName: 'A', playerBId: 2, playerBName: 'B', scoreA: scoreA, scoreB: scoreB),
          teamA: a, teamB: b, iAmHome: true,
        )!;

    final subA = find.byKey(const ValueKey('substitute-on-court-a'));
    final subB = find.byKey(const ValueKey('substitute-on-court-b'));
    const entered = SubstitutionState(status: 'entered', replacedId: 'x');
    const notEntered = SubstitutionState(status: 'not_entered');

    testWidgets('both teams: A above the half-way line, B below; the server\'s score is the one drawn', (t) async {
      await showCard(t, duel(side(1, 'A', state: entered, out: true), side(2, 'B', state: entered)));
      expect(subA, findsOneWidget);
      expect(subB, findsOneWidget);
      expect(t.getRect(subA).bottom, lessThan(t.getRect(subB).top));
      expect(find.byType(SubstituteEnteredMark), findsNWidgets(2));
      expect(find.byType(OutBadge), findsOneWidget);
      expect(find.text('147'), findsOneWidget);
      expect(find.text('245'), findsOneWidget);
    });

    testWidgets('a substitute who did not come in (or not yet) is left off the card', (t) async {
      for (final state in [notEntered, pendingState]) {
        await showCard(t, duel(side(1, 'A', state: entered), side(2, 'B', state: state)));
        expect(subA, findsOneWidget);
        expect(subB, findsNothing);
        expect(find.text('(11)'), findsNothing);
      }
      await showCard(t, duel(side(1, 'A', state: notEntered), side(2, 'B', state: pendingState)));
      expect(subA, findsNothing);
      expect(subB, findsNothing);
    });

    testWidgets('a substitute who came in but was left out by the 6th Man: drawn in the shadow, in brackets', (t) async {
      PlayerScore leftOut(int n, String name) => PlayerScore(
            playerId: n, teamName: name, username: name, totalPoints: 0, jerseyIndex: n,
            selection: [
              for (var i = 0; i < 5; i++)
                PlayerSelection(id: '$n$i', name: 'J$i', position: ['SF', 'C', 'PF', 'PG', 'SG'][i], score: 20 + i),
            ],
            substitute: PlayerSelection(id: '${n}s', name: 'Sub$n', position: 'PG', score: 11, counted: false),
            substitution: entered,
          );
      await showCard(t, duel(leftOut(1, 'A'), side(2, 'B')));
      expect(subA, findsOneWidget);
      expect(find.descendant(of: subA, matching: find.byKey(const ValueKey('not-counted'))), findsOneWidget);
      expect(find.descendant(of: subA, matching: find.text('(11)')), findsOneWidget);
      expect(find.descendant(of: subA, matching: find.byType(SubstituteEnteredMark)), findsOneWidget);
    });

    testWidgets('on the story the substitutes are drawn at 80 % of a starter', (t) async {
      await showCard(t, duel(side(1, 'A', state: entered), side(2, 'B', state: entered)));
      // (the whole court is shrunk to the story, so compare with a starter's jersey picture)
      final starter = t.getRect(find.descendant(of: find.byType(MatchLineupsField), matching: find.byType(Opacity)).first).height;
      for (final sub in [subA, subB]) {
        final jersey = t.getRect(find.descendant(of: sub, matching: find.byType(Opacity)).last).height; // (not the shadow wrapper)
        expect(jersey / starter, closeTo(0.8, 0.02));
      }
    });

    testWidgets('nothing is cut at the bottom of the longer court', (t) async {
      await showCard(t, duel(side(1, 'A', state: entered), side(2, 'B', state: entered)));
      final found = [for (final o in overflows) if (o.contains('bottom') || o.contains('top')) o];
      expect(found, isEmpty, reason: found.join('; '));
      // the court is clipped to its frame: everything of it, down to team B's label and
      // substitute, must be inside that frame
      final frame = t.getRect(find.ancestor(of: find.byType(MatchLineupsField), matching: find.byType(ClipRect)).first);
      expect(t.getRect(find.byKey(const ValueKey('substitute-on-court-b'))).bottom, lessThanOrEqualTo(frame.bottom + 0.5));
      expect(t.getRect(find.text('B').first).bottom, lessThanOrEqualTo(frame.bottom + 0.5));
    });

    testWidgets('the court is what the story is about: it takes at least two thirds of its height', (t) async {
      await showCard(t, duel(side(1, 'A', state: entered), side(2, 'B', state: entered)));
      final frame = t.getRect(find.ancestor(of: find.byType(MatchLineupsField), matching: find.byType(ClipRect)).first);
      final card = t.getRect(find.byType(ShareStoryWidget));
      debugPrint('COURTSHARE ${frame.height / card.height}');
      expect(frame.height / card.height, greaterThan(0.66));
    });

    testWidgets('no substitute anywhere: the card is what it was, no extra court', (t) async {
      await showCard(t, duel(side(1, 'A'), side(2, 'B')));
      expect(subA, findsNothing);
      expect(subB, findsNothing);
      // team B's label sits at the bottom of the court: lower on a longer court
      // (the field itself always fills the box it is given, so its own height says nothing)
      double labelY(WidgetTester t) => t.getTopLeft(find.text('B').first).dy - t.getTopLeft(find.byType(MatchLineupsField)).dy;
      final plain = labelY(t);
      await showCard(t, duel(side(1, 'A', state: entered), side(2, 'B')));
      final withSub = labelY(t);
      expect(withSub, greaterThan(plain));
    });

    test('a duel with a lineup still hidden is not offered at all', () {
      final story = shareStoryFromDuel(
        result: MatchResultModel(
          id: 1, leagueId: 3, leagueName: 'Ligue', matchDay: 1, matchType: 'league', matchDate: '2026-11-03',
          status: 'completed', playerScores: const [], pairs: const [], createdAt: '', scoresHidden: false,
        ),
        pair: MatchPair(playerAId: 1, playerAName: 'A', playerBId: 2, playerBName: 'B', scoreA: 1, scoreB: 2),
        teamA: side(1, 'A', state: entered),
        teamB: side(2, 'B', state: entered, hidden: true),
        iAmHome: true,
      );
      expect(story, isNull);
    });
  });

  test('the card code never adds the players up', () {
    final src = File('lib/presentation/screens/share/share_story_from_global.dart').readAsStringSync();
    expect(src, isNot(contains('fold')));
    expect(src, contains("d['total_points']"));
  });
}
