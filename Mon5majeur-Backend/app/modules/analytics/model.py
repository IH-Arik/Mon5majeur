from datetime import datetime
from typing import Literal

from pymongo import ASCENDING, DESCENDING, IndexModel

from app.database.base import BaseDocument


class AccountDeletionLog(BaseDocument):
    """
    Audit trail of fulfilled account-deletion requests (dashboard block 1,
    "Account deletions").

    Deliberately holds NO personal data: the whole point of a GDPR erasure
    is that the user's row is gone, so counting deletions cannot rely on
    the `users` collection — a hard-deleted user leaves no trace there.
    This log keeps only what is needed to count and date the event, which
    is also what lets us evidence that the request was honoured.

    `user_auto_id` is the sequential integer id, kept purely so a specific
    request can be traced back in support tickets; it is not linkable to a
    person once the account is gone.
    """

    deleted_at: datetime
    user_auto_id: int | None = None
    # "soft"  = anonymised + deactivated (Flutter "Delete Account" button)
    # "hard"  = row and all owned documents purged (admin / v1 users API)
    deletion_type: Literal["soft", "hard"] = "soft"
    # Whether the account had ever validated a lineup — lets deletions be
    # read as a churn signal ("we lost a real player") vs. noise ("someone
    # who never played removed a test account").
    had_validated_lineup: bool = False

    class Settings:
        name = "account_deletion_logs"
        indexes = [
            IndexModel([("deleted_at", DESCENDING)]),
            IndexModel([("deletion_type", ASCENDING)]),
        ]
