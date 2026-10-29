"""READ-ONLY: iOS push diagnostics for Robin's report (missing tokens).

    python scripts/check_ios_push.py                 # token coverage, no send
    python scripts/check_ios_push.py --send-to "Lyon 69ers"   # also test-send to one team

Prints, for the 3 named teams: token present (first 6 chars + saved date),
push_notifications_enabled. Then overall iOS-vs-total token coverage.
--send-to sends ONE "Test M5M" to that team's account only.
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database.session import init_db
from app.modules.notifications import fcm
from app.modules.users.model import User

TEAMS = ["Lyon 69ers", "-", "Clebz"]


async def main() -> None:
    send_to = None
    if "--send-to" in sys.argv:
        send_to = sys.argv[sys.argv.index("--send-to") + 1]

    await init_db()
    for name in TEAMS:
        u = await User.find_one(User.team_name == name)
        if not u:
            print(f"{name!r}: account not found")
            continue
        print(
            f"{name!r}: token={'yes ' + u.fcm_token[:6] if u.fcm_token else 'NONE'} "
            f"updated_at={u.updated_at} push_enabled={u.push_notifications_enabled}"
        )
        if send_to == name and u.fcm_token:
            result = await fcm.send_push(u.fcm_token, "Test M5M", "Test notification", {"type": "test"})
            print(f"  send result: ok={result.ok} code={result.code} dead_token={result.dead_token}")

    total = await User.find_all().count()
    with_token = await User.find(User.fcm_token != None).count()  # noqa: E711
    print(f"\ntokens: {with_token}/{total} accounts")


if __name__ == "__main__":
    asyncio.run(main())
