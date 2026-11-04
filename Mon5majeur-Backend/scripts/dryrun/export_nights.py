"""READ-ONLY export of past nights for the substitute dry-run.

    EXPORT_MONGODB_URI="mongodb://..."  python scripts/dryrun/export_nights.py --suggest
    EXPORT_MONGODB_URI="mongodb://..."  python scripts/dryrun/export_nights.py \
        --night 2026-10-21 --night 2026-10-30

What it does on the production database: find() and distinct() only. The
collections are wrapped so that any other call (insert, update, delete, index,
aggregate with $out...) raises before reaching the server. Prefer a read-only
database user (see scripts/dryrun/README.md).

What it writes (one folder, on this machine; default scripts/dryrun/export, and
the script refuses any folder that git does not ignore): lineups, tonight's player stats,
games, matches and published scores of the chosen nights.
  * user and league identifiers are replaced by aliases (same user = same alias
    inside the export; the key is random, used once and never stored, so the
    aliases cannot be turned back into real ids);
  * the `users` collection is NEVER read: no email, name, birth date, token;
  * league names are replaced by "League <number>";
  * every document is rebuilt from a whitelist of fields, then the files are
    scanned for anything that looks like an email or a secret.
"""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import re
import secrets
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import date, datetime, time, timedelta
from pathlib import Path

from bson import ObjectId, json_util
from pymongo import MongoClient

DEFAULT_OUT = Path(__file__).resolve().parent / "export"
READ_ONLY_METHODS = {"find", "find_one", "distinct", "count_documents"}


class _ReadOnly:
    """A collection that can only be read."""

    def __init__(self, coll):
        self._coll = coll

    def __getattr__(self, name):
        if name not in READ_ONLY_METHODS:
            raise PermissionError(f"export is read-only: '{name}' is not allowed")
        return getattr(self._coll, name)


def midnight(d: date) -> datetime:
    return datetime.combine(d, time.min)


# ── anonymisation ────────────────────────────────────────────────────────────

class Aliaser:
    """Stable fake ObjectIds: HMAC of the real id with a random key kept only in
    memory. Same input -> same alias within this run; irreversible."""

    def __init__(self):
        self._key = secrets.token_bytes(32)

    def __call__(self, value) -> ObjectId | None:
        if value is None:
            return None
        digest = hmac.new(self._key, str(value).encode(), hashlib.sha256).hexdigest()
        return ObjectId(digest[:24])


# ── whitelists: a field not listed here is never exported ────────────────────

PLAYER_FIELDS = ("id", "name", "position", "price")


def lineup_player(p):
    return None if p is None else {k: p[k] for k in PLAYER_FIELDS if k in p}


def selection(doc, alias):
    return {
        "_id": alias(doc["_id"]),
        "user_id": alias(doc["user_id"]),
        "league_id": alias(doc.get("league_id")),
        "league_auto_id": doc.get("league_auto_id"),
        "match_day": doc.get("match_day"),
        "nba_date": doc.get("nba_date"),
        "submitted_at": doc.get("submitted_at"),
        "selected_players": [lineup_player(p) for p in doc.get("selected_players", [])],
        "luxury_tax": bool(doc.get("luxury_tax")),
        "chef_curry": bool(doc.get("chef_curry")),
        "sixth_man_player": lineup_player(doc.get("sixth_man_player")),
        "substitute_player": lineup_player(doc.get("substitute_player")),
    }


def league(doc, alias):
    return {
        "_id": alias(doc["_id"]), "auto_id": doc.get("auto_id"), "name": f"League {doc.get('auto_id')}",
        "type": doc.get("type"), "status": doc.get("status"), "budget": doc.get("budget"),
        "max_size": doc.get("max_size"), "current_match_day": doc.get("current_match_day"),
    }


def match(doc, alias):
    return {
        "_id": alias(doc["_id"]), "league_id": alias(doc["league_id"]), "match_day": doc.get("match_day"),
        "nba_date": doc.get("nba_date"), "home_user_id": alias(doc["home_user_id"]),
        "away_user_id": alias(doc["away_user_id"]), "home_score": doc.get("home_score"),
        "away_score": doc.get("away_score"), "winner_id": alias(doc.get("winner_id")),
        "status": doc.get("status"), "auto_id": doc.get("auto_id"), "is_playoff": bool(doc.get("is_playoff")),
        "home_seed": doc.get("home_seed"), "away_seed": doc.get("away_seed"),
    }


