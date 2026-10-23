// The hot/cold badge sits on the jersey thumbnail's top-right corner, at the
// same spot for every player whatever the length of the name.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/player.dart';
import 'package:mon5majeur_app/presentation/screens/home/screens/select_player_screen.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/player_form_badge.dart';
import 'package:mon5majeur_app/presentation/screens/tutorial/tutorial_controller.dart';

Player _p(String name, String form) => Player(
  name: name,
  position: 'PF',
  team: 'MIN',
  price: 9,
  trigram: 'MIN',
  opponentTrigram: 'LAL',
  isHome: true,
  form: form,
  lastTwoScores: const [30, 41],
);

void main() {
  for (final lang in const [Locale('fr', 'FR'), Locale('en', 'US')]) {
    testWidgets('badge is pinned to the jersey corner (${lang.languageCode})', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // The last-scores chips overflow under the test font (Ahem is wider than
      // the real one); unrelated to the badge.
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      Get.put(TutorialController());
      addTearDown(Get.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => GetMaterialApp(
              translations: Language(),
              locale: lang,
              home: SelectPlayerScreen(
                playersNotifier: ValueNotifier([
                  _p('Karl-Anthony Towns', 'HOT'),
                  _p('Lauri Markkanen', 'COLD'),
                ]),
                getHasMorePages: () => false,
                getIsLoadingMore: () => false,
                remainingBudget: 100,
                teamJersey: Assets.icons.jerseyDevil,
                onPlayerSelected: (_) {},
                onLoadMore: () async {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      final hot = t.getRect(find.bySemanticsLabel(AppString.playerFormHot.tr));
      final cold = t.getRect(find.bySemanticsLabel(AppString.playerFormCold.tr));

      // 28px badge, same x in both rows, same offset from each row's top.
      expect(hot.width, closeTo(28, 0.5));
      expect(cold.width, closeTo(28, 0.5));
      expect(hot.left, closeTo(cold.left, 0.01));

      // Straddles the top-right corner of the 50x50 jersey thumbnail.
      final thumb = t.getRect(find.byType(ClipRRect).first);
      expect(hot.center.dx, closeTo(thumb.right - 5, 0.5));
      expect(hot.center.dy, closeTo(thumb.top + 5, 0.5));
      expect(hot.right, greaterThan(thumb.right));
      expect(hot.top, lessThan(thumb.top));

      // Rows differ in height (long vs short name), the badge offset doesn't.
      final rowTops = find.byType(ClipRRect);
      expect(t.getTopLeft(rowTops.at(1)).dy, isNot(t.getTopLeft(rowTops.first).dy));
      final thumb2 = t.getRect(find.byType(ClipRRect).at(1));
      expect(cold.center.dx - thumb2.right, closeTo(hot.center.dx - thumb.right, 0.01));
      expect(cold.center.dy - thumb2.top, closeTo(hot.center.dy - thumb.top, 0.01));
    });
  }
}
