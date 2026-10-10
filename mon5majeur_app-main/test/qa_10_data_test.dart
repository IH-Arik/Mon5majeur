// QA #10 items 6/7: position groups and the one-active-sort rule of the Data screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/presentation/screens/data/data_screen.dart';

Player _p(String name, String pos, double price, int? avg) =>
    Player(name: name, position: pos, price: price, team: 'T', avg: avg);

void main() {
  test('position groups follow the validated mapping', () {
    for (final c in ['C', 'C-F', 'F-C']) {
      expect(inPositionGroup(1, c), isTrue, reason: c);
    }
    for (final f in ['SF', 'PF', 'F', 'G-F', 'F-G', 'F-C', 'C-F']) {
      expect(inPositionGroup(2, f), isTrue, reason: f);
    }
    for (final g in ['PG', 'SG', 'G', 'G-F', 'F-G']) {
      expect(inPositionGroup(3, g), isTrue, reason: g);
    }
    // a multi-position player appears in every matching group
    expect(inPositionGroup(2, 'G-F') && inPositionGroup(3, 'G-F'), isTrue);
    expect(inPositionGroup(1, 'F-C') && inPositionGroup(2, 'F-C'), isTrue);
    // "NA" only under All
    expect(inPositionGroup(0, 'NA'), isTrue);
    for (final g in [1, 2, 3]) {
      expect(inPositionGroup(g, 'NA'), isFalse);
    }
    expect(inPositionGroup(1, 'pg'), isFalse); // a guard is not a center
  });

  test('sorting: best first on the first tap, one active key', () {
    final list = [
      _p('a', 'C', 10, 20),
      _p('b', 'C', 37, 5),
      _p('c', 'PG', 3, null),
    ];
    expect(sortPlayers(list, 'avg', true).map((p) => p.name), ['a', 'b', 'c']);
    expect(sortPlayers(list, 'avg', false).map((p) => p.name), ['c', 'b', 'a']);
    expect(sortPlayers(list, 'price', true).map((p) => p.name), ['b', 'a', 'c']);
    expect(sortPlayers(list, null, true).map((p) => p.name), ['a', 'b', 'c']);
  });

  test('centers + price descending puts the most expensive center first', () {
    final list = [
      _p('cheap C', 'C', 5, 10),
      _p('Guard', 'PG', 40, 30),
      _p('star C-F', 'C-F', 38, 25),
    ];
    final centers = list.where((p) => inPositionGroup(1, p.position)).toList();
    expect(sortPlayers(centers, 'price', true).first.name, 'star C-F');
  });
}
