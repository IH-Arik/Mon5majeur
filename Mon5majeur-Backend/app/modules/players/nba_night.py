"""The NBA "night" a moment belongs to.

NBA games are dated by their US date, and a night's games run from Paris
evening D until Paris morning D+1 - i.e. past midnight UTC. The plain UTC
date is therefore WRONG for the small hours (at 03:00 Paris it is already D+1
while the games being played are still night D). The rule used across the app
(see compat_router._nba_today): the UTC date if it has games in the DB,
otherwise the day before.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from app.modules.players.model import NBAGame


async def current_nba_night() -> date:
    utc_today = datetime.now(timezone.utc).date()
    for candidate in (utc_today, utc_today - timedelta(days=1)):
        if await NBAGame.find(NBAGame.nba_date == candidate).count() > 0:
            return candidate
    return utc_today


async def latest_finished_night(today: date) -> date | None:
    """Most recent night strictly before `today` that has games."""
    game = (
        await NBAGame.find(NBAGame.nba_date < today).sort(-NBAGame.nba_date).first_or_none()
    )
    return game.nba_date if game else None


PUBLICATION_HOUR_PARIS = 9


def publication_cutoff(night: date) -> datetime:
    """Moment the results of `night` are published: 09:00 Paris the next day."""
    from zoneinfo import ZoneInfo

    next_day = night + timedelta(days=1)
    return datetime(
        next_day.year, next_day.month, next_day.day, PUBLICATION_HOUR_PARIS, 0,
        tzinfo=ZoneInfo("Europe/Paris"),
    ).astimezone(timezone.utc)


async def live_night(now: datetime | None = None) -> date | None:
    """The night whose scores Live must still show, or None.

    Live shows a night from its first tip-off until the results are published
    at 09:00 Paris (QA #9 7.4 / 12.2: a player waking up at 06:00, games over
    but nothing published yet, saw "no live match"). It is the latest night
    that has a game in progress or finished and whose publication is still
    ahead."""
    now = now or datetime.now(timezone.utc)
    game = (
        await NBAGame.find(
            {"status": {"$in": ["live", "final"]}},
            NBAGame.nba_date <= now.date(),
        )
        .sort(-NBAGame.nba_date)
        .first_or_none()
    )
    if game is None:
        return None
    return game.nba_date if now < publication_cutoff(game.nba_date) else None


def season_start(today: date) -> date:
    """First day of the NBA season `today` belongs to (October 1st). Stats
    from before it are not "this season" (QA #9 4.4: the player sheet showed
    full statistics although no official game had been played)."""
    year = today.year if today.month >= 10 else today.year - 1
    return date(year, 10, 1)


async def _recent_nights(now: datetime, limit: int = 30) -> list[tuple[date, datetime | None]]:
    """(night, first tip-off) of the latest nights up to today, newest first."""
    games = (
        await NBAGame.find(NBAGame.nba_date <= now.date())
        .sort(-NBAGame.nba_date)
        .limit(limit * 16)
        .to_list()
    )
    first_tip: dict[date, datetime | None] = {}
    for g in games:
        tip = g.tip_off_time
        if tip is not None and tip.tzinfo is None:
            tip = tip.replace(tzinfo=timezone.utc)
        if g.nba_date not in first_tip:
            first_tip[g.nba_date] = tip
        elif tip is not None and (first_tip[g.nba_date] is None or tip < first_tip[g.nba_date]):
            first_tip[g.nba_date] = tip
    return list(first_tip.items())[:limit]


def _started(night_first_tip: datetime | None, now: datetime) -> bool:
    return night_first_tip is not None and night_first_tip <= now


async def results_night(now: datetime | None = None) -> date | None:
    """The night the "NBA results" block shows: the last night that has
    started. Last night's results therefore stay up until the first tip-off of
    the new day, and only then does the new day appear (QA #9 3.2)."""
    now = now or datetime.now(timezone.utc)
    for night, tip in await _recent_nights(now):
        if _started(tip, now):
            return night
    return None


async def published_night(now: datetime | None = None) -> date | None:
    """The latest night whose results are published (09:00 Paris after the
    night): what the "fantasy scores of the day" block shows (QA #9 3.1)."""
    now = now or datetime.now(timezone.utc)
    for night, tip in await _recent_nights(now):
        if _started(tip, now) and now >= publication_cutoff(night):
            return night
    return None


def polling_nights(now: datetime | None = None) -> list[date]:
    """Every night whose games may be on the court right now, oldest first.

    A night's games run past 00:00 UTC, so at 02:30 Paris two dates are in play:
    the night that began yesterday (still being played) and the one that begins
    today. Following only one date is what froze every game after the first
    in the live score (QA #10 18): once the schedule for the coming days was
    loaded, "the current night" flipped to the next date at 00:00 UTC while
    the games tipping off at 02:00 Paris still belonged to the previous one."""
    now = now or datetime.now(timezone.utc)
    today = now.date()
    return [today - timedelta(days=1), today]
