// Global League results with a substitute: the lineup total, the card under the
// court, the replaced starter greyed, and "no substitute" looking exactly as before.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/core/utils/lineup_rules.dart';
import 'package:mon5majeur_app/data/models/live_score_model.dart';
import 'package:mon5majeur_app/data/models/match_result_model.dart';
import 'package:mon5majeur_app/data/models/substitution_model.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/match_lineups_field.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/substitute_widgets.dart';

PlayerSelection sel(String id, String name, int score, {bool absent = false}) =>
    PlayerSelection(id: id, name: name, position: 'PG', score: score, absent: absent);

final starters = [
  sel('1', 'Doncic', 46),
  sel('2', 'Jerome', 43),
  sel('3', 'Cunningham', 39),
  sel('4', 'Sengun', 39),
  sel('5', 'Irving', 0, absent: true),
];
final sub = sel('s', 'Jaylin Williams', 22);

PlayerScore team({
  PlayerSelection? substitute,
  SubstitutionState? state,
  List<PlayerSelection>? selection,
  bool hidden = false,
}) =>
    PlayerScore(
      playerId: 0, teamName: 'My team', username: '', totalPoints: 0,
      selection: selection ?? starters, substitute: substitute, substitution: state,
      selectionHidden: hidden,
    );

const entered = SubstitutionState(status: 'entered', replacedId: '5');
const notEntered = SubstitutionState(status: 'not_entered');
const pending = SubstitutionState(status: 'pending');

LivePlayerScore live(String id, String name, double score, {bool absent = false, String slot = 'STARTER'}) =>
    LivePlayerScore(
      playerId: id, fullName: name, slot: slot, points: 0, rebounds: 0, assists: 0, steals: 0,
      blocks: 0, turnovers: 0, minutesPlayed: 0, fantasyScoreLive: score, isFinalized: false,
      isCounted: true, isAbsent: absent,
    );

Widget host(Locale locale, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => GetMaterialApp(
        translations: Language(),
        locale: locale,
        home: Scaffold(backgroundColor: Colors.black, body: SingleChildScrollView(child: child)),
      ),
    );

const fr = Locale('fr', 'FR');
const en = Locale('en', 'US');

