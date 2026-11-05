// The three meanings of `substitute_player` in a lineup save request.
import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/core/utils/lineup_request.dart';
import 'package:mon5majeur_app/data/models/player.dart';

void main() {
  final sub = Player(id: 'abc', name: 'Sub', position: 'SG', team: 'BOS', price: 7);

  test('default: the field is left out, so the server keeps the substitute', () {
    expect(substituteRequestField(sub, send: false), isEmpty);
    expect(substituteRequestField(null, send: false), isEmpty);
    expect(substituteRequestField(null, send: false).containsKey('substitute_player'), isFalse);
  });

  test('a player: set or change the substitute', () {
    final field = substituteRequestField(sub, send: true);
    expect(field['substitute_player']['id'], 'abc');
    expect(field['substitute_player']['price'], '7.0M');
  });

  test('explicit null: remove the substitute', () {
    final field = substituteRequestField(null, send: true);
    expect(field.containsKey('substitute_player'), isTrue);
    expect(field['substitute_player'], isNull);
  });

  test('merged in a body, nothing else changes', () {
    final body = {
      'selected_players': [1],
      ...substituteRequestField(null, send: false),
    };
    expect(body.keys, ['selected_players']);
  });
}
