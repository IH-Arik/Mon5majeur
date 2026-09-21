// The private league and the Global League share these lineup widgets
// (QA 15/09/2026: same components everywhere) — check they render the same
// way in both, never clip the position pill, and show full player names.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/language/language_controller.dart';
import 'package:mon5majeur_app/data/models/player.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/lineup_widgets.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => GetMaterialApp(
    translations: Language(),
    locale: const Locale('fr', 'FR'),
    home: Scaffold(backgroundColor: Colors.black, body: SingleChildScrollView(child: child)),
  ),
);

Player _p(String name) => Player(name: name, position: 'PG', team: 'LAL', price: 8);

void main() {
  testWidgets('court shows 5 slots with FULL positions, no clipping', (t) async {
    t.view.physicalSize = const Size(400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var tapped = -1;
    await t.pumpWidget(_host(LineupCourt(
      slotBuilder: (i, label) => LineupPlayerSlot(
        player: i == 1 ? _p('Giannis Antetokounmpo') : null,
        jersey: Assets.icons.jerseyDevil,
        label: label,
        onTap: () => tapped = i,
      ),
      changeJerseyButton: LineupChangeJerseyButton(jersey: Assets.icons.jerseyDevil, onTap: () {}),
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(LineupPlayerSlot), findsNWidgets(5));
    // full labels (SF/PF x2, C, PG/SG x2) — never "PG/" or a lone "SF"
    expect(find.text('SF/PF'), findsNWidgets(2));
    expect(find.text('PG/SG'), findsNWidgets(2));
    expect(find.text('C'), findsOneWidget);
    // a picked player shows the full name and price; empty slots show "+"
    expect(find.text('Giannis Antetokounmpo'), findsOneWidget);
    expect(find.text('8M'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNWidgets(4));
    expect(find.text('Changer de\nmaillot'), findsOneWidget);
    await t.tap(find.byType(LineupPlayerSlot).at(3));
    expect(tapped, 3);
  });

  testWidgets('position pill is fully inside the slot area (not clipped)', (t) async {
    // Phone-shaped viewport: ScreenUtil scales .h by height and .sp by width,
    // so the default 800x600 test surface would distort the ratio.
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(Center(
      child: LineupPlayerSlot(
        player: null,
        jersey: Assets.icons.jerseyDevil,
        label: 'PG/SG',
        onTap: () {},
      ),
    )));
    await t.pumpAndSettle();
    final slot = t.getRect(find.byType(LineupPlayerSlot));
    final pill = t.getRect(find.text('PG/SG'));
    expect(pill.bottom, lessThanOrEqualTo(slot.bottom + 0.5));
  });
}
