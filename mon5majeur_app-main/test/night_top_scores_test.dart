import 'package:flutter_test/flutter_test.dart';

import 'package:mon5majeur_app/data/services/night_top_scores.dart';

Map<String, dynamic> _player(String id, int score) =>
    {'id': id, 'name': id, 'position': 'PG', 'team': 'X', 'score': score};

void main() {
  late List<String> asked;

  setUp(() {
    NightTopScores.reset();
    asked = [];
  });
  tearDown(NightTopScores.reset);

  void answer(Map<String, dynamic>? Function(String night) body, {int status = 200}) {
    NightTopScores.request = (night) async {
      asked.add(night);
      return (status, body(night));
    };
  }

  test('ranks the night asked for, any night', () async {
    answer((n) => {
          'nba_date': n,
          'results': [_player('a', 50), _player('b', 40), _player('c', 30), _player('d', 20)],
        });
    expect(await NightTopScores.forDate('2026-10-31'), {'a': 1, 'b': 2, 'c': 3});
    expect(await NightTopScores.forDate('2026-11-02T00:00:00'), {'a': 1, 'b': 2, 'c': 3});
    expect(asked, ['2026-10-31', '2026-11-02']);
  });

  test('an answer for another night, or with no night, gives no medal', () async {
    // An old server: ignores nba_date, answers for the last night, no field.
    answer((n) => {'results': [_player('a', 50)]});
    expect(await NightTopScores.forDate('2026-10-31'), isEmpty);

    NightTopScores.reset();
    answer((n) => {'nba_date': '2026-11-02', 'results': [_player('a', 50)]});
    expect(await NightTopScores.forDate('2026-10-31'), isEmpty);
  });

  test('a night not published yet (empty list) is asked again later', () async {
    answer((n) => {'nba_date': n, 'results': []});
    expect(await NightTopScores.forDate('2026-11-02'), isEmpty);
    expect(await NightTopScores.forDate('2026-11-02'), isEmpty);
    expect(asked.length, 2);
  });

  test('a ranked night is kept: asked once', () async {
    answer((n) => {'nba_date': n, 'results': [_player('a', 50)]});
    await NightTopScores.forDate('2026-11-02');
    await NightTopScores.forDate('2026-11-02');
    expect(asked, ['2026-11-02']);
  });

  test('two calls at once share one request', () async {
    answer((n) => {'nba_date': n, 'results': [_player('a', 50)]});
    await Future.wait([
      NightTopScores.forDate('2026-11-02'),
      NightTopScores.forDate('2026-11-02'),
    ]);
    expect(asked.length, 1);
  });

  test('errors and unusable dates give no medal', () async {
    answer((n) => null, status: 500);
    expect(await NightTopScores.forDate('2026-11-02'), isEmpty);
    expect(await NightTopScores.forDate(null), isEmpty);
    expect(await NightTopScores.forDate('2026'), isEmpty);
  });
}
