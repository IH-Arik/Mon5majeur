"""READ-ONLY: games recorded twice and games stuck live (Arik QA item 3).

    python scripts/find_duplicate_games.py              # the last 14 nights
    python scripts/find_duplicate_games.py 2026-10-21   # one night

For every matchup recorded more than once on a night it prints each record
(id, status, score, tip-off, created / updated) with its number of player stat
rows, then the players who have a stat row in BOTH records (they would be
counted twice). Writes nothing: the clean-up is a separate, approved step.
"""
from __future__ import annotations

import asyncio
import sys
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.session import init_db
from app.modules.players.model import NBAGame, Player, PlayerGameStats


async def main() -> None:
    await init_db()
    if len(sys.argv) > 1:
        nights = [date.fromisoformat(sys.argv[1])]
    else:
        today = date.today()
        nights = [today - timedelta(days=i) for i in range(14)]
    found = 0
    for night in sorted(nights):
        games = await NBAGame.find(NBAGame.nba_date == night).to_list()
        groups = defaultdict(list)
        for g in games:
            groups[(g.home_team_id, g.away_team_id)].append(g)
        for (home, away), recs in groups.items():
            stuck = [g for g in recs if g.status == "live"]
            if len(recs) < 2 and not stuck:
                continue
            found += 1
            print(f"\n{night} {recs[0].away_team_name} @ {recs[0].home_team_name}: {len(recs)} record(s)")
            players = defaultdict(set)
            for g in recs:
                rows = await PlayerGameStats.find(PlayerGameStats.goalserve_game_id == g.goalserve_id).to_list()
                for r in rows:
                    players[r.player_id].add(g.goalserve_id)
                print(f"  id {g.goalserve_id} status {g.status} score {g.away_score}-{g.home_score} "
                      f"tip {g.tip_off_time} created {g.created_at} updated {g.updated_at} "
                      f"final_at {getattr(g, 'final_at', None)} stat rows {len(rows)}")
            twice = [pid for pid, ids in players.items() if len(ids) > 1]
            for pid in twice:
                p = await Player.get(pid)
                print(f"  counted twice: {p.full_name if p else pid}")
    print(f"\n{found} matchup(s) to look at. Nothing written.")


if __name__ == "__main__":
    asyncio.run(main())
