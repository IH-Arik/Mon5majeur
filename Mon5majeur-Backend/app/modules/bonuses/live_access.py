"""
Live Scoring has two expiry fields: `UserBonusInventory.live_scoring_until`
(what the Shop shows as "Active ✓") and `User.premium_until` (what unlocks the
live-score endpoints and the score paywall). A purchase writes both, but any
other write (older purchases, admin extension, manual DB edits) can leave them
apart — QA 24/09 #6: Shop said Active while the live screen stayed locked.

`sync_live_scoring` makes them agree, the later expiry winning, and is called
wherever either one is read for Live Scoring.
"""
from __future__ import annotations

from datetime import datetime, timezone

from app.modules.bonuses.model import UserBonusInventory
from app.modules.users.model import User


def _aware(dt: datetime | None) -> datetime | None:
    # MongoDB round-trips datetimes as naive UTC.
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


async def sync_live_scoring(
    user: User, inv: UserBonusInventory | None = None
) -> datetime | None:
    """Align both expiry fields on the later one and return it."""
    if inv is None:
        inv = await UserBonusInventory.find_one(UserBonusInventory.user_id == user.id)

    premium = _aware(user.premium_until)
    shop = _aware(inv.live_scoring_until) if inv else None
    candidates = [d for d in (premium, shop) if d is not None]
    if not candidates:
        return None
    latest = max(candidates)

    # Targeted $set, not save(): must not overwrite concurrent writes to the
    # rest of either document.
    if premium != latest:
        await user.set({User.premium_until: latest})
    if inv is not None and shop != latest:
        await inv.set({UserBonusInventory.live_scoring_until: latest})
    return latest
