// QA #10 layout checks: the Global results court (items 10/13/14) and the duel
// bonus card (item 17), rendered with fake data in French.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/match_result_model.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/match_lineups_field.dart';

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => GetMaterialApp(
        translations: Language(),
        locale: const Locale('fr', 'FR'),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(child: child),
        ),
      ),
    );

List<PlayerSelection> _five() => [
      PlayerSelection(id: '1', name: 'Wing One', position: 'SF', score: 0),
      PlayerSelection(id: '2', name: 'Center One', position: 'C', score: 10),
      PlayerSelection(id: '3', name: 'Wing Two', position: 'PF', score: 0),
      PlayerSelection(id: '4', name: 'Guard One', position: 'PG', score: 0),
      PlayerSelection(id: '5', name: 'Guard Two', position: 'SG', score: 18),
    ];

PlayerScore _team(String name,
        {List<PlayerSelection>? sel, String? bonus, bool hidden = false}) =>
    PlayerScore(
      playerId: 1,
      teamName: name,
      username: '',
      totalPoints: 28,
      selection: sel ?? _five(),
      bonus: bonus,
      bonusHidden: hidden,
    );

void main() {
  testWidgets('Global results: points pill under the court, no bonus card',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(MatchLineupsField(
      teamA: _team('Rob1'),
      teamB: null,
      showOpponent: false,
      showSummary: false,
      totalPill: 28,
    )));
    await tester.pump();

    expect(find.text('28 Points'), findsOneWidget);
    expect(find.text('Rob1'), findsOneWidget);
    expect(find.text('Aucun bonus'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Global results: a day without lineup says so and shows 0 Points',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(MatchLineupsField(
      teamA: _team('robzerr', sel: const []),
      teamB: null,
      showOpponent: false,
      showSummary: false,
      totalPill: 0,
      emptyMessage: "Pas d'équipe composée ce jour-là",
    )));
    await tester.pump();

    expect(find.text("Pas d'équipe composée ce jour-là"), findsOneWidget);
    expect(find.text('0 Points'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Duel results: ONE bonus card with both columns and the 3 states',
      (tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(MatchLineupsField(
      teamA: _team('robzerr', bonus: null),          // no bonus
      teamB: _team('Snake Sixers', hidden: true),     // not revealed yet
    )));
    await tester.pump();

    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('Aucun bonus'), findsOneWidget);
    expect(find.text('9h00'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
