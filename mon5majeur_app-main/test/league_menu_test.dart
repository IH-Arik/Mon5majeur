// QA 24/09 #3/#4: the private-league menu is the Global League's menu (same
// icons + Live), and the home night card opens the league on its Standings.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/my_match_today_model.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/league_tab_bar.dart';
import 'package:mon5majeur_app/presentation/widgets/match_widgets.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => GetMaterialApp(
    translations: Language(),
    locale: const Locale('fr', 'FR'),
    home: Scaffold(body: child),
  ),
);

MyMatchTodayModel _card({bool isPrivate = true, int? current}) => MyMatchTodayModel(
  id: 1,
  leagueId: 7,
  leagueName: 'Ligue',
  matchDay: 15,
  matchType: 'head_to_head',
  matchDate: '2026-09-08',
  status: 'completed',
  playerScores: const [],
  pairs: const [],
  createdAt: '',
  isPrivate: isPrivate,
  leagueCurrentMatchDay: current,
);

void main() {
  testWidgets('league menu: 4 tabs + Live, Global icon set', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    int? selected;
    var live = 0;
    await t.pumpWidget(_host(LeagueTabBar(
      selected: 0,
      onSelect: (i) => selected = i,
      onLive: () => live++,
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    for (final icon in [Icons.add, Icons.scoreboard, Icons.leaderboard, Icons.menu_book, Icons.bolt]) {
      expect(find.byIcon(icon), findsOneWidget, reason: '$icon');
    }
    expect(find.byIcon(Icons.receipt), findsNothing, reason: 'old private-league icon');
    expect(find.text('Live'), findsOneWidget);

    await t.tap(find.byIcon(Icons.leaderboard));
    expect(selected, LeagueTab.standings);
    await t.tap(find.byIcon(Icons.bolt));
    expect(live, 1);
    expect(selected, LeagueTab.standings, reason: 'Live is pushed, not switched in');
  });

  test('night card opens the league on Standings, on its current match day', () {
    expect(
      leagueRouteForMatch(_card(current: 16)),
      '/fantasyLeagueScreenForJoin/7?matchDay=16&isPrivate=true&tab=2',
    );
    // older backend (no current day): fall back to the card's own match day
    expect(leagueRouteForMatch(_card()), contains('matchDay=15'));
    expect(leagueRouteForMatch(_card(isPrivate: false, current: 16)), contains('isPrivate=false'));
  });
}
