"""Dry run of tonight's 19:00 reminder (QA #13 item 4): lists who WOULD be
notified. Sends nothing, writes nothing.

    python scripts/qa13_reminder_dryrun.py
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.cron.jobs import reminder_recipients
from app.database.session import init_db
from app.modules.users.model import User


async def main() -> None:
    await init_db()
    recipients = await reminder_recipients()
    print(f"{len(recipients)} player(s) would get the reminder:")
    for user_id, league_auto_id in recipients:
        user = await User.get(user_id)
        label = (user.team_name or user.email.split("@")[0]) if user else str(user_id)
        print(f"  user {user.auto_id if user else '?'}  {label}  (league {league_auto_id})")


if __name__ == "__main__":
    asyncio.run(main())
