// The public "Rejoindre" dialog (same widget from Explorer and Choisir une ligue) lists the teams already in the league (team
// name + logo), keeps the Join button on screen with 10 teams, and never shows
// anything but the team name.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/private_league_model.dart';
import 'package:mon5majeur_app/presentation/screens/home/controllers/create_league_controller.dart';
import 'package:mon5majeur_app/presentation/screens/home/screens/choose_a_league_screen.dart';
import 'package:mon5majeur_app/presentation/screens/home/screens/explore_leagues_screen.dart';

class _FakeController extends CreateLeagueController {
  _FakeController() : super(isPublic: true);
  @override
  Future<void> getActivePublicLeagues(BuildContext context) async {}
}

PrivateLeagueModel _league(int n) => PrivateLeagueModel(
  id: 1,
  teams: [
    for (var i = 1; i <= n; i++)
      TeamInfo(teamId: i, teamName: 'Team $i', teamLogo: 'paris_fc'),
  ],
  leagueName: 'Ligue test',
  leagueDescription: '',
  leagueLogo: 'league_lion',
  teamBudget: '100M',
  maxTeamNumber: '10',
);

void main() {
  final screens = <String, Widget Function()>{
    'explore': () => const ExploreLeaguesScreen(),
    'choose': () => const ChooseALeagueScreen(),
  };
  for (final screen in screens.entries)
  for (final lang in const [Locale('fr', 'FR'), Locale('en', 'US')]) {
    testWidgets('joined teams list, 10 teams (${screen.key}, ${lang.languageCode})', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = _FakeController();
      c.activePublicLeagues.value = [_league(10)];
      Get.put<CreateLeagueController>(c, tag: 'public');
      addTearDown(Get.reset);
      await t.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => GetMaterialApp(
            translations: Language(),
            locale: lang,
            home: screen.value(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Ligue test'));
      await t.pumpAndSettle();

      expect(find.text(AppString.joinedTeamsTitle.tr), findsOneWidget);
      expect(
        AppString.joinedTeamsTitle.tr,
        lang.languageCode == 'fr' ? 'Équipes inscrites' : 'Joined teams',
      );
      expect(find.text('Team 1'), findsOneWidget);
      // Join button stays fully on screen.
      final join = t.getRect(find.byType(ElevatedButton).last);
      expect(join.bottom, lessThanOrEqualTo(844));
      expect(join.top, greaterThan(0));
    });
  }
}
