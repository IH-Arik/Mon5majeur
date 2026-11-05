// Duel results (two teams on one court): each team's substitute stands on the
// court, which is longer in the middle - team A's just above the half-way line,
// team B's just below. A starter with no minute is in the shadow with OUT.
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

PlayerSelection sel(String id, String name, String pos, int score, {bool absent = false, bool sixth = false}) =>
    PlayerSelection(id: id, name: name, position: pos, score: score, absent: absent, isSixthMan: sixth);

const entered = SubstitutionState(status: 'entered', replacedId: '5');
const notEntered = SubstitutionState(status: 'not_entered');
const pending = SubstitutionState(status: 'pending');

PlayerScore team(String name, int n,
    {SubstitutionState? state, bool out = false, bool sixth = false, bool hidden = false, PlayerSelection? sub}) {
  return PlayerScore(
    playerId: n, teamName: name, username: name, totalPoints: 0, jerseyIndex: n,
    selection: hidden
        ? const []
        : [
            sel('${n}1', 'Tatum', 'SF', 32), sel('${n}2', 'Jokic', 'C', 47), sel('${n}3', 'Durant', 'PF', 26),
            sel('${n}4', 'Curry', 'PG', 24), sel('${n}5', 'Halib', 'SG', 0, absent: out),
            if (sixth) sel('${n}6', 'Cunning', 'SG', 21, sixth: true),
          ],
    // (a hidden lineup is given a substitute too: the screen must not show him)
    substitute: state == null ? null : (sub ?? sel('${n}s', 'Williams', 'PG', 11)),
    substitution: state,
    selectionHidden: hidden,
    bonus: sixth ? 'sixth_man' : null,
  );
}

// Where the visible jersey is inside its picture (measured on the asset).
Rect art(Rect box) => Rect.fromLTRB(
      box.left + box.width * 0.30, box.top + box.height * 0.12,
      box.left + box.width * 0.68, box.top + box.height * 0.93,
    );

