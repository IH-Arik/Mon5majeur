"""
One-off backfill: stamp `nba_date` on FlutterPlayerSelection rows written
before that field existed.

Run once after deploying the retention dashboard. Until it has run, those
legacy lineups are missing from every per-night figure (DAU, lineups
tonight, volume, cohort retention) — they are excluded rather than guessed
at, so the dashboard is incomplete but never wrong.

Resolution order per row, most reliable first:
  1. The league's own LeagueMatch for that match_day  → its nba_date.
     Authoritative: it is the night the duel was actually scheduled for.
  2. The Global League (no LeagueMatch rows exist): the user's
     GlobalLeagueDailyScore for that league, matched by match_day ordering
     of archived nights.
  3. Fall back to the match night closest to `submitted_at` that is not
     after it — a lineup is always submitted before its own tip-off.
Rows that still cannot be resolved are left as None and reported, never
assigned an approximate date.

Usage:
    ./.venv/Scripts/python.exe backfill_lineup_nba_date.py            # dry run
    ./.venv/Scripts/python.exe backfill_lineup_nba_date.py --apply    # write
"""
from __future__ import annotations

import asyncio
import sys
from collections import Counter
from datetime import date, datetime

from app.database.session import init_db
from app.modules.leagues.constants import LEAGUE_TYPE_GLOBAL
from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
from app.modules.leagues.model import League, LeagueMatch
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.players.model import NBAGame


def _as_date(value: datetime | date | None) -> date | None:
    if value is None:
        return None
    return value.date() if isinstance(value, datetime) else value


async def main(apply: bool) -> None:
    await init_db()

    rows = await FlutterPlayerSelection.find({"nba_date": None}).to_list()
    print(f"rows missing nba_date: {len(rows)}")
    if not rows:
        print("nothing to do")
        return

    leagues = {lg.id: lg for lg in await League.find_all().to_list()}
    match_nights = sorted(
        {_as_date(g.nba_date) for g in await NBAGame.find_all().to_list()}
    )

    # (league_id, match_day) -> nba_date, from the duel schedule.
    schedule: dict[tuple, date] = {}
    for m in await LeagueMatch.find_all().to_list():
        schedule.setdefault((m.league_id, m.match_day), _as_date(m.nba_date))

    # Global League: ordered list of nights that were actually archived.
    global_nights: dict = {}
    for lg in leagues.values():
        if lg.type != LEAGUE_TYPE_GLOBAL:
            continue
        scores = (
            await GlobalLeagueDailyScore.find(GlobalLeagueDailyScore.league_id == lg.id)
            .sort(+GlobalLeagueDailyScore.nba_date)
            .to_list()
        )
        global_nights[lg.id] = list(
            dict.fromkeys(_as_date(s.nba_date) for s in scores)
        )

    reasons: Counter = Counter()
    updates: list[tuple[FlutterPlayerSelection, date]] = []

    for row in rows:
        night = schedule.get((row.league_id, row.match_day))
        source = "league_match"

        if night is None:
            nights = global_nights.get(row.league_id) or []
            # match_day is 1-based in the Global League's archived sequence
            idx = row.match_day - 1
            if 0 <= idx < len(nights):
                night = nights[idx]
                source = "global_archive"

        if night is None:
            submitted = _as_date(row.submitted_at)
            candidates = [n for n in match_nights if submitted and n <= submitted]
            if candidates:
                night = candidates[-1]
                source = "submitted_at_fallback"

        if night is None:
            reasons["unresolved"] += 1
            continue

        reasons[source] += 1
        updates.append((row, night))

    print("\nresolution breakdown:")
    for k, v in reasons.most_common():
        print(f"  {k:<24} {v}")

    if not apply:
        print("\nDRY RUN — nothing written. Re-run with --apply to persist.")
        return

    written = 0
    for row, night in updates:
        row.nba_date = night
        await row.save()
        written += 1

    print(f"\nwrote nba_date on {written} rows; {reasons['unresolved']} left as None")


if __name__ == "__main__":
    asyncio.run(main(apply="--apply" in sys.argv))
