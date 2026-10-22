"""Arik QA item 1: a post-game stat correction from Goalserve is picked up."""
import asyncio
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from app.modules.players import service as svc_mod
from app.modules.players.service import PlayerService, _stat_changes

NIGHT = date(2026, 10, 20)


def _box(reb, stl, blk):
    return {
        "goalserve_player_id": "sga", "full_name": "Shai Gilgeous-Alexander",
        "team_goalserve_id": "okc", "position": "G",
        "minutes_played": 34, "did_not_play": False, "points": 30,
        "rebounds": reb, "assists": 6, "steals": stl, "blocks": blk, "turnovers": 2,
        "field_goals_made": 11, "field_goals_attempted": 20,
        "threepoint_made": 2, "threepoint_attempted": 6,
        "freethrow_made": 6, "freethrow_attempted": 7,
    }


def _game(players):
    return [{
        "goalserve_game_id": "g1", "nba_date": NIGHT, "home_team_id": "sas",
        "away_team_id": "okc", "home_team_name": "Spurs", "away_team_name": "Thunder",
        "status": "final", "tip_off_utc": None, "home_score": 100, "away_score": 110,
        "players": players,
    }]


class _Stat(SimpleNamespace):
    async def save(self):
        self.saved = getattr(self, "saved", 0) + 1


def _run_sync(stored, box, published=False):
    stats = MagicMock()
    stats.find_one = AsyncMock(return_value=stored)
    stats.goalserve_game_id = stats.goalserve_player_id = MagicMock()
    games = MagicMock()
    games.find_one = AsyncMock(return_value=None)
    games.goalserve_id = MagicMock()
    inserted = []

    def _new_game(**kw):
        g = SimpleNamespace(**kw)
        g.insert = AsyncMock()
        return g
    games.side_effect = _new_game

    service = PlayerService.__new__(PlayerService)
    player = SimpleNamespace(id="P1", full_name="Shai Gilgeous-Alexander")
    with patch.object(svc_mod, "PlayerGameStats", stats), \
            patch.object(svc_mod, "NBAGame", games), \
            patch.object(PlayerService, "_resolve_goalserve_player", AsyncMock(return_value=player)), \
            patch("app.modules.players.goalserve_client.fetch_scores_for_date",
                  AsyncMock(return_value=_game([box]))), \
            patch("app.modules.players.night_publication.published_marks",
                  AsyncMock(return_value={NIGHT} if published else set())):
        n = asyncio.run(service.sync_scores_for_date(NIGHT))
    return n, inserted


def _stored(**kw):
    fields = {k: v for k, v in _box(5, 2, 2).items() if k not in ("full_name", "team_goalserve_id", "position")}
    fields.update(goalserve_game_id="g1", player_id="P1", nba_date=NIGHT,
                  score_computed=True, fantasy_score=29.0,
                  updated_at=datetime(2026, 10, 21, tzinfo=timezone.utc))
    fields.update(kw)
    return _Stat(**fields)


def test_a_second_sync_with_corrected_values_updates_the_line_and_rescores_it():
    stored = _stored()
    before = stored.updated_at
    _run_sync(stored, _box(6, 3, 3))
    assert (stored.rebounds, stored.steals, stored.blocks) == (6, 3, 3)
    assert stored.score_computed is False          # computed again by finalize
    assert stored.updated_at > before
    assert stored.saved == 1


def test_an_unchanged_line_is_not_rewritten_nor_rescored():
    stored = _stored()
    _run_sync(stored, _box(5, 2, 2))
    assert stored.score_computed is True
    assert getattr(stored, "saved", 0) == 0


def test_a_published_night_is_frozen():
    stored = _stored()
    n, _ = _run_sync(stored, _box(6, 3, 3), published=True)
    assert n == 0 and stored.rebounds == 5


def test_stat_changes_lists_old_and_new_values():
    stored = _stored()
    changes = _stat_changes(stored, {"rebounds": 6, "steals": 2})
    assert changes == {"rebounds": (5, 6)}


def _poll(game):
    from app.cron import jobs

    class _Q:
        def __init__(self, rows):
            self.rows = rows

        async def to_list(self):
            return self.rows

    games = MagicMock()
    games.find = MagicMock(return_value=_Q([game]))
    games.nba_date = MagicMock()
    sync = AsyncMock(return_value=0)
    with patch("app.modules.players.model.NBAGame", games), \
            patch("app.modules.players.service.PlayerService.sync_scores_for_date", sync), \
            patch("app.modules.players.service.PlayerService.finalize_game_scores", AsyncMock(return_value=0)), \
            patch("app.modules.leagues.engine.sync_match_live_status", AsyncMock(return_value=0)):
        asyncio.run(jobs._poll_night(NIGHT))
    return sync


def _final_game(final_minutes_ago, resynced=None):
    g = SimpleNamespace(
        status="final", goalserve_id="g1", tip_off_time=None, resynced_at=resynced,
        final_at=datetime.now(timezone.utc) - timedelta(minutes=final_minutes_ago),
    )
    g.save = AsyncMock()
    return g


def test_a_finished_game_is_fetched_again_about_an_hour_later():
    g = _final_game(65)
    sync = _poll(g)
    sync.assert_awaited_once()
    assert g.resynced_at is not None


def test_not_before_the_hour():
    sync = _poll(_final_game(20))
    sync.assert_not_awaited()


def test_only_once():
    sync = _poll(_final_game(90, resynced=datetime.now(timezone.utc)))
    sync.assert_not_awaited()
