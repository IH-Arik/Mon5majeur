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
import 'package:auto_size_text/auto_size_text.dart';
import 'package:mon5majeur_app/presentation/screens/home/controllers/home_controller.dart';
import 'package:mon5majeur_app/presentation/screens/home/home_screen.dart' show HomeActionCard;
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

  testWidgets('position label shows the full "PG/SG" in a compact pill', (t) async {
    // Phone-shaped viewport (ScreenUtil scales .sp by width, .h by height).
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(const Center(child: PositionLabel('PG/SG'))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('PG/SG'), findsOneWidget);
    final box = t.getSize(find.byType(PositionLabel));
    // QA 24/09 #2: the pill had grown too big. Still room above/below the
    // text (> 9), but compact (<= 16 tall) and hugging its text - well under
    // the 114 px jersey slot it sits in (it used to stretch to the full slot
    // width). The test font is wider than Roboto, hence the generous bound.
    expect(box.height, greaterThan(9));
    expect(box.height, lessThanOrEqualTo(16));
    expect(box.width, lessThanOrEqualTo(60));
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

  test('home card refresh: 30 s while a match is live, 2 min otherwise', () {
    expect(matchRefreshInterval([_match(status: 'live')]), const Duration(seconds: 30));
    expect(
      matchRefreshInterval([_match(status: 'completed'), _match(status: 'live')]),
      const Duration(seconds: 30),
    );
    expect(matchRefreshInterval([_match(status: 'completed')]), const Duration(minutes: 2));
    expect(matchRefreshInterval([]), const Duration(minutes: 2));
  });

  test('shop pack texts have the French wording provided in QA 24/09 #7', () {
    Get.addTranslations(Language().keys);
    Get.locale = const Locale('fr', 'FR');
    const nb = ' ';
    expect('Buy @price'.trParams({'price': '1,99 €'}), 'Acheter 1,99 €');
    expect('@n TOKENS'.trParams({'n': '200'}), '200 JETONS');
    expect('POPULAR'.tr, 'POPULAIRE');
    expect('BEST VALUE'.tr, 'MEILLEURE OFFRE');
    expect('Restore Purchases'.tr, 'Restaurer les achats');
    expect(
      '200 tokens to enter tournaments and tweak your weekly lineup.'.tr,
      '200 jetons pour participer aux tournois et ajuster ton équipe de la semaine.',
    );
    expect(
      '550 tokens — perfect for active players unlocking daily boosts.'.tr,
      '550 jetons — parfait pour les joueurs actifs qui veulent débloquer des boosts au quotidien.',
    );
    expect(
      '1,200 tokens for competitive managers competing for championships.'.tr,
      '1${nb}200 jetons pour les managers compétitifs qui visent les titres.',
    );
    expect(
      '2,500 tokens — ultimate power pack with maximum bonus capacity.'.tr,
      '2${nb}500 jetons — le pack ultime, avec la capacité de bonus maximale.',
    );
    // Target pack prices in French (1,99 € / 4,99 € / 9,99 € / 19,99 €)
    Get.locale = const Locale('fr', 'FR');
    expect(AppString.rookiePrice.tr, '1,99 €');
    expect(AppString.allStarPrice.tr, '4,99 €');
    expect(AppString.mvpPrice.tr, '9,99 €');
    expect(AppString.hallOfFamePrice.tr, '19,99 €');
    expect('Buy @price'.trParams({'price': '4,99 €'}), 'Acheter 4,99 €');

    // Target pack prices in English (euros, not $US)
    Get.locale = const Locale('en', 'US');
    expect(AppString.rookiePrice.tr, '1.99 €');
    expect(AppString.allStarPrice.tr, '4.99 €');
    expect(AppString.mvpPrice.tr, '9.99 €');
    expect(AppString.hallOfFamePrice.tr, '19.99 €');
    expect('Buy @price'.trParams({'price': '4.99 €'}), 'Buy 4.99 €');
    expect('@n TOKENS'.trParams({'n': '550'}), '550 TOKENS');
    expect('Restore Purchases'.tr, 'Restore Purchases');
  });

  testWidgets('home "Rejoindre / Créer une ligue" cards: same size, one line, aligned', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // the titles are resolved when the widgets are built, before the app exists
    Get.addTranslations(Language().keys);
    Get.locale = const Locale('fr', 'FR');
    final group = AutoSizeGroup();
    await t.pumpWidget(_host(Row(
      children: [
        Expanded(child: HomeActionCard(title: AppString.joinLeague.tr, group: group, delay: 0, onTap: () {})),
        const SizedBox(width: 16),
        Expanded(child: HomeActionCard(title: AppString.createALeague.tr, group: group, delay: 0, onTap: () {})),
      ],
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    final join = find.text('Rejoindre une ligue', findRichText: true);
    final create = find.text('Créer une ligue', findRichText: true);
    expect(join, findsOneWidget);
    expect(create, findsOneWidget);
    // one line each and identical size -> labels sit at the same height
    final joinBox = t.getRect(join);
    final createBox = t.getRect(create);
    expect(joinBox.height, closeTo(createBox.height, 0.5));
    expect(joinBox.center.dy, closeTo(createBox.center.dy, 0.5));
    // the two "+" icons are aligned too
    final icons = t.widgetList<Icon>(find.byIcon(Icons.add_circle)).length;
    expect(icons, 2);
    expect(t.getRect(find.byIcon(Icons.add_circle).first).center.dy,
        closeTo(t.getRect(find.byIcon(Icons.add_circle).last).center.dy, 0.5));
  });
}
