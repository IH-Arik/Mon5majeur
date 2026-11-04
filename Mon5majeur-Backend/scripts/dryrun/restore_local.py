"""Load an export (see export_nights.py) into a LOCAL dry-run database.

    MONGODB_URI=mongodb://127.0.0.1:27017 MONGODB_DB_NAME=dryrun_m5m \
        python scripts/dryrun/restore_local.py ./dryrun_export

Refuses to run unless the connection string points at this machine (or the
isolated Docker service) and the database name starts with "dryrun_". The
database is emptied first, then marked so that compare.py accepts it.
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from bson import json_util
from pymongo import MongoClient

from _guard import MARKER, assert_local, assert_no_env_files

COLLECTIONS = ("players", "nba_games", "player_game_stats", "leagues", "league_matches",
               "flutter_player_selections", "global_league_daily_scores")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    folder = Path(sys.argv[1])
    assert_no_env_files()
    uri, name = os.environ.get("MONGODB_URI", ""), os.environ.get("MONGODB_DB_NAME", "")
    assert_local(uri, name)
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))

    client = MongoClient(uri, serverSelectionTimeoutMS=5000)
    client.admin.command("ping")
    db = client[name]
    for coll in db.list_collection_names():
        db.drop_collection(coll)
    for coll in COLLECTIONS:
        docs = json_util.loads((folder / f"{coll}.json").read_text(encoding="utf-8"))
        if docs:
            db[coll].insert_many(docs)
        print(f"{coll:<32}{len(docs):>7}")
    db[MARKER].insert_one({"purpose": "dryrun", "restored_at": datetime.now(timezone.utc),
                           "nights": manifest["nights"]})
    print(f"Restored into {name} on {uri}")


if __name__ == "__main__":
    main()
