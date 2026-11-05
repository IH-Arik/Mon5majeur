// "Reuse my Global League team" (Global -> a duel league's composition): the
// substitute is copied with the starters, with the same checks as by hand. One
// who does not pass is simply left empty; the copy is never stopped by him.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/core/utils/lineup_rules.dart';
import 'package:mon5majeur_app/data/models/player.dart';

Player p(String id, double price, {String? status}) =>
    Player(id: id, name: 'P$id', position: 'PG', team: 'LAL', price: price, status: status);

void main() {
  final starters = [for (var i = 1; i <= 5; i++) p('s$i', 20)];
  final sub = p('sub', 8);

  Player? copy({
    Player? candidate,
    List<Player?>? team,
    Player? sixth,
    List<Player>? pool,
    bool complete = true,
  }) => copiedSubstitute(
    candidate: candidate ?? sub,
    starters: team ?? starters,
    sixthMan: sixth,
    pool: pool ?? [...starters, sub],
    poolComplete: complete,
  );

  group('who is copied as the substitute', () {
    test('1. a valid substitute is copied', () {
      expect(copy()!.id, 'sub');
    });

    test('2. over 10M: left empty, and the price is the player list\'s, not the copy\'s', () {
      expect(copy(pool: [...starters, p('sub', 10.5)]), isNull);
      expect(copy(pool: [...starters, p('sub', 10)])!.id, 'sub'); // 10M exactly is fine
      // the copy said 8M, the database (the list) says 12M: the list wins
      expect(copy(candidate: p('sub', 8), pool: [...starters, p('sub', 12)]), isNull);
    });

    test('3. he is one of the starters of the lineup he lands in: left empty', () {
      expect(copy(team: [...starters.take(4), sub]), isNull);
    });

    test('4. he is the 6th Man of that league: left empty', () {
      expect(copy(sixth: sub), isNull);
      expect(copy(sixth: p('other', 6))!.id, 'sub'); // another 6th Man changes nothing
    });

    test('5. OUT, or not playing tonight: left empty', () {
      expect(copy(pool: [...starters, p('sub', 8, status: 'OUT')]), isNull);
      expect(copy(pool: [...starters]), isNull); // the list is complete and does not hold him
    });

    test('6. the list is not complete yet: he is copied, the server decides on save', () {
      expect(copy(pool: [...starters], complete: false)!.id, 'sub');
      expect(copy(pool: [...starters, p('sub', 11)], complete: false), isNull); // a known price still counts
    });

    test('7. no substitute in the copied team: nobody', () {
      expect(
        copiedSubstitute(candidate: null, starters: starters, sixthMan: null, pool: starters, poolComplete: true),
        isNull,
      );
    });
  });

  group('the screen', () {
    final src = File('lib/presentation/screens/home/tabs/build_your_team_tab.dart').readAsStringSync();
    String between(String from, String to) {
      final a = src.indexOf(from);
      return src.substring(a, src.indexOf(to, a));
    }

    test('reads the Global team\'s substitute with its starters', () {
      expect(between('Future<void> _fetchGlobalTeam', 'Future<void> _reuseGlobalTeam'), contains("['substitute_player']"));
    });

    test('the copy replaces the substitute whatever he was (none in the Global team = none here)', () {
      final copyFn = between('Future<void> _reuseGlobalTeam', 'Widget _buildReuseGlobalTeamButton');
      expect(copyFn, contains('substitutePlayer = copiedSubstitute('));
      expect(copyFn, contains('candidate: _globalSubstitute'));
      // the 6th Man and the bonuses of this league are not touched
      expect(copyFn, isNot(contains('sixthManPlayer =')));
      expect(copyFn, isNot(contains('activeBonus')));
    });

    test('a locked or just-sent lineup is never overwritten', () {
      final copyFn = between('Future<void> _reuseGlobalTeam', 'Widget _buildReuseGlobalTeamButton');
      final guard = copyFn.indexOf('isLineupLocked(lockInSeconds)');
      expect(guard, greaterThan(-1));
      expect(guard, lessThan(copyFn.indexOf('showDialog')));
    });
  });
}
