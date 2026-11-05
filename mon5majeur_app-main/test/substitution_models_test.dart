// The substitute fields of the Result, Live and Global League models. Every
// field is optional: an older server, and a lineup without a substitute, send none.
import 'package:flutter_test/flutter_test.dart';
import 'package:mon5majeur_app/controllers/global_league_controller.dart';
import 'package:mon5majeur_app/data/models/live_score_model.dart';
import 'package:mon5majeur_app/data/models/match_result_model.dart';
import 'package:mon5majeur_app/data/models/substitution_model.dart';

Map<String, dynamic> live(String slot, {bool absent = false, bool counted = true}) => {
      'player_id': 'p1',
      'full_name': 'Test Player',
      'slot': slot,
      'fantasy_score_live': 22.0,
      'is_counted': counted,
      if (absent) 'is_absent': true,
    };

void main() {
  group('SubstitutionState', () {
    test('entered, with the replaced starter', () {
      final s = SubstitutionState.fromJson({'status': 'entered', 'replaced_id': 'abc'})!;
      expect(s.isEntered, isTrue);
      expect(s.replacedId, 'abc');
    });

    test('pending and not_entered', () {
      expect(SubstitutionState.fromJson({'status': 'pending', 'replaced_id': null})!.isPending, isTrue);
      expect(SubstitutionState.fromJson({'status': 'not_entered'})!.isNotEntered, isTrue);
    });

    test('nothing to show -> null (no substitute, older server, junk)', () {
      expect(SubstitutionState.fromJson(null), isNull);
      expect(SubstitutionState.fromJson({'status': 'none'}), isNull);
      expect(SubstitutionState.fromJson({'status': ''}), isNull);
      expect(SubstitutionState.fromJson('entered'), isNull);
      expect(SubstitutionState.fromJson({}), isNull);
    });

    test('an empty replaced_id is not an id', () {
      expect(SubstitutionState.fromJson({'status': 'entered', 'replaced_id': ''})!.replacedId, isNull);
    });
  });

  group('Result page (duels and Global day view)', () {
    final starter = {'id': 'a', 'name': 'A', 'position': 'PG', 'score': 0.0, 'absent': true};

    test('a lineup with a substitute', () {
      final ps = PlayerScore.fromJson({
        'team_name': 'T',
        'total_points': 97.0,
        'selection': [starter],
        'substitute': {'id': 's', 'name': 'S', 'position': 'SG', 'score': 22.0},
        'substitution': {'status': 'entered', 'replaced_id': 'a'},
      });
      expect(ps.selection.single.absent, isTrue);
      expect(ps.substitute!.name, 'S');
      expect(ps.substitute!.score, 22);
      expect(ps.substitute!.isSixthMan, isFalse);
      expect(ps.substitution!.isEntered, isTrue);
      expect(ps.substitution!.replacedId, 'a');
    });

    test('an older server / a lineup without a substitute: all defaults', () {
      final ps = PlayerScore.fromJson({
        'team_name': 'T',
        'total_points': 115.0,
        'selection': [
          {'id': 'a', 'name': 'A', 'position': 'PG', 'score': 40.0}
        ],
      });
      expect(ps.selection.single.absent, isFalse);
      expect(ps.substitute, isNull);
      expect(ps.substitution, isNull);
    });

    test('an opponent before the first tip-off: substitute null', () {
      final ps = PlayerScore.fromJson({
        'team_name': 'T',
        'selection_hidden': true,
        'selection': [],
        'substitute': null,
        'substitution': null,
      });
      expect(ps.substitute, isNull);
      expect(ps.substitution, isNull);
    });
  });

  group('Live', () {
    test('player flags', () {
      expect(LivePlayerScore.fromJson(live('STARTER', absent: true, counted: false)).isAbsent, isTrue);
      expect(LivePlayerScore.fromJson(live('STARTER')).isAbsent, isFalse);
      expect(LivePlayerScore.fromJson(live('SUBSTITUTE')).isSubstitute, isTrue);
      expect(LivePlayerScore.fromJson(live('SIXTH_MAN')).isSubstitute, isFalse);
    });

    test('duel: a substitute on each side, and none from an older server', () {
      final base = {
        'match_id': 'm', 'league_id': 'l', 'league_name': 'L', 'nba_date': '2026-11-02',
        'home_user_id': 'h', 'away_user_id': 'a', 'home_score': 97.0, 'away_score': 75.0,
        'match_status': 'live', 'home_players': [live('STARTER')], 'away_players': [],
      };
      final withSub = LiveMatchScore.fromJson({
        ...base,
        'home_substitute': live('SUBSTITUTE'),
        'home_substitution': {'status': 'pending'},
        'away_substitute': null,
        'away_substitution': null,
      });
      expect(withSub.homeSubstitute!.isSubstitute, isTrue);
      expect(withSub.homeSubstitution!.isPending, isTrue);
      expect(withSub.awaySubstitute, isNull);
      expect(withSub.awaySubstitution, isNull);

      final older = LiveMatchScore.fromJson(base);
      expect(older.homeSubstitute, isNull);
      expect(older.homeSubstitution, isNull);
    });

    test('Global League live', () {
      final g = LiveGlobalScore.fromJson({
        'league_id': 'l', 'league_name': 'G', 'total_score': 97.0,
        'players': [live('STARTER', absent: true, counted: false)],
        'substitute': live('SUBSTITUTE'),
        'substitution': {'status': 'entered', 'replaced_id': 'p1'},
      });
      expect(g.players.single.isAbsent, isTrue);
      expect(g.substitute!.fantasyScoreLive, 22.0);
      expect(g.substitution!.isEntered, isTrue);
      expect(LiveGlobalScore.fromJson({'league_id': 'l'}).substitute, isNull);
    });
  });

  group('Global League selection', () {
    test('with a substitute', () {
      final sel = GlobalLeagueSelection.fromJson({
        'match_day': 3,
        'selected_players': [
          {'id': 'a', 'name': 'A', 'position': 'PG', 'team': 'LAL', 'price': '20M'}
        ],
        'substitute_player': {'id': 's', 'name': 'S', 'position': 'SG', 'team': 'BOS', 'price': '7M'},
        'substitution': {'status': 'not_entered'},
      });
      expect(sel.substitutePlayer!.id, 's');
      expect(sel.substitutePlayer!.price, 7.0);
      expect(sel.substitution!.isNotEntered, isTrue);
      expect(sel.toJson()['substitute_player']['id'], 's');
    });

    test('without one (older server): nothing, and no key in toJson', () {
      final sel = GlobalLeagueSelection.fromJson({'match_day': 3, 'selected_players': []});
      expect(sel.substitutePlayer, isNull);
      expect(sel.substitution, isNull);
      expect(sel.toJson().containsKey('substitute_player'), isFalse);
    });
  });
}
