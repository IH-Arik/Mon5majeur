"""
"Does this player's team play tonight?" — one rule for the whole backend.

Why: the same team appears in `nba_games` under several team ids (Lakers as
both "LOS" and "LAL", Spurs as the NBA.com numeric "1610612759", the rest as
Goalserve 3-letter codes), because the schedule feed, the scores feed and the
old NBA-CDN seed each used their own scheme. Comparing `player.team_goalserve_id`
to a game's team ids therefore drops perfectly valid players — and, in the
lineup validators, rejects a valid pick as "does not play tonight".

The team *name* is the one identity every source agrees on, so the rule is:

  * a player whose `team_name` maps to a known NBA team is matched by that
    team (trigram) against the teams in tonight's games;
  * only a player whose team name is unknown/missing falls back to comparing
    the raw team id.

`TeamsPlaying.mongo_filter()` expresses exactly the same rule as a Mongo
query, so paginated lists and per-player checks can never disagree.
"""
from __future__ import annotations

from app.modules.players.team_trigrams import (
    KNOWN_TEAM_NAMES,
    names_for_trigrams,
    trigram_for_team_name,
)


class TeamsPlaying:
    def __init__(self, games) -> None:
        self.ids: set[str] = set()
        self.trigrams: set[str] = set()
        self._game_by_id: dict[str, object] = {}
        self._game_by_tri: dict[str, object] = {}
        for g in games:
            for team_id, name in (
                (g.home_team_id, g.home_team_name),
                (g.away_team_id, g.away_team_name),
            ):
                if team_id:
                    self.ids.add(team_id)
                    self._game_by_id[team_id] = g
                tri = trigram_for_team_name(name)
                if tri:
                    self.trigrams.add(tri)
                    self._game_by_tri[tri] = g

    def __bool__(self) -> bool:
        return bool(self.ids or self.trigrams)

    def game_for(self, team_name: str | None, team_id: str | None):
        """Tonight's game for this team, or None if it does not play."""
        tri = trigram_for_team_name(team_name)
        if tri:
            return self._game_by_tri.get(tri)
        return self._game_by_id.get(team_id or "")

    def plays(self, team_name: str | None, team_id: str | None) -> bool:
        return self.game_for(team_name, team_id) is not None

    def is_home(self, game, team_name: str | None, team_id: str | None) -> bool:
        tri = trigram_for_team_name(team_name)
        if tri:
            return trigram_for_team_name(game.home_team_name) == tri
        return (team_id or "") == game.home_team_id

    def mongo_filter(self) -> dict:
        """Active players whose team plays tonight — same rule as plays()."""
        return {
            "is_active": True,
            "$or": [
                {"team_name": {"$in": names_for_trigrams(self.trigrams)}},
                {
                    "team_name": {"$nin": KNOWN_TEAM_NAMES},
                    "team_goalserve_id": {"$in": sorted(self.ids)},
                },
            ],
        }