def global_score(doc, alias):
    return {
        "_id": alias(doc["_id"]), "user_id": alias(doc["user_id"]), "league_id": alias(doc["league_id"]),
        "nba_date": doc.get("nba_date"), "total_points": doc.get("total_points"),
    }


PUBLIC_PLAYER = ("goalserve_id", "first_name", "last_name", "full_name", "position", "team_name",
                 "team_goalserve_id", "daily_price", "is_active", "is_out")
PUBLIC_STATS = ("player_id", "goalserve_player_id", "goalserve_game_id", "nba_date", "points", "rebounds",
                "assists", "steals", "blocks", "turnovers", "field_goals_made", "field_goals_attempted",
                "threepoint_made", "threepoint_attempted", "freethrow_made", "freethrow_attempted",
                "fantasy_score", "score_computed", "minutes_played", "did_not_play")
PUBLIC_GAME = ("goalserve_id", "nba_date", "home_team_id", "away_team_id", "home_team_name",
               "away_team_name", "status", "tip_off_time", "home_score", "away_score", "final_at")


def pick(doc, fields, keep_id=True):
    out = {k: doc[k] for k in fields if k in doc}
    if keep_id:
        out["_id"] = doc["_id"]            # public NBA data keeps its real id
    return out


# ── export ───────────────────────────────────────────────────────────────────

def ensure_ignored_by_git(out: Path) -> None:
    """Real (anonymised) lineups must never end up in a commit: refuse to write
    anywhere git does not ignore, or when that cannot be verified."""
    probe = out.resolve() / "manifest.json"
    try:
        result = subprocess.run(["git", "check-ignore", "-q", str(probe)],
                                cwd=Path(__file__).resolve().parent, capture_output=True)
    except FileNotFoundError:
        sys.exit("REFUSED: git is not available, cannot check that the output folder is ignored.")
    if result.returncode != 0:
        sys.exit(f"REFUSED: {out.resolve()} is not ignored by git (or is outside the repository). "
                 "Use the default scripts/dryrun/export, or add the folder to .gitignore first.")


def connect():
    uri = os.environ.get("EXPORT_MONGODB_URI", "")
    if not uri:
        sys.exit("Set EXPORT_MONGODB_URI (the production connection string) in your shell.")
    client = MongoClient(uri, appname="m5m-dryrun-export-readonly", serverSelectionTimeoutMS=8000)
    name = os.environ.get("EXPORT_DB_NAME", "mon5majeur_db")
    try:
        info = client.admin.command("connectionStatus")["authInfo"].get("authenticatedUserRoles", [])
        write_roles = [r["role"] for r in info if r["role"] in {"readWrite", "readWriteAnyDatabase", "dbOwner", "root"}]
        if write_roles:
            print(f"WARNING: this user could write ({', '.join(write_roles)}). The script only reads, "
                  "but a read-only user is safer.", file=sys.stderr)
    except Exception:  # noqa: BLE001 - informational only
        pass
    db = client[name]
    return {n: _ReadOnly(db[n]) for n in (
        "flutter_player_selections", "players", "player_game_stats", "nba_games", "leagues",
        "league_matches", "global_league_daily_scores")}


def suggest(c, days):
    """Table of recent nights to help choosing: a normal one, and one where a
    lineup had a starter of 10M+ who played 0 minute."""
    start = midnight(date.today() - timedelta(days=days))
    lineups = defaultdict(list)
    for d in c["flutter_player_selections"].find({"nba_date": {"$gte": start}},
                                                 {"nba_date": 1, "selected_players": 1}):
        lineups[d["nba_date"]].append(d.get("selected_players", []))
    print(f"{'night':<12}{'lineups':>8}{'games final/all':>17}{'lineups with an absent 10M+ starter':>40}")
    for night in sorted(lineups):
        games = list(c["nba_games"].find({"nba_date": night}, {"status": 1}))
        finals = sum(1 for g in games if g.get("status") == "final")
        absent = {s["player_id"] for s in c["player_game_stats"].find(
            {"nba_date": night, "$or": [{"minutes_played": 0}, {"did_not_play": True}]}, {"player_id": 1})}
        absent_ids = {str(a) for a in absent}
        hit = sum(
            1 for team in lineups[night]
            if any(str(p.get("id")) in absent_ids and _price(p) >= 10 for p in team)
        )
        print(f"{night.date()!s:<12}{len(lineups[night]):>8}{f'{finals}/{len(games)}':>17}{hit:>40}")