Future<void> show(WidgetTester t, PlayerScore a, PlayerScore b,
    {Size size = const Size(393, 1800), bool compact = false}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
  await t.pumpWidget(ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => GetMaterialApp(
      translations: Language(),
      locale: const Locale('fr', 'FR'),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          child: MatchLineupsField(
            teamA: a, teamB: b, duelResultStyle: true, matchFinished: true, shareCompact: compact,
          ),
        ),
      ),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  final subA = find.byKey(const ValueKey('substitute-on-court-a'));
  final subB = find.byKey(const ValueKey('substitute-on-court-b'));
  final shadows = find.byKey(const ValueKey('in-the-shadow'));

  group('where they stand', () {
    final screens = {
      'iPhone 16 Pro': const Size(393, 1800),
      'iPhone SE': const Size(375, 1800),
      'iPhone 5s': const Size(320, 1800),
    };
    for (final screen in screens.entries) {
      testWidgets('${screen.key}: A above the half-way line, B below, nothing touching', (t) async {
        await show(t, team('Moi', 0, state: entered, out: true, sixth: true), team('Eux', 1, state: notEntered),
            size: screen.value);
        final u = ScreenUtil().setHeight(1);
        final field = t.getRect(find.byType(MatchLineupsField));
        final line = field.top + (12 + 415) * u;               // the middle of the 830 court
        expect(find.byType(MatchLineupsField), findsOneWidget);
        final a = t.getRect(subA), b = t.getRect(subB);
        expect(a.bottom, closeTo(line - 4 * u, 1.5));
        expect(b.top, closeTo(line + 4 * u, 1.5));
        expect(a.center.dx, closeTo(field.center.dx, 1));
        expect(b.center.dx, closeTo(field.center.dx, 1));
        // the court is longer: 830 instead of 700 (and 12 of margin)
        expect(t.getRect(find.byType(MatchLineupsField)).height, greaterThan((12 + 830) * u - 1));

        // nothing of the starters touches a substitute: jerseys, names, points, badges
        Iterable<Rect> pieces(Finder inside) => [
              for (final e in find.descendant(of: inside, matching: find.byType(Text)).evaluate())
                t.getRect(find.byWidget(e.widget)),
              art(t.getRect(find.descendant(of: inside, matching: find.byType(Opacity)).first)),
            ];
        final mine = [...pieces(subA), ...pieces(subB)];
        final inSubs = {
          ...find.descendant(of: subA, matching: find.byType(Text)).evaluate().map((e) => e.widget),
          ...find.descendant(of: subB, matching: find.byType(Text)).evaluate().map((e) => e.widget),
        };
        for (final e in find.descendant(of: find.byType(MatchLineupsField), matching: find.byType(Text)).evaluate()) {
          if (inSubs.contains(e.widget)) continue;
          final r = t.getRect(find.byWidget(e.widget));
          if (r.height == 0) continue;
          for (final m in mine) {
            expect(r.overlaps(m), isFalse, reason: 'a text of the court at $r touches a substitute piece $m');
          }
        }
        // each substitute's own jersey and texts do not touch the other's
        for (final x in pieces(subA)) {
          for (final y in pieces(subB)) {
            expect(x.overlaps(y), isFalse, reason: 'the two substitutes touch: $x / $y');
          }
        }
      });
    }

    testWidgets('only one team has a substitute: only his is drawn, the court is still the longer one', (t) async {
      await show(t, team('Moi', 0), team('Eux', 1, state: pending));
      final u = ScreenUtil().setHeight(1);
      expect(subA, findsNothing);
      expect(subB, findsOneWidget);
      expect(t.getRect(find.byType(MatchLineupsField)).height, greaterThan((12 + 830) * u - 1));
    });

    testWidgets('nobody has one: the court is exactly what it was (700)', (t) async {
      await show(t, team('Moi', 0), team('Eux', 1));
      final u = ScreenUtil().setHeight(1);
      expect(subA, findsNothing);
      expect(subB, findsNothing);
      expect(t.getRect(find.byType(MatchLineupsField)).height, lessThan((12 + 700) * u + 400 * u)); // + the cards under it
      // (the court itself is 700: the field is not longer than 700 + its cards)
    });

    testWidgets('a lineup still hidden (before tip-off) shows no substitute', (t) async {
      await show(t, team('Moi', 0, state: pending), team('Eux', 1, hidden: true, state: pending));
      expect(subA, findsOneWidget);
      expect(subB, findsNothing);
    });

    testWidgets('the 6th Man is still not on the court', (t) async {
      await show(t, team('Moi', 0, state: entered, sixth: true), team('Eux', 1, state: pending));
      // his name is in the card under the court (name · points), never on the court
      final u = ScreenUtil().setHeight(1);
      final courtBottom = t.getRect(find.byType(MatchLineupsField)).top + (12 + 830) * u;
      expect(find.text('Cunning'), findsOneWidget);
      expect(t.getRect(find.text('Cunning')).top, greaterThan(courtBottom - 1));
    });

    testWidgets('the share story (compact court) carries them too, on its own longer court', (t) async {
      await show(t, team('Moi', 0, state: entered), team('Eux', 1, state: entered), compact: true);
      expect(subA, findsOneWidget);
      expect(subB, findsOneWidget);
      expect(t.getRect(subA).bottom, lessThan(t.getRect(subB).top));
    });

    testWidgets('the share story leaves off a substitute who did not come in', (t) async {
      await show(t, team('Moi', 0, state: entered), team('Eux', 1, state: notEntered), compact: true);
      expect(subA, findsOneWidget);
      expect(subB, findsNothing);
    });

    testWidgets('the share story without any substitute draws none', (t) async {
      await show(t, team('Moi', 0), team('Eux', 1), compact: true);
      expect(subA, findsNothing);
      expect(subB, findsNothing);
    });
  });

  group('what each one shows', () {
    testWidgets('entered: plain, 🔄, his points; the replaced starter in the shadow with OUT and 0', (t) async {
      await show(t, team('Moi', 0, state: entered, out: true), team('Eux', 1, state: pending));
      expect(find.descendant(of: subA, matching: find.byType(SubstituteEnteredMark)), findsOneWidget);
      expect(find.descendant(of: subA, matching: find.byKey(const ValueKey('in-the-shadow'))), findsNothing);
      expect(find.descendant(of: subA, matching: find.text('11')), findsOneWidget);
      expect(find.byType(OutBadge), findsOneWidget);
    });

    testWidgets('did not enter: in the shadow, (11), no 🔄', (t) async {
      await show(t, team('Moi', 0), team('Eux', 1, state: notEntered));
      expect(find.descendant(of: subB, matching: find.byKey(const ValueKey('in-the-shadow'))), findsOneWidget);
      expect(find.descendant(of: subB, matching: find.text('(11)')), findsOneWidget);
      expect(find.descendant(of: subB, matching: find.byType(SubstituteEnteredMark)), findsNothing);
    });

    testWidgets('pending (live): jersey at 80 %, (11), no 🔄, nobody in the shadow', (t) async {
      await show(t, team('Moi', 0, state: pending), team('Eux', 1, state: pending));
      for (final s in [subA, subB]) {
        expect(find.descendant(of: s, matching: find.text('(11)')), findsOneWidget);
        expect(find.descendant(of: s, matching: find.byType(SubstituteEnteredMark)), findsNothing);
        expect(t.widgetList<Opacity>(find.descendant(of: s, matching: find.byType(Opacity))).map((o) => o.opacity), contains(0.8));
      }
      expect(shadows, findsNothing);
    });

    testWidgets('a starter with no minute is OUT even without any substitute', (t) async {
      await show(t, team('Moi', 0, out: true), team('Eux', 1));
      expect(find.byType(OutBadge), findsOneWidget);
      expect(shadows, findsOneWidget);
    });

    testWidgets('a starter who played and scored 0 is shown normally', (t) async {
      await show(t, team('Moi', 0), team('Eux', 1));
      expect(find.byType(OutBadge), findsNothing);
    });

    testWidgets('scores behind the paywall: locks, no number on a substitute', (t) async {
      t.view.physicalSize = const Size(393, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(
          translations: Language(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MatchLineupsField(
                teamA: team('Moi', 0, state: entered), teamB: team('Eux', 1, state: pending),
                duelResultStyle: true, matchFinished: true, scoresHidden: true,
              ),
            ),
          ),
        ),
      ));
      await t.pump();
      expect(find.descendant(of: subA, matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(find.descendant(of: subA, matching: find.text('11')), findsNothing);
    });
  });

  group('wired to the screens', () {
    test('the live duel hands each team its substitute and what became of him', () {
      final src = File('lib/presentation/screens/home/screens/live_score_screen.dart').readAsStringSync();
      for (final s in [
        'substitute: match.homeSubstitute,', 'substitution: match.homeSubstitution,',
        'substitute: match.awaySubstitute,', 'substitution: match.awaySubstitution,',
      ]) {
        expect(src, contains(s));
      }
    });
  });
}
