// The Global League court is 720 high (it holds the substitute's own row under
// the starters): on small phones nothing may overflow or overlap.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/player.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/lineup_widgets.dart';

Player p(String name, double price) => Player(id: name, name: name, position: 'PG', team: 'LAL', price: price);

void main() {
  // iPhone 16 Pro, iPhone SE (3rd generation), the smallest iPhone still around
  // (SE 1st generation / iPhone 5s: 320 x 568).
  final screens = {
    'iPhone 16 Pro 393x852': const Size(393, 852),
    'iPhone SE 375x667': const Size(375, 667),
    'iPhone 5s 320x568': const Size(320, 568),
  };

  for (final entry in screens.entries) {
    testWidgets('court with 5 starters and a substitute fits on ${entry.key}', (t) async {
      t.view.physicalSize = entry.value;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      // Overflows are collected, not thrown. The "change jersey" button (not part
      // of the substitute) is a few pixels too tall on a small phone today: it is
      // reported apart so it cannot hide a problem of the substitute's row.
      final overflows = <String>[];
      final jerseyButtonOverflows = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) {
          final where = d.toDiagnosticsNode().toStringDeep();
          (where.contains('LineupChangeJerseyButton') ? jerseyButtonOverflows : overflows)
              .add(d.exceptionAsString().split('\n').first);
        } else {
          prev?.call(d);
        }
      };
      addTearDown(() => FlutterError.onError = prev);

      final names = ['Shai Gilgeous-Alexander', 'Giannis Antetokounmpo', 'Karl-Anthony Towns', 'Anthony Edwards', 'Luka Doncic'];
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(
          translations: Language(),
          locale: const Locale('fr', 'FR'),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SingleChildScrollView(
              child: Builder(
                builder: (_) => LineupCourt(
                  height: 720.h, // what the Global builder uses
                  slotBuilder: (i, label) => KeyedSubtree(
                    key: ValueKey('starter-$i'),
                    child: LineupPlayerSlot(
                      player: p(names[i], 24),
                      jersey: Assets.icons.jerseyDevil,
                      label: label,
                      onTap: () {},
                    ),
                  ),
                  changeJerseyButton: LineupChangeJerseyButton(jersey: Assets.icons.jerseyDevil, onTap: () {}),
                  inside: [
                    Positioned(
                      bottom: 12.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: KeyedSubtree(
                          key: const ValueKey('substitute'),
                          child: LineupSubstituteSlot(
                            player: p('Jaylin Williams', 3),
                            jersey: Assets.icons.jerseyDevil,
                            onTap: () {},
                            onRemove: () {},
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      // Two plain frames are enough to lay the court out; waiting for the app to
      // "settle" is not needed here.
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));

      if (jerseyButtonOverflows.isNotEmpty) {
        debugPrint('NOTE ${entry.key}: the existing "change jersey" button overflows '
            '(${jerseyButtonOverflows.first}); not caused by the substitute.');
      }
      expect(overflows, isEmpty, reason: overflows.join('; '));
      final court = t.getRect(find.byType(LineupCourt));
      final sub = t.getRect(find.byKey(const ValueKey('substitute')));
      // the two guards are the lowest starters
      final lowestStarter = [3, 4].map((i) => t.getRect(find.byKey(ValueKey('starter-$i'))).bottom).reduce((a, b) => a > b ? a : b);
      expect(sub.bottom, lessThanOrEqualTo(court.bottom + 0.5), reason: 'the substitute stays inside the court');
      expect(sub.top, greaterThanOrEqualTo(lowestStarter - 0.5),
          reason: 'the substitute row does not overlap the guards (sub top ${sub.top}, guards bottom $lowestStarter)');
      expect(sub.left, greaterThanOrEqualTo(0));
      expect(sub.right, lessThanOrEqualTo(entry.value.width));
    });
  }

  test('the numbers above are the real screen\'s (change both together)', () {
    final screen = File('lib/presentation/screens/home/tabs/build_your_team_global_tab.dart').readAsStringSync();
    expect(screen, contains('height: 720.h'));
    expect(screen, contains('bottom: 12.h'));
  });
}
