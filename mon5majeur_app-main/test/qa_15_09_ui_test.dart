// Layout / state checks for the QA 15/09/2026 UI (items 4-9). These render the
// real widgets with fake data at a small phone width, in French, and fail on
// any overflow or build exception.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/core/utils/datetime_format.dart';
import 'package:mon5majeur_app/data/models/match_result_model.dart' as mr;
import 'package:mon5majeur_app/data/models/my_match_today_model.dart';
import 'package:mon5majeur_app/data/models/playoff_bracket_model.dart';
import 'package:mon5majeur_app/presentation/screens/home/tabs/match_results_dialog.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/match_lineups_field.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/position_label.dart';
import 'package:mon5majeur_app/presentation/widgets/match_widgets.dart';

Widget _host(Widget child, {String lang = 'fr'}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => GetMaterialApp(
      translations: Language(),
      locale: Locale(lang, lang == 'fr' ? 'FR' : 'US'),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

MyMatchTodayModel _match({
  String status = 'completed',
  bool hidden = false,
  bool live = false,
  String league = 'Completed Super League With A Very Long Name',
  String a = 'Dunk Stars Basketball Club',
  String b = 'Les Requins de Marseille',
}) {
  return MyMatchTodayModel(
    id: 1,
    leagueId: 7,
    leagueName: league,
    matchDay: 16,
    matchType: 'head_to_head',
    matchDate: '2026-09-08',
    status: status,
    playerScores: const [],
    pairs: [
      MatchPair(
        playerAId: 1,
        playerAName: a,
        playerBId: 2,
        playerBName: b,
        scoreA: hidden ? 0 : 101,
        scoreB: hidden ? 0 : 98,
        matchObjectId: 'abc',
      ),
    ],
    createdAt: '',
    isLiveForUser: live,
    resultAvailable: !hidden,
    scoresHidden: hidden,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'userId': '1'}));

  testWidgets('finished match shows Terminé, spaced score, wrapped names', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(NightMatchCard(match: _match())));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text('101'), findsOneWidget);
    expect(find.text('98'), findsOneWidget);
    // Full names, never ellipsised.
    expect(find.text('Completed Super League With A Very Long Name'), findsOneWidget);
    expect(find.text('Dunk Stars Basketball Club'), findsOneWidget);
    expect(find.text('Journée 16'), findsOneWidget);
    expect(find.text('08/09/2026'), findsOneWidget);
    expect(find.text('Duel'), findsOneWidget);
  });

  testWidgets('live match: En cours + no digits while scores are paywalled', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(NightMatchCard(match: _match(status: 'live', hidden: true))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Score dispo à 9h'), findsOneWidget);
    expect(find.text('101'), findsNothing);
  });

  testWidgets('English locale uses Live/Final and Sep 8, 2026', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(NightMatchCard(match: _match()), lang: 'en'));
    await t.pumpAndSettle();
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Sep 8, 2026'), findsOneWidget);
    expect(find.text('Matchday 16'), findsOneWidget);
  });

  testWidgets('position label shows the full "PG/SG"', (t) async {
    await t.pumpWidget(_host(const Center(child: PositionLabel('PG/SG'))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('PG/SG'), findsOneWidget);
    final box = t.getSize(find.byType(PositionLabel));
    expect(box.height, greaterThan(12)); // room above and below the text
  });

  testWidgets('lineups field: scores hidden shows locks, not numbers', (t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    mr.PlayerScore team(String n) => mr.PlayerScore(
      playerId: 1,
      teamName: n,
      username: n,
      totalPoints: 0,
      selection: [
        for (var i = 0; i < 5; i++)
          mr.PlayerSelection(id: '$i', name: 'Joueur $i', position: 'PG', score: 0),
      ],
    );
    await t.pumpWidget(_host(MatchLineupsField(teamA: team('A'), teamB: team('B'), scoresHidden: true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(10));

    await t.pumpWidget(_host(MatchLineupsField(teamA: null, teamB: null)));
    await t.pumpAndSettle();
    expect(find.text('Équipes pas encore prêtes'), findsOneWidget);
    expect(
      find.text('Les deux joueurs doivent composer leur équipe avant le début du match.'),
      findsOneWidget,
    );
  });

  testWidgets('series dialog: title, series score, games, hidden game, close', (t) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final series = PlayoffSeries(
      seriesIndex: 0,
      round: 'semi_final',
      teamAId: 1,
      teamAName: 'Les Requins de Marseille',
      teamBId: 2,
      teamBName: 'Dunk Stars Basketball Club',
      winsA: 1,
      winsB: 0,
      isComplete: false,
      hasHiddenScores: true,
      games: [
        PlayoffGame(gameNumber: 1, scoreA: 110, scoreB: 99, winnerTeam: 'x', matchDay: 19, matchStatus: 'completed'),
        PlayoffGame(gameNumber: 2, scoreA: 0, scoreB: 0, winnerTeam: '', matchDay: 20, matchStatus: 'completed', scoresHidden: true),
      ],
    );
    await t.pumpWidget(_host(SeriesDialog(series: series, leagueId: 7, isPrivate: true)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Demi-finale'), findsOneWidget);
    expect(find.text('Série : 1-0'), findsOneWidget);
    expect(find.text('Demi-finale — Match 1'), findsOneWidget);
    expect(find.text('Demi-finale — Match 2'), findsOneWidget);
    expect(find.text('110'), findsOneWidget);
    expect(find.text('Score dispo à 9h'), findsOneWidget);
    expect(find.text('Toi'), findsNWidgets(2)); // user 1 is in the series
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Quart de finale Journée 1'), findsNothing);
  });

  test('countdown and date helpers', () {
    Get.locale = const Locale('fr', 'FR');
    Get.addTranslations(Language().keys);
    expect(formatCountdown(4 * 3600 + 12 * 60 + 5), '4 h 12 min');
    expect(formatCountdown(12 * 60), '12 min');
    expect(formatMatchDate('2026-09-08'), '08/09/2026');
    expect(AppString.joinLeague.tr, 'Rejoindre une ligue');
    expect(AppString.createALeague.tr, 'Créer une ligue');
    expect(AppString.buildYourTeam.tr, 'Crée ton équipe');
    expect(AppString.youNeedMorePlayers(5), 'Il te manque encore 5 joueurs');
    expect(AppString.youNeedMorePlayers(1), 'Il te manque encore 1 joueur');
    expect(AppString.fourHoursLeft.tr, '4 heures restantes');
    expect(AppString.changeJersey.tr.replaceAll('\n', ' '), 'Changer de maillot');
  });

  test('literal-keyed messages translate in FR and fall back to English', () {
    Get.addTranslations(Language().keys);
    Get.locale = const Locale('fr', 'FR');
    expect('Network error'.tr, 'Erreur réseau');
    expect('Please enter your email'.tr, 'Entre ton e-mail');
    expect(
      'Available: @n / @m players'.trParams({'n': '3', 'm': '10'}),
      'Disponibles : 3 / 10 joueurs',
    );
    expect('@n/@m Teams'.trParams({'n': '4', 'm': '10'}), '4/10 équipes');
    expect(
      'Buy @name for @cost tokens?\n\nYour balance: @bal tokens.'
          .trParams({'name': 'Pack', 'cost': '5', 'bal': '9'}),
      'Acheter Pack pour 5 jetons ?\n\nTon solde : 9 jetons.',
    );
    Get.locale = const Locale('en', 'US');
    expect('Network error'.tr, 'Network error');
    expect(
      'Available: @n / @m players'.trParams({'n': '3', 'm': '10'}),
      'Available: 3 / 10 players',
    );
  });
}
