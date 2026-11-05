// Team builder, bonus menu: an "i" next to each bonus says in one sentence what it
// does (French and English). It opens a dialog and never picks the bonus.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/bonus_option_row.dart';

void main() {
  final keys = {
    'sixth': AppString.bonusInfoSixthMan,
    'chef': AppString.bonusInfoChefCurry,
    'luxury': AppString.bonusInfoLuxuryTax,
  };

  Future<int> pump(WidgetTester t, Locale locale, {String key = AppString.bonusInfoChefCurry}) async {
    var picked = 0;
    t.view.physicalSize = const Size(375, 667);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => GetMaterialApp(
        translations: Language(),
        locale: locale,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: BonusOptionRow(
              icon: Assets.icons.chefcurry, label: 'Chef Curry', count: 6, isActivated: false,
              onTap: () => picked++, info: key,
            ),
          ),
        ),
      ),
    ));
    await t.pump();
    return picked;
  }

  testWidgets('the "i" opens the sentence (fr) and does not pick the bonus', (t) async {
    var picked = 0;
    t.view.physicalSize = const Size(375, 667);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => GetMaterialApp(
        translations: Language(), locale: const Locale('fr', 'FR'),
        home: Scaffold(body: Align(alignment: Alignment.topRight, child: BonusOptionRow(
          icon: Assets.icons.chefcurry, label: 'Chef Curry', count: 6, isActivated: false,
          onTap: () => picked++, info: AppString.bonusInfoChefCurry,
        ))),
      ),
    ));
    await t.tap(find.byKey(const ValueKey('bonus-info-${AppString.bonusInfoChefCurry}')));
    await t.pumpAndSettle();
    expect(find.text('Ajoute 3 points à ton score final.'), findsOneWidget);
    expect(picked, 0);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await t.tap(find.text('Chef Curry'));                       // the row itself still picks it
    expect(picked, 1);
  });

  testWidgets('and in English', (t) async {
    await pump(t, const Locale('en', 'US'));
    await t.tap(find.byKey(const ValueKey('bonus-info-${AppString.bonusInfoChefCurry}')));
    await t.pumpAndSettle();
    expect(find.text('Adds 3 points to your final score.'), findsOneWidget);
  });

  testWidgets('the picture stands on its own, big, with no circle around it', (t) async {
    await pump(t, const Locale('fr', 'FR'));
    final icon = t.getSize(find.byKey(const ValueKey('bonus-icon')));
    expect(icon.width, greaterThan(30));
    expect(icon.height, greaterThan(30));
    // nothing round is drawn in the row any more
    final round = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(ScreenUtil().radius(19)));
    expect(round, findsNothing);
  });

  testWidgets('the bonus that is on has an orange name, the others a grey one', (t) async {
    Future<Color?> pill(bool on) async {
      t.view.physicalSize = const Size(375, 667);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(
          translations: Language(), locale: const Locale('fr', 'FR'),
          home: Scaffold(body: BonusOptionRow(
            icon: Assets.icons.chefcurry, label: 'Chef Curry', count: 6, isActivated: on,
            onTap: () {}, info: AppString.bonusInfoChefCurry,
          )),
        ),
      ));
      final box = t.widget<Container>(find.ancestor(of: find.text('Chef Curry'), matching: find.byType(Container)).first);
      return (box.decoration as BoxDecoration).color;
    }
    expect(await pill(true), const Color(0xFFFF8C42));
    expect(await pill(false), const Color(0xFF777777));
  });

  test('each bonus has one sentence in French and in English, never the raw key', () {
    for (final entry in keys.entries) {
      for (final lang in ['fr', 'en']) {
        final text = Language().keys[lang == 'fr' ? 'fr_FR' : 'en_US']![entry.value]!;
        expect(text, isNot(entry.value), reason: '${entry.key} $lang');
        expect(text.endsWith('.'), isTrue);
        expect(text.contains('\n'), isFalse);
        expect('.'.allMatches(text.substring(0, text.length - 1)).length, 0, reason: 'one sentence');
      }
      expect(Language().keys['fr_FR']![entry.value], isNot(Language().keys['en_US']![entry.value]));
    }
  });

  test('the three bonuses of the menu all have their "i"', () {
    final src = File('lib/presentation/screens/home/tabs/build_your_team_tab.dart').readAsStringSync();
    for (final k in ['bonusInfoSixthMan', 'bonusInfoChefCurry', 'bonusInfoLuxuryTax']) {
      expect(src, contains('info: AppString.$k'));
    }
  });
}
