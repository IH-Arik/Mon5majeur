"""
Database side of the substitute rule: reads the minutes and the games, calls the
pure ``apply_substitution`` and hands back the five starters that count.

Two modes, because "no stat row" means two different things:

* closing=True  - the night is being closed (09:00 archive, duel close, repair
  scripts). A player with no stat row, or whose game is not final (postponed...),
  counts as 0 minute and the substitution applies normally.
* closing=False - the night is still being played or shown live. Nothing is
  decided until the game of EVERY player of the lineup (the five starters and
  the substitute) is final in the games table. A game not started, or in
  progress with 0 minute so far, never triggers a replacement.
"""
from __future__ import annotations

from datetime import date, datetime

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.modules.leagues.substitution import (
    ENTERED, NONE, SubstitutionResult, apply_substitution,
)
from app.modules.players.model import NBAGame, Player, PlayerGameStats

logger = get_logger(__name__)


def _oids(people: list[dict]) -> list[PydanticObjectId]:
    out = []
    for p in people:
        try:
            out.append(PydanticObjectId(str(p.get("id", ""))))
        except Exception:
            pass
    return out


async def _minutes(people: list[dict], nba_date: date) -> dict[str, int]:
    oids = _oids(people)
    if not oids:
        return {}
    rows = await PlayerGameStats.find(
        {"player_id": {"$in": oids}, "nba_date": datetime.combine(nba_date, datetime.min.time())}
    ).to_list()
    return {str(r.player_id): 0 if r.did_not_play else (r.minutes_played or 0) for r in rows}


async def _game_statuses(people: list[dict], nba_date: date) -> dict[str, str | None] | None:
    """player id -> status of his team's game that night (None = no game).
    None as a whole when a player cannot be found."""
    from app.modules.players.nba_night import drop_duplicate_games
    from app.modules.players.teams_playing import TeamsPlaying

    oids = _oids(people)
    if len(oids) != len(people):
        return None
    players = await Player.find({"_id": {"$in": oids}}).to_list()
    if len(players) != len(set(oids)):
        return None
    games = drop_duplicate_games(await NBAGame.find(NBAGame.nba_date == nba_date).to_list())
    teams = TeamsPlaying(games)
    out: dict[str, str | None] = {}
    for pl in players:
        game = teams.game_for(pl.team_name, pl.team_goalserve_id)
        out[str(pl.id)] = game.status if game is not None else None
    return out


async def _all_games_final(people: list[dict], nba_date: date) -> bool:
    """True when every player's team game of that night is final. A player whose
    team has no game that night, or who cannot be found, is not settled."""
    statuses = await _game_statuses(people, nba_date)
    return statuses is not None and all(st == "final" for st in statuses.values())


async def _warn_if_decided_on_unfinished_game(
    result: SubstitutionResult, nba_date: date, user_id
) -> None:
    """A substitution decided at the close while the game of the replaced
    starter or of the substitute is not final (postponed, stuck live): only a
    trace in the logs, no alert."""
    if result.status != ENTERED:
        return
    rid, sid = str(result.replaced.get("id", "")), str(result.substitute.get("id", ""))
    try:
        statuses = await _game_statuses([result.replaced, result.substitute], nba_date) or {}
    except Exception:  # noqa: BLE001 - a trace must never fail the close
        logger.debug("substitution trace skipped: games lookup failed", exc_info=True)
        return
    if all(statuses.get(i) == "final" for i in (rid, sid)):
        return
    logger.warning(
        "Substitution decided on a game that is not final: user=%s night=%s "
        "replaced=%s (%s) game=%s substitute=%s (%s) game=%s",
        user_id, nba_date,
        rid, result.replaced.get("name", ""), statuses.get(rid) or "no game",
        sid, result.substitute.get("name", ""), statuses.get(sid) or "no game",
    )


async def resolve_substitution(
    selected_players: list[dict],
    substitute: dict | None,
    nba_date: date,
    *,
    closing: bool,
    user_id=None,
) -> SubstitutionResult:
    if substitute is None:
        return apply_substitution(selected_players, None, {})
    people = list(selected_players) + [substitute]
    settled = True if closing else await _all_games_final(people, nba_date)
    minutes = await _minutes(people, nba_date) if settled else {}
    result = apply_substitution(selected_players, substitute, minutes, settled=settled)
    if closing:
        await _warn_if_decided_on_unfinished_game(result, nba_date, user_id)
    return result


async def counted_starters(sel, nba_date: date, *, closing: bool = True) -> list[dict]:
    """The five players whose scores count. A lineup without a substitute is
    returned as saved, with no extra query."""
    sub = getattr(sel, "substitute_player", None)
    if sub is None:
        return sel.selected_players
    result = await resolve_substitution(
        sel.selected_players, sub, nba_date, closing=closing, user_id=getattr(sel, "user_id", None)
    )
    return result.starters


def describe(result: SubstitutionResult) -> dict | None:
    """What a screen needs to draw the substitution; None for a lineup without
    a substitute. ``replaced_id`` is only set once he has really come in."""
    if result.status == NONE:
        return None
    return {
        "status": result.status,
        "replaced_id": str(result.replaced.get("id", "")) if result.status == ENTERED else None,
    }


def mark_absent(items: list[dict], result: SubstitutionResult) -> None:
    """Flag the replaced starter ("absent") in already-built display items."""
    if result.status != ENTERED:
        return
    gone = str(result.replaced.get("id", ""))
    for item in items:
        if str(item.get("id", "")) == gone:
            item["absent"] = True
