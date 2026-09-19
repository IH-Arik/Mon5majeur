"""
"Does this player's team play tonight?" must not depend on which team-id
scheme a feed used (prod data: Lakers as both "LOS" and "LAL", Spurs as the
NBA.com numeric "1610612759", the rest as Goalserve 3-letter codes).
"""
from types import SimpleNamespace

from app.modules.players.teams_playing import TeamsPlaying


def _game(home_id, home_name, away_id, away_name):
    return SimpleNamespace(
        home_team_id=home_id, home_team_name=home_name,
        away_team_id=away_id, away_team_name=away_name,
    )


# Tonight: Lakers (schedule feed says "LAL") host the Spurs (numeric id),
# Celtics host the Magic.
GAMES = [
    _game("LAL", "Los Angeles Lakers", "1610612759", "San Antonio Spurs"),
    _game("BOS", "Boston Celtics", "ORL", "Orlando Magic"),
]


def test_player_stored_under_a_different_id_scheme_still_plays():
    teams = TeamsPlaying(GAMES)
    # Cameron Carr: stored with "LOS", tonight's game uses "LAL"
    assert teams.plays("Los Angeles Lakers", "LOS")
    # A Spurs player stored with the 3-letter code while the game has the numeric id
    assert teams.plays("San Antonio Spurs", "SAS")


def test_player_without_a_team_id_is_matched_by_name():
    # Malaki Branham: real goalserve_id, team "Orlando Magic", empty team id
    assert TeamsPlaying(GAMES).plays("Orlando Magic", None)
    assert TeamsPlaying(GAMES).plays("Orlando Magic", "")


def test_team_not_playing_is_rejected_whatever_its_id():
    teams = TeamsPlaying(GAMES)
    assert not teams.plays("Miami Heat", "MIA")
    # traded player: stale id still points at a team that plays tonight, but
    # ESPN's (authoritative) team name says he is on a team that does not
    assert not teams.plays("Miami Heat", "LAL")


def test_unknown_team_name_falls_back_to_the_id():
    teams = TeamsPlaying(GAMES)
    assert teams.plays(None, "BOS")
    assert teams.plays("", "ORL")
    assert not teams.plays(None, "XXX")


def test_clippers_spelling_variants_match():
    games = [_game("LAC", "LA Clippers", "DEN", "Denver Nuggets")]
    assert TeamsPlaying(games).plays("Los Angeles Clippers", None)
    assert TeamsPlaying(games).plays("LA Clippers", None)


def test_game_and_home_away_are_resolved_by_team():
    teams = TeamsPlaying(GAMES)
    g = teams.game_for("Los Angeles Lakers", "LOS")
    assert g is GAMES[0]
    assert teams.is_home(g, "Los Angeles Lakers", "LOS") is True
    assert teams.is_home(g, "San Antonio Spurs", "SAS") is False


def test_empty_schedule_is_falsy():
    assert not TeamsPlaying([])


def test_mongo_filter_expresses_the_same_rule():
    f = TeamsPlaying(GAMES).mongo_filter()
    assert f["is_active"] is True
    by_name, by_id = f["$or"]
    assert "Los Angeles Lakers" in by_name["team_name"]["$in"]
    assert "Orlando Magic" in by_name["team_name"]["$in"]
    assert "Miami Heat" not in by_name["team_name"]["$in"]
    # id fallback only for players whose team name is not a known NBA team
    assert "Boston Celtics" in by_id["team_name"]["$nin"]
    assert set(by_id["team_goalserve_id"]["$in"]) == {"LAL", "1610612759", "BOS", "ORL"}
