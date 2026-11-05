// Duel leagues (private and public), composition: the substitute on the left edge
// of the half-way line (always there), the 6th Man on the right edge (while that
// bonus is on). Fixed places, the top of each jersey on the line, nothing touching.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/core/utils/lineup_request.dart';
import 'package:mon5majeur_app/data/models/player.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/lineup_widgets.dart';

Player p(String id, String name, double price, {String pos = 'PG'}) =>
    Player(id: id, name: name, position: pos, team: 'LAL', price: price);

// Where the visible jersey is inside the 114 x 91 picture (measured on the asset).
Rect jerseyArt(Rect box) => Rect.fromLTRB(
      box.left + box.width * 0.30, box.top + box.height * 0.12,
      box.left + box.width * 0.68, box.top + box.height * 0.93,
    );

void main() {
  group('the request body of a duel lineup', () {
    final five = [for (var i = 0; i < 5; i++) p('s$i', 'S$i', 20)];
    final sub = p('sub', 'Sub', 7);
    final sixth = p('six', 'Sixth', 6);

    Map<String, dynamic> body({Player? substitute, bool sixthOn = false, List<Player?>? starters}) =>
        duelLineupRequestBody(
          starters: starters ?? five, luxuryTax: false, chefCurry: false,
          sixthManActive: sixthOn, sixthMan: sixth, substitute: substitute,
        );

    test('with a substitute: he is sent', () {
      expect(body(substitute: sub)['substitute_player']['id'], 'sub');
    });

    test('without one: an explicit null, so a removed substitute is removed on the server', () {
      final b = body();
      expect(b.containsKey('substitute_player'), isTrue);
      expect(b['substitute_player'], isNull);
    });

    test('the 6th Man and the substitute are independent', () {
      final b = body(substitute: sub, sixthOn: true);
      expect(b['sixth_man_player']['id'], 'six');
      expect(b['substitute_player']['id'], 'sub');
      final c = body(substitute: sub);
      expect(c['sixth_man_player'], isNull);        // the 6th Man only counts while his bonus is on
      expect(c['substitute_player']['id'], 'sub');
    });

    test('the rest of the body is what it was', () {
      final b = body();
      expect(b.keys.toSet(), {'selected_players', 'luxury_tax', 'chef_curry', 'sixth_man_player', 'substitute_player'});
      expect((b['selected_players'] as List).length, 5);
    });

    test('an empty starter slot is left out, as before', () {
      expect((body(starters: [...five.take(4), null])['selected_players'] as List).length, 4);
    });
  });

  group('the court', () {
    final screens = {
      'iPhone 16 Pro': const Size(393, 852),
      'iPhone SE': const Size(375, 667),
      'iPhone 5s': const Size(320, 568),
    };
    // (substitute chosen, 6th Man on)
    final states = {
      'no substitute, no 6th Man': (false, false),
      'substitute only': (true, false),
      'substitute and 6th Man': (true, true),
      '6th Man only': (false, true),
    };
    const names = ['Gilgeous', 'Antetok', 'Towns', 'Edwards', 'Doncic'];

    Future<Map<String, Rect>> show(WidgetTester t, Size size, {required bool sub, required bool sixth}) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) prev?.call(d);   // the existing jersey button
      };
      addTearDown(() => FlutterError.onError = prev);
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
                    child: LineupPlayerSlot(player: p('s$i', names[i], 32), jersey: Assets.icons.jerseyDevil, label: label, onTap: () {}),
                  ),
                  changeJerseyButton: LineupChangeJerseyButton(jersey: Assets.icons.jerseyDevil, onTap: () {}),
                  inside: [
                    LineupHalfwayRow(
                      substitute: KeyedSubtree(
                        key: const ValueKey('sub'),
                        child: LineupSubstituteSlot(player: sub ? p('a', 'Williams', 10) : null, jersey: Assets.icons.jerseyDevil, onTap: () {}, fitName: true),
                      ),
                      sixthMan: sixth
                          ? KeyedSubtree(
                              key: const ValueKey('sixth'),
                              child: LineupPlayerSlot(player: p('b', 'Cunningham', 8), jersey: Assets.icons.jerseyDevil, label: '6e', onTap: () {}, fitName: true),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      Rect picture(Finder slot) => t.getRect(find.descendant(of: slot, matching: find.byType(Opacity)).first);
      Rect box(String key) => t.getRect(find.byKey(ValueKey(key)));
      return {
        // the drawn court: LineupCourt keeps a 16 margin on each side
        'court': t.getRect(find.byType(LineupCourt)).deflate(0).let16(ScreenUtil().setWidth(16)),
        'sub': box('sub'),
        'subPicture': picture(find.byKey(const ValueKey('sub'))),
        if (sixth) 'sixth': box('sixth'),
        if (sixth) 'sixthPicture': picture(find.byKey(const ValueKey('sixth'))),
      };
    }

    for (final screen in screens.entries) {
      for (final st in states.entries) {
        testWidgets('${screen.key} - ${st.key}', (t) async {
          final r = await show(t, screen.value, sub: st.value.$1, sixth: st.value.$2);
          final court = r['court']!;
          // the substitute is on the court's left edge, the 6th Man on its right edge
          expect(r['sub']!.left, closeTo(court.left, 1.5));
          if (st.value.$2) expect(r['sixth']!.right, closeTo(court.right, 1.5));
          // inside the court, and not cut off at the bottom
          for (final k in ['sub', 'sixth']) {
            final b = r[k];
            if (b == null) continue;
            expect(b.bottom, lessThanOrEqualTo(court.bottom + 0.5), reason: '$k is cut off');
            expect(b.left, greaterThanOrEqualTo(court.left - 0.5));
            expect(b.right, lessThanOrEqualTo(court.right + 0.5));
          }
          // both jerseys start on the same line
          if (st.value.$2) {
            expect(r['sixthPicture']!.top, closeTo(r['subPicture']!.top, 0.5));
          }
          // that line is the half-way line: 487.5 of the 600 (the court is longer by lineupBelowLine)
          final line = court.top + 487.5 * (court.height - lineupBelowLine_(t)) / 600;
          expect(jerseyArt(r['subPicture']!).top, closeTo(line, 1.5));
          // nothing of the starters touches the substitute or the 6th Man
          final mine = [
            jerseyArt(r['subPicture']!),
            if (st.value.$2) jerseyArt(r['sixthPicture']!),
            ...[for (final k in ['sub', 'sixth']) if (r[k] != null) ...[
              for (final e in find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(Text)).evaluate())
                t.getRect(find.byWidget(e.widget)),
            ]],
          ];
          for (var i = 0; i < 5; i++) {
            for (final e in find.descendant(of: find.byKey(ValueKey('starter-$i')), matching: find.byType(Text)).evaluate()) {
              final g = t.getRect(find.byWidget(e.widget));
              for (final m in mine) {
                expect(g.overlaps(m), isFalse, reason: 'starter $i text $g touches $m');
              }
            }
            final art = jerseyArt(t.getRect(find.descendant(of: find.byKey(ValueKey('starter-$i')), matching: find.byType(Opacity)).first));
            for (final m in mine) {
              expect(art.overlaps(m), isFalse, reason: 'starter $i jersey touches $m');
            }
          }
        });
      }
    }

    testWidgets('fixed places: nobody moves when the other appears', (t) async {
      final a = await show(t, screens['iPhone 16 Pro']!, sub: true, sixth: false);
      final b = await show(t, screens['iPhone 16 Pro']!, sub: true, sixth: true);
      expect(b['sub']!.topLeft, a['sub']!.topLeft);
      final c = await show(t, screens['iPhone 16 Pro']!, sub: false, sixth: true);
      final d = await show(t, screens['iPhone 16 Pro']!, sub: true, sixth: true);
      expect(d['sixth']!.topRight, c['sixth']!.topRight);
      // an empty substitute slot and a filled one start at the same height
      expect(c['sub']!.top, d['sub']!.top);
    });

    testWidgets('a long name is shrunk, the slot does not grow past the edge', (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => GetMaterialApp(
          translations: Language(),
          home: Scaffold(
            body: Builder(
              builder: (_) => Align(
                alignment: Alignment.topLeft,
                child: LineupSubstituteSlot(
                  key: const ValueKey('long'),
                  player: p('a', 'Cunningham-Longname-Of-A-Player', 10),
                  jersey: Assets.icons.jerseyDevil, onTap: () {}, fitName: true,
                ),
              ),
            ),
          ),
        ),
      ));
      await t.pump();
      expect(t.getSize(find.byKey(const ValueKey('long'))).width, closeTo(114.w_(t), 0.5));
    });
  });

  group('the duel composition screen is wired to it', () {
    final src = File('lib/presentation/screens/home/tabs/build_your_team_tab.dart').readAsStringSync();

    test('court: longer, the row on the half-way line, no more 720 court', () {
      expect(src, contains('belowLine: lineupBelowLine'));
      expect(src, contains('LineupHalfwayRow('));
      expect(src, isNot(contains('720.h')));
      expect(src, contains('substitute: LineupSubstituteSlot('));
      expect(src, contains('sixthMan: sixthManActivated ? _buildSixthManSlot(fitName: true) : null'));
    });

    test('saved with the lineup, restored when the screen opens', () {
      expect(src, contains('substitute: substitutePlayer,'));
      expect(src, contains("data['substitute_player']"));
      expect(src, contains('Player.fromJson(savedSubstitute)'));
    });

    test('the picker: 10M or less, never a starter or the 6th Man, with the remove button', () {
      expect(src, contains('maxPrice: substituteMaxPrice'));
      expect(src, contains('if (sixthManPlayer?.id != null) excluded.add(sixthManPlayer!.id!);'));
      expect(src, contains('onRemove: substitutePlayer == null ? null : _removeSubstitute'));
    });

    test('the 6th Man picker never offers the substitute; a starter pick clears him', () {
      expect(src, contains('if (substitutePlayer?.id != null) selectedIds.add(substitutePlayer!.id!);'));
      expect(src, contains('substitutePlayer!.id == p.id'));
    });

    test('a new day starts without a substitute', () {
      expect(src, contains('sixthManPlayer = null;\n        substitutePlayer = null;'));
    });
  });
}

// ScreenUtil's scale in the running test.
double lineupBelowLine_(WidgetTester t) => t.widget<LineupCourt>(find.byType(LineupCourt)).belowLine;

extension on Rect {
  Rect let16(double m) => Rect.fromLTRB(left + m, top, right - m, bottom);
}

extension on num {
  double w_(WidgetTester t) => ScreenUtil().setWidth(this);
}
