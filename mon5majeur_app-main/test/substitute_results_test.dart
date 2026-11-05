// Global League results with a substitute: the lineup total, the substitute on the
// court, the starters who played no minute in the shadow with OUT, and "no
// substitute" looking exactly as before.
import 'dart:io';

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
import 'package:mon5majeur_app/presentation/screens/home/widgets/out_badge.dart';
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

  group('the substitute on the court', () {
    Future<void> court(WidgetTester t, PlayerScore teamA,
        {Locale locale = fr, bool globalStyle = true, bool showOpponent = false, bool scoresHidden = false}) async {
      t.view.physicalSize = const Size(400, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      await t.pumpWidget(host(
        locale,
        MatchLineupsField(
          teamA: teamA, teamB: null, showOpponent: showOpponent, globalResultStyle: globalStyle, scoresHidden: scoresHidden,
        ),
      ));
      await t.pumpAndSettle();
    }

    final played = [sel('1', 'Doncic', 46), sel('2', 'Jerome', 43), sel('3', 'Cunningham', 39), sel('4', 'Sengun', 39), sel('5', 'Irving', 30)];
    final onCourt = find.byKey(const ValueKey('substitute-on-court'));
    final shadows = find.byKey(const ValueKey('in-the-shadow'));

    for (final locale in [fr, en]) {
      final badge = locale == fr ? 'Non entré' : 'Did not enter';

      testWidgets('entered (${locale.languageCode}): replaced starter in the shadow with OUT and 0, substitute plain with 🔄', (t) async {
        await court(t, team(substitute: sub, state: entered), locale: locale);
        expect(onCourt, findsOneWidget);
        expect(shadows, findsOneWidget);                              // only the replaced starter
        expect(find.byType(OutBadge), findsOneWidget);
        expect(find.text('OUT'), findsOneWidget);
        expect(find.byKey(const ValueKey('starter-out')), findsOneWidget);
        expect(find.byType(SubstituteEnteredMark), findsOneWidget);
        expect(find.text('22'), findsOneWidget);                      // his points count, no brackets
        expect(find.text('(22)'), findsNothing);
        expect(find.text('0'), findsOneWidget);                       // the replaced starter shows 0
        expect(find.text(badge), findsNothing);
        expect(find.text('absent'), findsNothing);
      });

      testWidgets('did not enter (${locale.languageCode}): substitute in the shadow with (22), no badge, no 🔄, nobody OUT', (t) async {
        await court(t, team(substitute: sub, state: notEntered, selection: played), locale: locale);
        expect(onCourt, findsOneWidget);
        expect(shadows, findsOneWidget);                              // only the substitute
        expect(find.descendant(of: onCourt, matching: find.byKey(const ValueKey('in-the-shadow'))), findsOneWidget);
        expect(find.text(badge), findsNothing);
        expect(find.text('Non entré'), findsNothing);
        expect(find.text('Did not enter'), findsNothing);
        expect(find.text('(22)'), findsOneWidget);
        expect(find.text('22'), findsNothing);
        expect(find.byType(SubstituteEnteredMark), findsNothing);
        expect(find.byType(OutBadge), findsNothing);
      });
    }

    testWidgets('pending (live): jersey at 80 %, (22), no 🔄, no badge, nobody in the shadow', (t) async {
      await court(t, team(substitute: sub, state: pending, selection: played));
      expect(onCourt, findsOneWidget);
      expect(shadows, findsNothing);
      expect(find.text('(22)'), findsOneWidget);
      expect(find.byType(SubstituteEnteredMark), findsNothing);
      expect(find.byType(OutBadge), findsNothing);
      final opacities = t.widgetList<Opacity>(find.descendant(of: onCourt, matching: find.byType(Opacity))).map((o) => o.opacity);
      expect(opacities, contains(0.8));
    });

    testWidgets('no more card under the court, no sentence "X remplace Y"', (t) async {
      await court(t, team(substitute: sub, state: entered));
      expect(find.byKey(const ValueKey('substitute-card')), findsNothing);
      expect(find.textContaining('remplace'), findsNothing);
    });

    testWidgets('a starter with no minute is OUT even without any substitute', (t) async {
      await court(t, team());                                         // Irving flagged absent, no substitute
      expect(find.byType(OutBadge), findsOneWidget);
      expect(shadows, findsOneWidget);
      expect(onCourt, findsNothing);
    });

    testWidgets('a starter with no minute always shows 0, whatever score the server carries', (t) async {
      final odd = [sel('1', 'Doncic', 46), sel('2', 'Jerome', 43), sel('3', 'Cunningham', 39), sel('4', 'Sengun', 38), sel('5', 'Irving', 7, absent: true)];
      await court(t, team(selection: odd));
      expect(find.text('7'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a starter who played and scored 0 is shown normally', (t) async {
      final zero = [sel('1', 'Doncic', 46), sel('2', 'Jerome', 43), sel('3', 'Cunningham', 39), sel('4', 'Sengun', 39), sel('5', 'Irving', 0)];
      await court(t, team(selection: zero));
      expect(find.byType(OutBadge), findsNothing);
      expect(shadows, findsNothing);
    });

    testWidgets('no substitute and nobody out: exactly as before', (t) async {
      await court(t, team(selection: played));
      expect(onCourt, findsNothing);
      expect(find.byType(OutBadge), findsNothing);
      expect(shadows, findsNothing);
    });

    testWidgets('scores behind the paywall: a lock, no number', (t) async {
      await court(t, team(substitute: sub, state: entered), scoresHidden: true);
      expect(find.descendant(of: onCourt, matching: find.byIcon(Icons.lock_outline)), findsOneWidget);
      expect(find.text('22'), findsNothing);
    });

    testWidgets('an opponent\'s hidden lineup shows no substitute', (t) async {
      await court(t, team(substitute: sub, state: pending, hidden: true));
      expect(onCourt, findsNothing);
    });

    testWidgets('the duel two-team view puts no substitute on the court for now', (t) async {
      await court(t, team(substitute: sub, state: entered), globalStyle: false, showOpponent: true);
      expect(onCourt, findsNothing);
    });

    testWidgets('on the half-way line: top of his jersey on it, name and points under it, court a little longer', (t) async {
      await court(t, team(substitute: sub, state: entered));
      final subRect = t.getRect(onCourt);
      final courtRect = t.getRect(find.byType(MatchLineupsField));
      expect(subRect.center.dx, closeTo(courtRect.center.dx, 1));
      expect(subRect.bottom, lessThanOrEqualTo(courtRect.bottom));
      // court: 456 instead of 350 (after a 12 margin); line at 350; his box starts 9 above it (341)
      final u = ScreenUtil().setHeight(1);
      final line = courtRect.top + (12 + 350) * u;
      expect(courtRect.height, closeTo((12 + 456) * u, 1));
      expect(subRect.top, closeTo(courtRect.top + (12 + 341) * u, 1));
      expect(subRect.top + subRect.height * 9 / 107, closeTo(line, 1), reason: 'the drawn jersey starts on the line');
      // name and points are in the other half
      final texts = find.descendant(of: onCourt, matching: find.byType(Text));
      for (final e in texts.evaluate()) {
        final r = t.getRect(find.byWidget(e.widget));
        if (r.height > 0) expect(r.top, greaterThanOrEqualTo(line), reason: 'a text of the substitute is above the line');
      }
      // and nothing of the starters reaches him
      for (final starter in ['Doncic', 'Jerome', 'Cunningham', 'Sengun', 'Irving']) {
        final r = t.getRect(find.text(starter));
        expect(r.bottom, lessThanOrEqualTo(line), reason: '$starter is in the substitute\'s half');
      }
    });

    testWidgets('a lineup without substitute keeps the short court; with one, every screen gets the same longer court', (t) async {
      await court(t, team(selection: played));
      final short = t.getRect(find.byType(MatchLineupsField)).height;
      await court(t, team(substitute: sub, state: entered));
      final long = t.getRect(find.byType(MatchLineupsField)).height;
      final u = ScreenUtil().setHeight(1);
      expect(short, closeTo((12 + 350) * u, 1));
      expect(long, closeTo((12 + 456) * u, 1));
    });
  });

  testWidgets('🔄 alone, no background, to the right of his jersey', (t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    await t.pumpWidget(host(fr, MatchLineupsField(
      teamA: team(substitute: sub, state: entered), teamB: null, showOpponent: false, globalResultStyle: true,
    )));
    await t.pumpAndSettle();
    final mark = find.byType(SubstituteEnteredMark);
    expect(mark, findsOneWidget);
    expect(find.descendant(of: mark, matching: find.byType(DecoratedBox)), findsNothing);
    expect(find.descendant(of: mark, matching: find.byType(Container)), findsNothing);
    expect(find.descendant(of: mark, matching: find.byIcon(Icons.sync)), findsOneWidget);
    final subBox = t.getRect(find.byKey(const ValueKey('substitute-on-court')).first);
    expect(t.getCenter(mark).dx, greaterThan(subBox.center.dx), reason: 'right of the jersey');
    expect(t.getRect(mark).right, lessThanOrEqualTo(subBox.center.dx + 45.0 + 2), reason: 'inside his own column');
  });

  test('the badge of the player picker and the courts is one widget', () {
    final picker = File('lib/presentation/screens/home/screens/select_player_screen.dart').readAsStringSync();
    final field = File('lib/presentation/screens/home/widgets/match_lineups_field.dart').readAsStringSync();
    expect(picker, contains('const OutBadge()'));
    expect(field, contains('const OutBadge()'));
  });
}
