// Duels: "in brackets = does not count". A player the best 5 of 6 left out (a
// starter, a substitute who came in, the 6th Man) is in the shadow with his points
// in brackets, as the server says ("counted": false). He is no OUT: he did play.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/data/models/match_result_model.dart';
import 'package:mon5majeur_app/data/models/substitution_model.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/out_badge.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/substitute_widgets.dart';

import 'substitute_duel_results_test.dart' show entered, notEntered, pending, show;

PlayerSelection p(String id, String name, String pos, int score,
        {bool absent = false, bool sixth = false, bool counted = true}) =>
    PlayerSelection(id: id, name: name, position: pos, score: score, absent: absent, isSixthMan: sixth, counted: counted);

PlayerScore side(String name, int n,
    {int curry = 24, bool curryCounted = true, bool out = false, bool outCounted = true,
     PlayerSelection? sixth, PlayerSelection? sub, SubstitutionState? state}) {
  return PlayerScore(
    playerId: n, teamName: name, username: name, totalPoints: 0, jerseyIndex: n,
    selection: [
      p('${n}1', 'Tatum', 'SF', 32), p('${n}2', 'Jokic', 'C', 47), p('${n}3', 'Durant', 'PF', 26),
      p('${n}4', 'Curry', 'PG', curry, counted: curryCounted),
      p('${n}5', 'Halib', 'SG', 0, absent: out, counted: outCounted),
      ?sixth,
    ],
    substitute: sub, substitution: state, bonus: sixth != null ? 'sixth_man' : null,
  );
}

void main() {
  final notCounted = find.byKey(const ValueKey('not-counted'));
  final sixthOut = find.byKey(const ValueKey('sixth-not-counted'));
  final other = side('Eux', 1);

  group('the model', () {
    test('"counted" is read from the server, true when it says nothing', () {
      expect(PlayerSelection.fromJson({'id': 'a', 'counted': false}).counted, isFalse);
      expect(PlayerSelection.fromJson({'id': 'a', 'counted': true}).counted, isTrue);
      expect(PlayerSelection.fromJson({'id': 'a'}).counted, isTrue);          // Global League, older servers
    });
  });

  group('a starter left out by the 6th Man', () {
    testWidgets('in the shadow, points in brackets, no OUT badge', (t) async {
      await show(t, side('Moi', 0, curry: 9, curryCounted: false, sixth: p('06', 'Cunning', 'SG', 30, sixth: true)), other);
      expect(notCounted, findsOneWidget);
      expect(find.descendant(of: notCounted, matching: find.text('(9)')), findsOneWidget);
      expect(find.byType(OutBadge), findsNothing);
    });

    testWidgets('everybody counted: nothing in the shadow, plain points', (t) async {
      await show(t, side('Moi', 0), other);
      expect(notCounted, findsNothing);
      expect(find.text('(24)'), findsNothing);
    });

    testWidgets('an OUT starter stays OUT with 0 even when he is not counted', (t) async {
      await show(t, side('Moi', 0, out: true, outCounted: false, sixth: p('06', 'Cunning', 'SG', 30, sixth: true)), other);
      expect(find.byType(OutBadge), findsOneWidget);
      expect(notCounted, findsNothing);                  // one shadow only: the OUT one
    });
  });

  group('the substitute', () {
    PlayerSelection sub(int score, {bool counted = true}) => p('0s', 'Williams', 'PG', score, counted: counted);

    testWidgets('came in and counts: plain, with the sync mark', (t) async {
      await show(t, side('Moi', 0, out: true, sub: sub(22), state: entered), other);
      expect(find.byType(SubstituteEnteredMark), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(notCounted, findsNothing);
    });

    testWidgets('came in but left out: the mark stays, shadow and (11)', (t) async {
      await show(t, side('Moi', 0, out: true, sub: sub(11, counted: false), state: entered,
          sixth: p('06', 'Cunning', 'SG', 21, sixth: true)), other);
      final sub0 = find.byKey(const ValueKey('substitute-on-court-a'));
      expect(find.descendant(of: sub0, matching: find.byType(SubstituteEnteredMark)), findsOneWidget);
      expect(find.descendant(of: sub0, matching: find.byKey(const ValueKey('not-counted'))), findsOneWidget);
      expect(find.descendant(of: sub0, matching: find.text('(11)')), findsOneWidget);
      expect(find.byType(OutBadge), findsOneWidget);     // the replaced starter, as before
    });

    testWidgets('did not come in / pending: as before, never the new shadow', (t) async {
      await show(t, side('Moi', 0, sub: sub(11, counted: false), state: notEntered),
          side('Eux', 1, sub: sub(11, counted: false), state: pending));
      expect(notCounted, findsNothing);
      expect(find.byKey(const ValueKey('in-the-shadow')), findsOneWidget);   // the one who did not enter
    });
  });

  group('the 6th Man', () {
    testWidgets('left out: his points in brackets and dimmed under the court', (t) async {
      await show(t, side('Moi', 0, sixth: p('06', 'Cunning', 'SG', 21, sixth: true, counted: false)), other);
      expect(sixthOut, findsOneWidget);
      expect(find.descendant(of: sixthOut, matching: find.text('(21)')), findsOneWidget);
    });

    testWidgets('counted: plain points', (t) async {
      await show(t, side('Moi', 0, sixth: p('06', 'Cunning', 'SG', 30, sixth: true)), other);
      expect(sixthOut, findsNothing);
      expect(find.text('30'), findsWidgets);
    });
  });

  test('Live passes the server\'s "is_counted" through to the court', () {
    final src = File('lib/presentation/screens/home/screens/live_score_screen.dart').readAsStringSync();
    expect(src, contains('counted: p.isCounted'));
  });
}
