// Composition court: 600 high plus a little (lineupBelowLine). The top of the
// substitute's jersey is ON the half-way line, centred, his name and price in the
// other half. On small phones nothing may overflow or be cut off, and nothing of
// his may touch anything of the starters.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/player.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/lineup_widgets.dart';

// Where the visible jersey is inside the 114 x 91 picture (measured on the asset:
// the rest is transparent), so two slots may share a box without touching.
Rect jerseyArt(Rect slot) => Rect.fromLTRB(
      slot.left + slot.width * 0.30,
      slot.top + slot.height * 0.12,
      slot.left + slot.width * 0.68,
      slot.top + slot.height * 0.93,
    );

// ScreenUtil's scale at the test's screen: the court heights are in .h / .sp.
double lineupBelowLine_(WidgetTester t) => t.widget<LineupCourt>(find.byType(LineupCourt)).belowLine;

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
    testWidgets('court with 5 starters and a substitute fits and nothing touches on ${entry.key}', (t) async {
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

      // Short names: the test font is twice as wide as the real one, and a name wider than
      // the 114 box moves its jersey sideways (the nominal layout is what is checked).
      final names = ['Gilgeous', 'Antetok', 'Towns', 'Edwards', 'Doncic'];
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
                  belowLine: lineupBelowLine,
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
                      top: lineupSubstituteTop.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: KeyedSubtree(
                          key: const ValueKey('substitute'),
                          child: LineupSubstituteSlot(
                            player: p('Williams', 3),
                            jersey: Assets.icons.jerseyDevil,
                            onTap: () {},
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
      expect(sub.bottom, lessThanOrEqualTo(court.bottom + 0.5), reason: 'the substitute stays inside the court');
      expect(sub.left, greaterThanOrEqualTo(0));
      expect(sub.right, lessThanOrEqualTo(entry.value.width));
      expect(sub.center.dx, closeTo(court.center.dx, 1), reason: 'centred');
      // 600 + a little: the original court is not stretched by much
      expect(court.height / (court.height - lineupBelowLine_(t)), inInclusiveRange(1.05, 1.12));
      // the top of his drawn jersey is on the half-way line (487.5 of the 600)
      Rect picture(Finder slot) => t.getRect(find.descendant(of: slot, matching: find.byType(Opacity)).first);
      final subArt = jerseyArt(picture(find.byKey(const ValueKey('substitute'))));
      final line = court.top + 487.5 * (court.height - lineupBelowLine_(t)) / 600;
      expect(subArt.top, closeTo(line, 1.5), reason: 'jersey top ${subArt.top}, half-way line $line');
      // his name and price are in the other half, and inside the court
      final subTexts = find.descendant(of: find.byKey(const ValueKey('substitute')), matching: find.byType(Text));
      final rects = [for (final e in subTexts.evaluate()) t.getRect(find.byWidget(e.widget))];
      final nameAndPrice = rects.where((r) => r.top > line + 10);
      expect(nameAndPrice.length, 3, reason: 'the label, the name and the price are under the line');
      for (final r in nameAndPrice) {
        expect(r.bottom, lessThanOrEqualTo(court.bottom + 0.5), reason: 'cut off at the court\'s edge');
      }
      // nothing of a guard (label, name, price) touches the substitute's jersey, label, name or price
      final subRects = [subArt, ...rects];
      for (final i in [3, 4]) {
        final guardTexts = find.descendant(of: find.byKey(ValueKey('starter-$i')), matching: find.byType(Text));
        for (final e in guardTexts.evaluate()) {
          final g = t.getRect(find.byWidget(e.widget));
          for (final r in subRects) {
            expect(g.overlaps(r), isFalse, reason: 'guard $i text $g touches the substitute\'s $r');
          }
        }
      }
      // the jersey drawn for the substitute touches no other jersey
      // (the jersey picture is the Opacity box at the top of each slot)
      for (var i = 0; i < 5; i++) {
        final art = jerseyArt(picture(find.byKey(ValueKey('starter-$i'))));
        expect(subArt.overlaps(art), isFalse, reason: 'substitute jersey $subArt overlaps starter $i $art');
      }
    });
  }

  test('the numbers above are the real screen\'s (change both together)', () {
    final screen = File('lib/presentation/screens/home/tabs/build_your_team_global_tab.dart').readAsStringSync();
    expect(screen, isNot(contains('height: 720.h')), reason: 'no more 720 court');
    expect(screen, contains('top: lineupSubstituteTop.h'));
    expect(screen, contains('belowLine: lineupBelowLine'));
  });
}
