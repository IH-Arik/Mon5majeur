"""
One-off CLI: grant or revoke admin (dashboard) access for an existing user by
email. There is no dashboard UI for this by design — the first admin account
has to be promoted from outside the system, and after that admins can be
managed through the User Management screen.

Usage:
    ./.venv/Scripts/python.exe promote_admin.py user@example.com           # grant
    ./.venv/Scripts/python.exe promote_admin.py user@example.com --revoke  # revoke
"""
from __future__ import annotations

import asyncio
import sys

from app.database.session import init_db
from app.modules.users.model import User


async def main(email: str, revoke: bool) -> None:
    await init_db()

    user = await User.find_one(User.email == email)
    if not user:
        print(f"No user found with email: {email}")
        return

    await user.save_updated(is_superuser=not revoke)
    action = "revoked from" if revoke else "granted to"
    print(f"Admin access {action} {email}")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print("Usage: promote_admin.py <email> [--revoke]")
        sys.exit(1)
    asyncio.run(main(args[0], revoke="--revoke" in sys.argv))
