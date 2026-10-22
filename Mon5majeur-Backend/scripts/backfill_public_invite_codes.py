"""Give an invitation code to the public leagues created before they had one
(Arik QA item 12). Only leagues still waiting and without a code.

    python scripts/backfill_public_invite_codes.py            # dry run
    python scripts/backfill_public_invite_codes.py --apply    # write
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pymongo.errors import DuplicateKeyError

from app.database.session import init_db
from app.modules.leagues.model import League


async def main() -> None:
    apply = "--apply" in sys.argv
    await init_db()
    leagues = await League.find(
        {"type": "public", "status": "waiting", "$or": [{"invite_code": None}, {"invite_code": {"$exists": False}}]}
    ).to_list()
    print(f"{len(leagues)} waiting public league(s) without a code")
    for league in leagues:
        if not apply:
            print(f"  would give a code to league {league.auto_id} '{league.name}'")
            continue
        for _ in range(5):
            league.invite_code = League.generate_invite_code()
            try:
                await league.save()
                print(f"  league {league.auto_id} '{league.name}': {league.invite_code}")
                break
            except DuplicateKeyError:
                continue
    if not apply:
        print("dry run: nothing written")


if __name__ == "__main__":
    asyncio.run(main())