void main() {
  group('lineup total (what the screens add up)', () {
    test('without a substitute: the plain sum, exactly as before', () {
      final plain = [sel('1', 'A', 40), sel('2', 'B', 30), sel('3', 'C', 20), sel('4', 'D', 15), sel('5', 'E', 10)];
      expect(lineupPointsTotal(team(selection: plain)), 115);
    });

    test('entered: the absent starter counts for nothing, the substitute counts', () {
      expect(lineupPointsTotal(team(substitute: sub, state: entered)), 46 + 43 + 39 + 39 + 22);
    });

    test('not entered / pending: the substitute never counts', () {
      expect(lineupPointsTotal(team(substitute: sub, state: notEntered)), 46 + 43 + 39 + 39);
      expect(lineupPointsTotal(team(substitute: sub, state: pending)), 46 + 43 + 39 + 39);
    });

    test('a starter flagged absent never counts, whatever score he carries', () {
      final odd = [...starters.take(4), sel('5', 'Irving', 7, absent: true)];
      expect(lineupPointsTotal(team(selection: odd)), 46 + 43 + 39 + 39);
      expect(lineupPointsTotal(team(selection: odd, substitute: sub, state: entered)), 46 + 43 + 39 + 39 + 22);
    });

    test('an absent starter with no substitute still counts 0', () {
      expect(lineupPointsTotal(team()), 46 + 43 + 39 + 39);
    });

    test('the name of the replaced starter', () {
      expect(replacedStarterName(team(substitute: sub, state: entered)), 'Irving');
      expect(replacedStarterName(team(substitute: sub, state: notEntered)), isNull);
      expect(replacedStarterName(team()), isNull);
    });
  });

  group('live total (same rule as the server)', () {
    final five = [
      live('1', 'A', 46), live('2', 'B', 43), live('3', 'C', 39), live('4', 'D', 39),
      live('5', 'E', 0, absent: true),
    ];
    final s = live('s', 'Sub', 22, slot: 'SUBSTITUTE');

    test('no substitute: best five of the lineup, as before', () {
      expect(liveLineupTotal(starters: [for (final p in five) live(p.playerId, p.fullName, p.fantasyScoreLive)]), 167);
    });

    test('pending: the substitute is not counted yet', () {
      expect(liveLineupTotal(starters: five, substitute: s, substitution: pending), 46 + 43 + 39 + 39);
    });

    test('entered: he takes the replaced starter\'s place', () {
      expect(liveLineupTotal(starters: five, substitute: s, substitution: entered), 46 + 43 + 39 + 39 + 22);
    });

    test('with a 6th Man: substitution first, then the best five of six', () {
      final sixth = [live('6', 'Sixth', 38, slot: 'SIXTH_MAN')];
      // counted: 46 43 39 39 + 22 (substitute) + 38 (6th man) -> best five = 46+43+39+39+38
      expect(liveLineupTotal(starters: five, sixth: sixth, substitute: s, substitution: entered), 205);
    });

    test('not entered: nothing changes', () {
      expect(liveLineupTotal(starters: five, substitute: s, substitution: notEntered), 46 + 43 + 39 + 39);
    });
  });

  group('the card', () {
    for (final entry in {fr: ['🔄 Jaylin Williams remplace Irving', 'Non entré'], en: ['🔄 Jaylin Williams replaces Irving', 'Did not enter']}.entries) {
      final locale = entry.key;
      final replaces = entry.value[0];
      final badge = entry.value[1];

      testWidgets('entered (${locale.languageCode}): "$replaces", points counted', (t) async {
        await t.pumpWidget(host(locale, SubstituteResultCard(substitute: sub, state: entered, replacedName: 'Irving')));
        await t.pumpAndSettle();
        expect(find.text(replaces), findsOneWidget);
        expect(find.text('22'), findsOneWidget);
        expect(find.text('(22)'), findsNothing);
        expect(find.byKey(const ValueKey('substitute-not-entered')), findsNothing);
      });

      testWidgets('did not enter (${locale.languageCode}): "$badge", (22), no 🔄', (t) async {
        await t.pumpWidget(host(locale, SubstituteResultCard(substitute: sub, state: notEntered)));
        await t.pumpAndSettle();
        expect(find.text(badge), findsOneWidget);
        expect(find.text('(22)'), findsOneWidget);
        expect(find.text('22'), findsNothing);
        expect(find.byKey(const ValueKey('substitute-replaces')), findsNothing);
        expect(find.textContaining('🔄'), findsNothing);
      });
    }

    testWidgets('the 🔄 line only exists once he really came in, even if a name is passed', (t) async {
      for (final state in [notEntered, pending]) {
        await t.pumpWidget(host(fr, SubstituteResultCard(substitute: sub, state: state, replacedName: 'Irving')));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('substitute-replaces')), findsNothing, reason: state.status);
        expect(find.textContaining('remplace'), findsNothing, reason: state.status);
      }
    });

    testWidgets('pending (live): points in brackets, no 🔄, no "did not enter" badge', (t) async {
      await t.pumpWidget(host(fr, SubstituteResultCard(substitute: sub, state: pending)));
      await t.pumpAndSettle();
      expect(find.text('(22)'), findsOneWidget);
      expect(find.textContaining('🔄'), findsNothing);
      expect(find.byKey(const ValueKey('substitute-not-entered')), findsNothing);
    });

    testWidgets('scores behind the paywall: a lock, no number', (t) async {
      await t.pumpWidget(host(fr, SubstituteResultCard(substitute: sub, state: entered, replacedName: 'Irving', scoresHidden: true)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('substitute-points')), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('the court (Global League results)', () {
    Future<void> court(WidgetTester t, PlayerScore teamA, {bool globalStyle = true, bool showOpponent = false}) async {
      t.view.physicalSize = const Size(400, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      await t.pumpWidget(host(
        fr,
        MatchLineupsField(teamA: teamA, teamB: null, showOpponent: showOpponent, globalResultStyle: globalStyle),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('entered: the replaced starter is greyed "absent" and the card follows', (t) async {
      await court(t, team(substitute: sub, state: entered));
      expect(find.byKey(const ValueKey('starter-absent')), findsOneWidget);
      expect(find.text('absent'), findsOneWidget);
      expect(find.byKey(const ValueKey('substitute-card')), findsOneWidget);
      expect(find.text('🔄 Jaylin Williams remplace Irving'), findsOneWidget);
    });

    testWidgets('did not enter: the card, nobody greyed', (t) async {
      final all = [sel('1', 'Doncic', 46), sel('2', 'Jerome', 43), sel('3', 'Cunningham', 39), sel('4', 'Sengun', 39), sel('5', 'Irving', 30)];
      await court(t, team(substitute: sub, state: notEntered, selection: all));
      expect(find.byKey(const ValueKey('starter-absent')), findsNothing);
      expect(find.text('Non entré'), findsOneWidget);
    });

    testWidgets('no substitute: exactly as before (no card, no "absent" mention)', (t) async {
      final all = [sel('1', 'Doncic', 46), sel('2', 'Jerome', 43), sel('3', 'Cunningham', 39), sel('4', 'Sengun', 39), sel('5', 'Irving', 30)];
      await court(t, team(selection: all));
      expect(find.byKey(const ValueKey('substitute-card')), findsNothing);
      expect(find.byKey(const ValueKey('starter-absent')), findsNothing);
    });

    testWidgets('an opponent\'s hidden lineup shows no substitute', (t) async {
      await court(t, team(substitute: sub, state: pending, hidden: true));
      expect(find.byKey(const ValueKey('substitute-card')), findsNothing);
    });

    testWidgets('the duel two-team view is untouched for now', (t) async {
      await court(t, team(substitute: sub, state: entered), globalStyle: false, showOpponent: true);
      expect(find.byKey(const ValueKey('substitute-card')), findsNothing);
    });
  });
}
