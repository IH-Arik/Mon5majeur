"""
Server-side score paywall for duel matches (QA 15/09/2026 item 4).

* Live Scoring subscribers (`premium_until` in the future) — and admins —
  always see real scores: in real time and after the match.
* Everyone else sees no numbers while the match is live, nor after it ends,
  until 09:00 Paris time on the morning after the NBA night. Until then the
  API returns zeros and `scores_hidden = true`; the app shows "Score dispo à 9h".

This MUST be enforced here, not in the app: hiding the digits client-side
would leave the paywall bypassable by anyone reading the raw API response.
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from app.modules.users.model import User

PARIS = ZoneInfo("Europe/Paris")
RELEASE_HOUR_PARIS = 9


def score_release_at(nba_date: date) -> datetime:
    """UTC instant the scores of an NBA night become visible to
    non-subscribers: 09:00 Paris on the day after `nba_date` (the US date the
    games were played on; they end in the small hours of that next day)."""
    release_local = datetime.combine(
        nba_date + timedelta(days=1), time(RELEASE_HOUR_PARIS), tzinfo=PARIS
    )
    return release_local.astimezone(timezone.utc)


def has_live_access(user: User) -> bool:
    from app.modules.live_scores.service import _is_premium

    return bool(user.is_superuser) or _is_premium(user)


def scores_hidden(
    user: User,
    *,
    status: str,
    nba_date: date | None,
    now: datetime | None = None,
) -> bool:
    """True when `user` must not receive this match's scores.

    `status` is either vocabulary in use ("upcoming"/"scheduled" = not played
    yet, "live", "completed"). A not-yet-started match has no scores to hide.
    """
    if status in ("upcoming", "scheduled"):
        return False
    if has_live_access(user):
        return False
    if status == "live":
        return True
    if nba_date is None:
        return False
    now = now or datetime.now(timezone.utc)
    return now < score_release_at(nba_date)


def release_iso(nba_date: date | None) -> str | None:
    return score_release_at(nba_date).isoformat() if nba_date else None
