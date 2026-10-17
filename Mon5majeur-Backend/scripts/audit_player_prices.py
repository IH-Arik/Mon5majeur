"""READ-ONLY audit of player prices and statistics (Final QA item 3).

    python scripts/audit_player_prices.py                  # summary + CSV in /tmp
    python scripts/audit_player_prices.py --name "CJ Huntley"   # one player in detail

Writes nothing to the database. For every player it compares:
  - the displayed price / average / games played (what the app shows),
  - the price the formula gives from the player's last 5 PLAYED games
    (pricing.compute_price, unchanged), once from ALL stat rows and once from
    REAL box scores only,
and flags why a player looks frozen or like test data:

  TEST_STATS        a stat row whose game is a QA/test game (id not a Goalserve
                    id) or whose game does not exist in nba_games
  PRE_SEASON        a real game dated before the season start (Oct 1)
  STALE_AVG         the displayed average is not the average of the last 5
                    played games (the average is only refreshed when the player
                    has a scored game: it never goes back to 0 afterwards)
  PRICE_MISMATCH    the displayed price differs from the formula (all rows)
  PRICE_NOT_REAL    the formula gives another price from real box scores only
  NEVER_RECOMPUTED  price_computed_at is empty or older than the latest close
  INACTIVE_STATS    inactive player: the daily recompute skips inactive players,
                    so their price is frozen
  NO_STATS_BUT_AVG  a displayed average with no played game at all

The CSV is the dry-run to show before any cleaning.
"""
from __future__ import annotations

import argparse
import asyncio
import csv
import sys
import tempfile
from collections import Counter
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.session import init_db
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.nba_night import season_start
from app.modules.players.pricing import compute_price


def _is_real_game_id(game_id: str, known_games: set[str]) -> bool:
    gid = str(game_id or "")
    return gid.isdigit() and gid in known_games


def _played(rows):
    return [s for s in rows if s.score_computed and not s.did_not_play and s.fantasy_score is not None]


def _last5(rows):
    return sorted(_played(rows), key=lambda s: s.nba_date, reverse=True)[:5]


def _avg(rows) -> float:
    scores = [s.fantasy_score for s in rows]
    return round(sum(scores) / len(scores), 2) if scores else 0.0


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name")
    args = parser.parse_args()

    await init_db()
    today = date.today()
    start = season_start(today)

    known = {g.goalserve_id for g in await NBAGame.find_all().to_list()}
    stats_by_player: dict = {}
    for s in await PlayerGameStats.find_all().to_list():
        stats_by_player.setdefault(s.player_id, []).append(s)

    latest_recompute = None
    players = await Player.find_all().to_list()
    for p in players:
        if p.price_computed_at and (latest_recompute is None or p.price_computed_at > latest_recompute):
            latest_recompute = p.price_computed_at

    rows_out = []
    reasons_count: Counter = Counter()
    created_by_day: Counter = Counter()
    for p in players:
        rows = stats_by_player.get(p.id, [])
        real = [s for s in rows if _is_real_game_id(s.goalserve_game_id, known)]
        test = [s for s in rows if not _is_real_game_id(s.goalserve_game_id, known)]
        pre = [s for s in real if s.nba_date < start]

        price_all = compute_price(_last5(rows))
        price_real = compute_price(_last5(real))
        last5_all = _last5(rows)

        reasons = []
        if test:
            reasons.append("TEST_STATS")
        if pre:
            reasons.append("PRE_SEASON")
        if rows and abs(_avg(last5_all) - (p.avg_fantasy_score or 0.0)) > 0.51:
            reasons.append("STALE_AVG")
        if not last5_all and (p.avg_fantasy_score or 0) > 0:
            reasons.append("NO_STATS_BUT_AVG")
        if abs(price_all - (p.daily_price or 0.0)) > 0.01:
            reasons.append("PRICE_MISMATCH")
        if abs(price_real - price_all) > 0.01:
            reasons.append("PRICE_NOT_REAL")
        if p.price_computed_at is None or (latest_recompute and p.price_computed_at < latest_recompute):
            reasons.append("NEVER_RECOMPUTED")
        if not p.is_active and rows:
            reasons.append("INACTIVE_STATS")

        if p.created_at:
            created_by_day[p.created_at.date().isoformat()] += 1
        for r in reasons:
            reasons_count[r] += 1

        rows_out.append({
            "player": p.full_name, "id": str(p.id), "team": p.team_name or "",
            "active": p.is_active, "goalserve_id": p.goalserve_id,
            "shown_price": p.daily_price, "shown_avg": p.avg_fantasy_score,
            "games_played": p.games_played, "price_computed_at": p.price_computed_at,
            "formula_price_all_rows": price_all, "formula_price_real_only": price_real,
            "avg_last5_all_rows": _avg(last5_all),
            "rows_total": len(rows), "rows_real": len(real), "rows_test": len(test),
            "rows_pre_season": len(pre),
            "test_game_ids": ";".join(sorted({str(s.goalserve_game_id) for s in test}))[:120],
            "reasons": " ".join(reasons),
        })

        if args.name and args.name.lower() in p.full_name.lower():
            print(f"\n== {p.full_name} (id {p.id}, gid {p.goalserve_id}, team {p.team_name}, active {p.is_active})")
            print(f"   shown: price {p.daily_price} avg {p.avg_fantasy_score} games {p.games_played} "
                  f"computed_at {p.price_computed_at} created {p.created_at}")
            print(f"   formula: price(all rows)={price_all} price(real only)={price_real} reasons={reasons}")
            for s in sorted(rows, key=lambda s: s.nba_date, reverse=True):
                kind = "REAL" if _is_real_game_id(s.goalserve_game_id, known) else "TEST?"
                print(f"   {s.nba_date} game {s.goalserve_game_id} [{kind}] pts {s.points} "
                      f"fp {s.fantasy_score} computed {s.score_computed} dnp {s.did_not_play}")

    out = Path(tempfile.gettempdir()) / f"audit_player_prices_{datetime.now():%Y%m%d_%H%M%S}.csv"
    flagged = [r for r in rows_out if r["reasons"]]
    with out.open("w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows_out[0].keys()))
        writer.writeheader()
        writer.writerows(flagged)

    print(f"\nplayers: {len(players)} (active {sum(1 for p in players if p.is_active)})")
    print(f"flagged: {len(flagged)}  -> {out}")
    for reason, n in reasons_count.most_common():
        print(f"  {reason:18s} {n}")
    print("\nplayers created per day (last 10 days with creations):")
    for day, n in sorted(created_by_day.items())[-10:]:
        print(f"  {day}: {n}")
    espn = sum(1 for p in players if str(p.goalserve_id).startswith("espn:"))
    print(f"\nplayers still on an espn: id (never matched to a Goalserve id): {espn}")
    print("This run wrote nothing.")


if __name__ == "__main__":
    asyncio.run(main())
