"""One lineup state per league and per player (QA #13 items 4 and 7).

The home card, the "Creer une equipe" tab and the 19:00 reminder used to
compute "can this player still edit their team?" three different ways (UTC date
of the day, the league's match day, any game of the date), so the home screen
could say "Compose ton 5" while the tab said "Verrouille". Everything now goes
through `decide_state`:

  open             the night's first tip-off is ahead: the lineup is editable
  locked           the first game started and some game is still to finish
  waiting_results  every game is final (or the cutoff passed), results not yet
                   published (09:00 Paris): not editable
  not_playing      the player has no game that night (qualified and waiting
                   for the other semi-final, eliminated, no duel): nothing to
                   compose, nothing to be reminded of

The real lock time is unchanged: the earliest tip-off of the night.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

OPEN = "open"
LOCKED = "locked"
WAITING_RESULTS = "waiting_results"
NOT_PLAYING = "not_playing"


@dataclass(frozen=True)
class LineupState:
    state: str | None            # None = the league has no night to play yet
    lock_in_seconds: int | None  # None = no game, 0 = locked, >0 = seconds left
    submitted: bool = False
    night: object | None = None  # the NBA date this state is about

    @property
    def concerned(self) -> bool:
        """Has to compose and has not: the only player a reminder is for."""
        return self.state == OPEN and not self.submitted


def decide_state(
    now: datetime,
    tip_off: datetime | None,
    all_games_final: bool,
    cutoff: datetime | None,
) -> tuple[str, int | None]:
    """(state, lock_in_seconds) for a player who has this night to play."""
    if tip_off is None:
        return NOT_PLAYING, None
    if tip_off.tzinfo is None:
        tip_off = tip_off.replace(tzinfo=timezone.utc)
    if now < tip_off:
        return OPEN, max(1, int((tip_off - now).total_seconds()))
    if all_games_final or (cutoff is not None and now >= cutoff):
        return WAITING_RESULTS, 0
    return LOCKED, 0


async def night_facts(night) -> tuple[datetime | None, bool]:
    """(earliest tip-off, every game final) of a night."""
    from app.modules.players.model import NBAGame

    games = await NBAGame.find(NBAGame.nba_date == night).to_list()
    tips = []
    for g in games:
        if g.tip_off_time is None:
            continue
        tip = g.tip_off_time
        tips.append(tip.replace(tzinfo=timezone.utc) if tip.tzinfo is None else tip)
    all_final = bool(games) and all((g.status or "").lower() == "final" for g in games)
    return (min(tips) if tips else None), all_final


async def state_for_night(night, now: datetime | None = None) -> tuple[str, int | None]:
    from app.modules.players.nba_night import publication_cutoff

    now = now or datetime.now(timezone.utc)
    tip, all_final = await night_facts(night)
    return decide_state(now, tip, all_final, publication_cutoff(night))


async def league_state(league, user_id, now: datetime | None = None) -> LineupState:
    """The state of `user_id` in `league`, from the same rules everywhere."""
    from app.modules.leagues.model import LeagueMatch
    from app.modules.lineups.compat_model import FlutterPlayerSelection

    now = now or datetime.now(timezone.utc)

    if league.type == "global":
        from app.modules.players.compat_router import _nba_today
        from app.modules.players.nba_night import composing_night

        night = await composing_night(now) or await _nba_today()
        sel = await FlutterPlayerSelection.find_one(
            FlutterPlayerSelection.user_id == user_id,
            FlutterPlayerSelection.league_auto_id == (league.auto_id or 0),
            FlutterPlayerSelection.nba_date == night,
        )
        state, lock = await state_for_night(night, now)
        return LineupState(state, lock, sel is not None, night)

    if league.status not in ("regular_season", "playoffs"):
        return LineupState(None, None, False, None)

    match = await LeagueMatch.find_one(
        LeagueMatch.league_id == league.id,
        LeagueMatch.match_day == league.current_match_day,
        {"$or": [{"home_user_id": user_id}, {"away_user_id": user_id}]},
    )
    if match is None:
        # Qualified and waiting for the other semi-final, eliminated, or a bye.
        return LineupState(NOT_PLAYING, None, False, None)

    sel = await FlutterPlayerSelection.find_one(
        FlutterPlayerSelection.user_id == user_id,
        FlutterPlayerSelection.league_auto_id == (league.auto_id or 0),
        FlutterPlayerSelection.match_day == league.current_match_day,
    )
    from app.modules.players.nba_night import composing_night

    # The league's match day moves on in the close, a little before everything
    # (prices) is up to date: the next day only opens once the night being
    # composed has been published, at the same instant for every league.
    comp = await composing_night(now)
    if comp is not None and match.nba_date > comp:
        return LineupState(WAITING_RESULTS, 0, sel is not None, match.nba_date)

    state, lock = await state_for_night(match.nba_date, now)
    return LineupState(state, lock, sel is not None, match.nba_date)


async def reopens_at(league, now: datetime | None = None) -> str | None:
    """ISO UTC moment the composition reopens: the publication of the night
    being composed (09:00 Paris after it)."""
    from app.modules.players.nba_night import composing_night, publication_cutoff

    night = await composing_night(now)
    return publication_cutoff(night).isoformat() if night else None


async def ensure_open(league, user_id, match_day: int | None = None, now: datetime | None = None) -> LineupState:
    """Raise 403 lineup_locked (with reopens_at) unless this player can edit a
    lineup or a bonus right now. Used by every entry point that changes one, so
    the app is never the only protection (QA #13 addendum).

    `match_day` is the day the request is for: a duel league only accepts its
    current one (a wrong day is refused)."""
    from app.exceptions.errors import LineupLockedException

    info = await league_state(league, user_id, now)
    wrong_day = (
        match_day is not None
        and league.type != "global"
        and match_day != league.current_match_day
    )
    if wrong_day or info.state in (LOCKED, WAITING_RESULTS):
        raise LineupLockedException(await reopens_at(league, now))
    return info
