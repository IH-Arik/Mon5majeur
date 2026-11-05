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

  test('the card code never adds the players up', () {
    final src = File('lib/presentation/screens/share/share_story_from_global.dart').readAsStringSync();
    expect(src, isNot(contains('fold')));
    expect(src, contains("d['total_points']"));
  });
}