def _price(p):
    try:
        return float(str(p.get("price", "0")).replace("M", ""))
    except ValueError:
        return 0.0


def export(c, nights, out: Path):
    alias = Aliaser()
    out.mkdir(parents=True, exist_ok=True)
    files: dict[str, list] = {k: [] for k in (
        "flutter_player_selections", "players", "player_game_stats", "nba_games", "leagues",
        "league_matches", "global_league_daily_scores")}

    league_oids, league_autos, player_ids = set(), set(), set()
    for night in nights:
        n = midnight(night)
        for d in c["flutter_player_selections"].find({"nba_date": n}):
            files["flutter_player_selections"].append(selection(d, alias))
            league_autos.add(d.get("league_auto_id"))
            for p in d.get("selected_players", []) + [d.get("sixth_man_player"), d.get("substitute_player")]:
                if p and p.get("id"):
                    player_ids.add(str(p["id"]))
        for d in c["league_matches"].find({"nba_date": n}):
            files["league_matches"].append(match(d, alias))
            league_oids.add(d["league_id"])
        for d in c["global_league_daily_scores"].find({"nba_date": n}):
            files["global_league_daily_scores"].append(global_score(d, alias))
            league_oids.add(d["league_id"])
        for d in c["nba_games"].find({"nba_date": n}):
            files["nba_games"].append(pick(d, PUBLIC_GAME))
        for d in c["player_game_stats"].find({"nba_date": n}):
            files["player_game_stats"].append(pick(d, PUBLIC_STATS))
            player_ids.add(str(d["player_id"]))

    seen = set()
    for d in c["leagues"].find({"$or": [{"_id": {"$in": list(league_oids)}},
                                        {"auto_id": {"$in": [a for a in league_autos if a is not None]}}]}):
        if d["_id"] not in seen:
            seen.add(d["_id"])
            files["leagues"].append(league(d, alias))
    oids = [ObjectId(p) for p in player_ids if ObjectId.is_valid(p)]
    for d in c["players"].find({"_id": {"$in": oids}}):
        files["players"].append(pick(d, PUBLIC_PLAYER))

    for name, docs in files.items():
        (out / f"{name}.json").write_text(json_util.dumps(docs, indent=1), encoding="utf-8")
    leaks = scan_for_personal_data(out)
    if leaks:
        for f in out.glob("*.json"):
            f.unlink()
        sys.exit("EXPORT CANCELLED, files deleted: personal data pattern found: " + "; ".join(leaks))
    manifest = {"nights": [str(n) for n in nights], "exported_at": datetime.now().isoformat(timespec="seconds"),
                "counts": {k: len(v) for k, v in files.items()},
                "note": "aliased ids, no users collection, no email/name/birth date/token"}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(json.dumps(manifest["counts"], indent=1))
    print(f"Exported to {out.resolve()}")


FORBIDDEN = [
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "an email address"),
    (re.compile(r'"(email|password|fcm_token|token|birth_date|phone|refresh_token|hashed_password)"', re.I),
     "a personal or secret field name"),
    (re.compile(r"(eyJ[\w-]{10,}\.[\w-]{10,}\.|AIza[\w-]{20,}|ghp_[\w]{20,})"), "a token"),
]


def scan_for_personal_data(folder: Path) -> list[str]:
    found = []
    for f in sorted(folder.glob("*.json")):
        text = f.read_text(encoding="utf-8")
        for rx, label in FORBIDDEN:
            if rx.search(text):
                found.append(f"{f.name}: {label}")
    return found


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--suggest", action="store_true", help="list recent nights to pick from, then stop")
    ap.add_argument("--days", type=int, default=45)
    ap.add_argument("--night", action="append", help="YYYY-MM-DD, once or twice")
    ap.add_argument("--out", default=str(DEFAULT_OUT), help="must be ignored by git (default: scripts/dryrun/export)")
    args = ap.parse_args()
    if not args.suggest:
        if not args.night or len(args.night) > 3:
            sys.exit("give 1 to 3 --night YYYY-MM-DD (use --suggest to choose)")
        ensure_ignored_by_git(Path(args.out))        # before touching production at all
    c = connect()
    if args.suggest:
        return suggest(c, args.days)
    export(c, [date.fromisoformat(n) for n in args.night], Path(args.out))


if __name__ == "__main__":
    main()
