"""Robin 10/24: one matchup stored 3 times (real id, stuck copy, empty id)."""
import asyncio
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from app.modules.players import service as svc_mod
from app.modules.players.service import PlayerService, _find_game

NIGHT = date(2026, 10, 22)
FEED = {"goalserve_game_id": "329192", "nba_date": NIGHT, "home_team_id": "phi",
        "away_team_id": "cle", "home_team_name": "76ers", "away_team_name": "Cavaliers"}


def _games(by_id, by_teams):
    fake = MagicMock()
    fake.find_one = AsyncMock(side_effect=[by_id, by_teams])
    return fake


def test_a_known_id_is_used_as_is():
    game = SimpleNamespace(goalserve_id="329192")
    with patch.object(svc_mod, "NBAGame", _games(game, None)):
        assert asyncio.run(_find_game(FEED, adopt_id=True)) is game


def test_the_same_matchup_under_another_id_is_the_same_game_and_takes_the_scores_id():
    stored = SimpleNamespace(goalserve_id="141511")
    with patch.object(svc_mod, "NBAGame", _games(None, stored)):
        found = asyncio.run(_find_game(FEED, adopt_id=True))
    assert found is stored and stored.goalserve_id == "329192"


def test_the_schedule_never_re_keys_a_game():
    stored = SimpleNamespace(goalserve_id="329192")
    with patch.object(svc_mod, "NBAGame", _games(None, stored)):
        found = asyncio.run(_find_game({**FEED, "goalserve_game_id": "141511"}, adopt_id=False))
    assert found is stored and stored.goalserve_id == "329192"


def test_a_feed_game_without_id_is_skipped_with_its_players():
    games = MagicMock()
    games.find_one = AsyncMock()
    stats = MagicMock()
    stats.find_one = AsyncMock()
    entry = {**FEED, "goalserve_game_id": "", "status": "final", "tip_off_utc": None,
             "players": [{"goalserve_player_id": "p1", "full_name": "X"}]}
    service = PlayerService.__new__(PlayerService)
    with patch.object(svc_mod, "NBAGame", games), patch.object(svc_mod, "PlayerGameStats", stats), \
            patch("app.modules.players.goalserve_client.fetch_scores_for_date", AsyncMock(return_value=[entry])), \
            patch("app.modules.players.night_publication.published_marks", AsyncMock(return_value=set())):
        n = asyncio.run(service.sync_scores_for_date(NIGHT))
    assert n == 0
    games.find_one.assert_not_awaited()
    stats.find_one.assert_not_awaited()
