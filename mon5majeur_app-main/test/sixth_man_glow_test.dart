// Duel composition: the 6th Man is highlighted with a fixed blue halo that follows
// his jersey, once he is picked. Nobody else gets one, and no other screen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/data/models/player.dart';
import 'package:mon5majeur_app/presentation/screens/home/widgets/lineup_widgets.dart';

void main() {
  Future<void> show(WidgetTester t, {Player? player, Color? glow}) async {
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: LineupPlayerSlot(
            player: player,
            jersey: Assets.icons.jerseyDevil,
            label: '6e',
            onTap: () {},
            glow: glow,
          ),
        ),
      ),
    ));
  }

  final picked = Player(id: 'b', name: 'Cunningham', position: 'SG', team: 'DET', price: 8);

  testWidgets('a slot with a halo draws two blurred copies of the jersey', (t) async {
    await show(t, player: picked, glow: sixthManBlue);
    expect(find.byType(ImageFiltered), findsNWidgets(2));
    expect(find.byType(ColorFiltered), findsNWidgets(2));
  });

  testWidgets('a normal slot has no halo', (t) async {
    await show(t, player: picked);
    expect(find.byType(ImageFiltered), findsNothing);
    await show(t);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  test('the blue is the 6th Man icon\'s', () {
    expect(sixthManBlue, const Color(0xFF2C46F4));
  });

  test('only the duel composition\'s 6th Man slot is given a halo, and only once picked', () {
    final users = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            !f.path.endsWith('lineup_widgets.dart') &&
            f.readAsStringSync().contains('glow:'))
          f.path,
    ];
    expect(users, ['lib/presentation/screens/home/tabs/build_your_team_tab.dart']);
    final src = File(users.single).readAsStringSync();
    expect(src, contains('glow: sixthManPlayer == null ? null : sixthManBlue'));
  });
}
