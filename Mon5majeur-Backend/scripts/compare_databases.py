"""Read-only comparison of two MongoDB databases (QA #10 20, step 5).

    OLD_URI=... NEW_URI=... DB_NAME=mon5majeur_db python scripts/compare_databases.py

Prints, per collection, the document count in each database and flags every
difference, then compares a sentinel fact (the latest archived Global score).
Exit code 1 when anything differs. It never writes. Connection strings are
read from the environment and never printed.
"""
from __future__ import annotations

import os
import sys


def diff_counts(old: dict[str, int], new: dict[str, int]) -> list[tuple[str, int, int]]:
    """(collection, old_count, new_count) for every collection that differs."""
    names = sorted(set(old) | set(new))
    return [(n, old.get(n, 0), new.get(n, 0)) for n in names if old.get(n, 0) != new.get(n, 0)]


def _counts(db) -> dict[str, int]:
    return {
        n: db[n].count_documents({})
        for n in db.list_collection_names()
        if not n.startswith("system.")
    }


def main() -> int:
    from pymongo import MongoClient

    old_uri, new_uri = os.environ.get("OLD_URI"), os.environ.get("NEW_URI")
    name = os.environ.get("DB_NAME", "mon5majeur_db")
    if not old_uri or not new_uri:
        print("Set OLD_URI and NEW_URI (and DB_NAME).")
        return 2

    old_db, new_db = MongoClient(old_uri)[name], MongoClient(new_uri)[name]
    old, new = _counts(old_db), _counts(new_db)

    print(f"{'collection':34} {'old':>9} {'new':>9}")
    for n in sorted(set(old) | set(new)):
        flag = "" if old.get(n, 0) == new.get(n, 0) else "   <-- DIFFERENT"
        print(f"{n:34} {old.get(n, 0):9} {new.get(n, 0):9}{flag}")

    bad = diff_counts(old, new)

    # A past night must read the same on both sides.
    def newest_score(db):
        doc = db["global_league_daily_scores"].find_one(sort=[("nba_date", -1)])
        return (doc or {}).get("nba_date"), (doc or {}).get("total_points")

    if newest_score(old_db) != newest_score(new_db):
        print("latest archived Global score differs:", newest_score(old_db), newest_score(new_db))
        bad.append(("global_league_daily_scores(sentinel)", 0, 1))

    print(
        "\nOK: the two databases hold the same data."
        if not bad
        else f"\n{len(bad)} difference(s)."
    )
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
