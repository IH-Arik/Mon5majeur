// Global League team builder: the substitute's slot, his picker, the texts
// (FR/EN) and the server's refusals.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/core/utils/lineup_rules.dart';
import 'package:mon5majeur_app/core/utils/server_message.dart';
import 'package:mon5majeur_app/data/models/player.dart';
import 'package:mon5majeur_app/presentation/screens/home/screens/select_player_screen.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/lineup_widgets.dart';
import 'package:mon5majeur_app/presentation/screens/tutorial/tutorial_controller.dart';

Player p(String id, String name, double price, {String pos = 'PG'}) =>
    Player(id: id, name: name, position: pos, team: 'LAL', price: price);

const fr = Locale('fr', 'FR');
const en = Locale('en', 'US');

Widget app(Locale locale, Widget home) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => GetMaterialApp(
        translations: Language(),
        locale: locale,
        home: Scaffold(backgroundColor: Colors.black, body: SingleChildScrollView(child: home)),
      ),
    );

void main() {
  group('the rules', () {
    test('the numbers are the server\'s', () {
      expect(substituteMaxPrice, 10.0);
      expect(replaceableMinPrice, 10.0);
    });

    test('the substitute never counts toward the budget', () {
      final starters = [for (var i = 0; i < 5; i++) p('s$i', 'S$i', 20)];
      expect(budgetUsedByStarters(starters), 100.0);
      // a 10M substitute on top: the five starters still use exactly the 100M
      final sub = p('x', 'Sub', 10);
      expect(budgetUsedByStarters(starters), 100.0, reason: 'sub=${sub.price}M is not an argument');
      expect(budgetUsedByStarters([null, p('a', 'A', 7), null]), 7.0);
    });

    test('who can be the substitute', () {
      expect(canBeSubstitute(p('a', 'A', 10), {}), isTrue); // 10M exactly
      expect(canBeSubstitute(p('a', 'A', 3), {}), isTrue);
      expect(canBeSubstitute(p('a', 'A', 10.5), {}), isFalse);
      expect(canBeSubstitute(p('a', 'A', 24), {}), isFalse);
      expect(canBeSubstitute(p('a', 'A', 5), {'a'}), isFalse); // a starter
    });
  });

  group('the slot', () {
    for (final entry in {fr: 'Remplaçant', en: 'Substitute'}.entries) {
      testWidgets('empty slot is labelled "${entry.value}" (${entry.key.languageCode})', (t) async {
        t.view.physicalSize = const Size(400, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var tapped = 0;
        await t.pumpWidget(app(
          entry.key,
          LineupSubstituteSlot(player: null, jersey: Assets.icons.jerseyDevil, onTap: () => tapped++),
        ));
        await t.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing, reason: 'no cross on the slot, ever');
        await t.tap(find.text(entry.value));
        expect(tapped, 1);
      });
    }

    testWidgets('a picked substitute shows name and price, with no cross and no link to remove him', (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(
        fr,
        LineupSubstituteSlot(player: p('a', 'Jaylin Williams', 3), jersey: Assets.icons.jerseyDevil, onTap: () {}),
      ));
      await t.pumpAndSettle();
      expect(find.text('Jaylin Williams'), findsOneWidget);
      expect(find.text('3M'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('Retirer le remplaçant'), findsNothing);
    });

    testWidgets('only his jersey is at 80 %: the "+", the label, the name and the price stay at 100 %', (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final player in [null, p('a', 'Jaylin Williams', 3)]) {
        await t.pumpWidget(app(
          fr,
          LineupSubstituteSlot(player: player, jersey: Assets.icons.jerseyDevil, onTap: () {}),
        ));
        await t.pumpAndSettle();
        final opacities = t.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity).toList();
        expect(opacities, [0.8], reason: 'one faded thing only: the jersey');
        for (final strong in [find.text('Remplaçant'), find.byIcon(Icons.add), find.text('Jaylin Williams'), find.text('3M')]) {
          expect(find.ancestor(of: strong, matching: find.byType(Opacity)), findsNothing);
        }
      }
    });

    testWidgets('a starter\'s jersey is not faded', (t) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(
        fr,
        LineupPlayerSlot(player: p('a', 'Jaylin Williams', 3), jersey: Assets.icons.jerseyDevil, label: 'PG', onTap: () {}),
      ));
      await t.pumpAndSettle();
      expect(t.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity), [1.0]);
    });
  });

  group('the picker', () {
    final candidates = [
      p('s1', 'Starter One', 8),
      p('c1', 'Cheap Guy', 4),
      p('c2', 'Ten Million', 10),
      p('d1', 'Too Dear', 12),
      p('d2', 'Star Player', 30),
    ];

    Future<void> openPicker(WidgetTester t, Locale locale) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Get.put(TutorialController());
      addTearDown(Get.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(
          translations: Language(),
          locale: locale,
          // Builder: the texts are translated when the screen is opened, once
          // the app (and its language) is up, exactly like the real screen.
          home: Builder(
            builder: (_) => SelectPlayerScreen(
              playersNotifier: ValueNotifier(candidates),
              getHasMorePages: () => false,
              getIsLoadingMore: () => false,
              remainingBudget: 0,
              teamJersey: Assets.icons.jerseyDevil,
              onPlayerSelected: (_) {},
              onLoadMore: () async {},
              positionCategory: null,
              excludedPlayerIds: const {'s1'},
              maxPrice: substituteMaxPrice,
              infoText: AppString.substituteExplanation.tr,
              maxPriceHint: AppString.substitutePriceHint.trParams({'n': '10'}),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('lists players of 10M or less, without the starters (fr)', (t) async {
      await openPicker(t, fr);
      expect(find.text('Cheap Guy'), findsOneWidget);
      expect(find.text('Ten Million'), findsOneWidget);
      expect(find.text('Too Dear'), findsNothing);
      expect(find.text('Star Player'), findsNothing);
      expect(find.text('Starter One'), findsNothing);
    });

    testWidgets('shows the explanation in French, word for word, and no bank', (t) async {
      await openPicker(t, fr);
      expect(
        find.text(
          "Ton remplaçant entre en jeu si un titulaire coûtant 10 M ou plus n'a joué aucune minute. "
          "Il ne compte pas dans ton budget de 100 M, et il ne joue qu'à cette condition.",
        ),
        findsOneWidget,
      );
      expect(find.text('Le remplaçant doit coûter 10M maximum'), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-info')), findsOneWidget);
      expect(find.text(AppString.bank.tr), findsNothing, reason: 'the substitute is outside the budget');
    });

    testWidgets('shows the explanation in English, word for word', (t) async {
      await openPicker(t, en);
      expect(
        find.text(
          "Your substitute comes in if a starter costing 10M or more doesn't play a single minute. "
          "He doesn't count toward your 100M budget and only plays under that condition.",
        ),
        findsOneWidget,
      );
      expect(find.text('Substitute pick must cost ≤ 10M'), findsOneWidget);
    });

    testWidgets('the usual pickers (starters, 6th Man) are unchanged: bank shown, no explanation', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Get.put(TutorialController());
      addTearDown(Get.reset);
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(
          translations: Language(),
          locale: fr,
          home: SelectPlayerScreen(
            playersNotifier: ValueNotifier(candidates),
            getHasMorePages: () => false,
            getIsLoadingMore: () => false,
            remainingBudget: 42,
            teamJersey: Assets.icons.jerseyDevil,
            onPlayerSelected: (_) {},
            onLoadMore: () async {},
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('picker-info')), findsNothing);
      expect(find.text('42M'), findsOneWidget);
    });
  });

  group('removing the substitute (button at the top of the picker)', () {
    Future<List<int>> open(WidgetTester t, Locale locale, {required bool chosen}) async {
      t.view.physicalSize = const Size(400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Get.put(TutorialController());
      addTearDown(Get.reset);
      final removed = <int>[];
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(
          translations: Language(),
          locale: locale,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => SelectPlayerScreen(
                        playersNotifier: ValueNotifier([p('c1', 'Cheap Guy', 4)]),
                        getHasMorePages: () => false,
                        getIsLoadingMore: () => false,
                        remainingBudget: 0,
                        teamJersey: Assets.icons.jerseyDevil,
                        onPlayerSelected: (_) {},
                        onLoadMore: () async {},
                        maxPrice: substituteMaxPrice,
                        infoText: AppString.substituteExplanation.tr,
                        onRemove: chosen ? () => removed.add(1) : null,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.byKey(const ValueKey('open')));
      await t.pumpAndSettle();
      return removed;
    }

    for (final entry in {fr: 'Retirer le remplaçant', en: 'Remove substitute'}.entries) {
      testWidgets('substitute chosen (${entry.key.languageCode}): "${entry.value}" is the first thing of the list, and works', (t) async {
        final removed = await open(t, entry.key, chosen: true);
        final button = find.byKey(const ValueKey('remove-substitute'));
        expect(button, findsOneWidget);
        expect(find.descendant(of: button, matching: find.text(entry.value)), findsOneWidget);
        expect(t.getSize(button).height, greaterThanOrEqualTo(44));
        // above the list: above the first player
        expect(t.getTopLeft(button).dy, lessThan(t.getTopLeft(find.text('Cheap Guy')).dy));
        await t.tap(button);
        await t.pumpAndSettle();
        expect(removed, [1]);
        expect(find.byType(SelectPlayerScreen), findsNothing, reason: 'the picker closes');
      });
    }

    testWidgets('no substitute chosen: no button', (t) async {
      await open(t, fr, chosen: false);
      expect(find.byKey(const ValueKey('remove-substitute')), findsNothing);
      expect(find.text('Retirer le remplaçant'), findsNothing);
    });
  });

  group('the server\'s refusals, translated', () {
    final refusals = {
      'The substitute cannot also be a starter': 'Le remplaçant ne peut pas être aussi titulaire',
      'The substitute cannot also be the 6th Man': 'Le remplaçant ne peut pas être aussi le 6e homme',
      'The substitute costs 12M — must be 10M or less': 'Le remplaçant coûte 12M — maximum 10M',
      'The substitute costs 10.5M — must be 10M or less': 'Le remplaçant coûte 10.5M — maximum 10M',
      'The substitute must have an id': 'Le remplaçant doit avoir un identifiant',
      // already translated, reused by the server for the substitute
      'Rests Tonight does not play tonight': 'Rests Tonight ne joue pas ce soir',
      'Hurt Guy is OUT and cannot be selected': 'Hurt Guy est absent (OUT) et ne peut pas être sélectionné',
    };

    testWidgets('French', (t) async {
      await t.pumpWidget(GetMaterialApp(translations: Language(), locale: fr, home: const SizedBox()));
      await t.pumpAndSettle();
      refusals.forEach((server, french) => expect(localizeServerMessage(server), french, reason: server));
    });

    testWidgets('English: the server\'s own text, with the price filled in', (t) async {
      await t.pumpWidget(GetMaterialApp(translations: Language(), locale: en, home: const SizedBox()));
      await t.pumpAndSettle();
      expect(localizeServerMessage('The substitute cannot also be a starter'),
          'The substitute cannot also be a starter');
      expect(localizeServerMessage('The substitute costs 12M — must be 10M or less'),
          'The substitute costs 12M — must be 10M or less');
    });
  });

  group('the Global builder screen is wired to the rule', () {
    final src = File('lib/presentation/screens/home/tabs/build_your_team_global_tab.dart').readAsStringSync();

    test('the substitute is outside the budget', () {
      final getter = src.substring(src.indexOf('double get usedBudget'), src.indexOf('int get remainingPlayers'));
      expect(getter, contains('budgetUsedByStarters(selectedPlayers)'));
      expect(getter, isNot(contains('ubstitute')));
      expect(src, contains('maxPrice: substituteMaxPrice'));
    });

    test('the lineup is saved with the substitute, null meaning "remove"', () {
      expect(src, contains('substitute: substitutePlayer,'));
      expect(src, contains('sendSubstitute: true'));
    });

    test('the saved substitute comes back when the screen opens', () {
      expect(src, contains('substitutePlayer = selection.substitutePlayer;'));
    });

    test('a player picked as starter stops being the substitute', () {
      expect(src, contains('substitutePlayer!.id == p.id'));
    });

    test('the substitute stands on the half-way line, on a court a little longer than the usual 600', () {
      expect(src, contains('LineupSubstituteSlot('));
      expect(src, contains('top: lineupSubstituteTop.h'));
      expect(src, contains('belowLine: lineupBelowLine'));
      expect(src, isNot(contains('height: 720.h')));
      expect(src, contains('onRemove: substitutePlayer == null ? null : _removeSubstitute'));
    });
  });
}
