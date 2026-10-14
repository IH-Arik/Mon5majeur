"""Send ONE test notification ("Test M5M") to ONE account's token (QA #13 item 8).

    python scripts/qa13_test_push.py --email robzerr@example.com             # read-only: token status only
    python scripts/qa13_test_push.py --email robzerr@example.com --send      # sends the single test push

Never sends to any other account. Prints the first 6 characters of the token
and the date it was saved, never the whole token, and the exact FCM answer
(message id, or the error class: UnregisteredError, SenderIdMismatchError,
ThirdPartyAuthError...). Also reports whether FCM_CREDENTIALS_PATH points to a
file that loads, without printing its content. The test account only: never
use a personal account.
"""
from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings
from app.database.session import init_db
from app.modules.notifications import fcm
from app.modules.users.model import User


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", required=True)
    parser.add_argument("--send", action="store_true")
    args = parser.parse_args()

    path = settings.FCM_CREDENTIALS_PATH
    print("FCM_CREDENTIALS_PATH set:", bool(path), "| file present:", bool(path and os.path.isfile(path)))
    print("FCM credentials load:", fcm._init_fcm())

    await init_db()
    user = await User.find_one(User.email == args.email.lower())
    if not user:
        print("account not found")
        return
    token = user.fcm_token
    saved = getattr(user, "updated_at", None)
    print(
        "token registered:", bool(token),
        "| first 6 chars:", token[:6] if token else "-",
        "| account last updated:", saved,
        "| push enabled:", user.push_notifications_enabled,
    )
    if not token or not args.send:
        if not args.send:
            print("read-only run: nothing sent (add --send to send the test)")
        return

    result = await fcm.send_push(token, "Test M5M", "Test notification", {"type": "test"})
    print("FCM answer:", result.code, "| ok:", result.ok, "| dead token:", result.dead_token)


if __name__ == "__main__":
    asyncio.run(main())
