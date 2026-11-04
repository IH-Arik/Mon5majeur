"""Safety rails shared by the restore and compare scripts: they only ever run
against a LOCAL database that the restore script created."""
from __future__ import annotations

import os
import sys
from pathlib import Path

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1", "dryrun-mongo"}   # dryrun-mongo: the Docker service
DB_PREFIX = "dryrun_"
MARKER = "_dryrun_marker"


def fail(message: str) -> None:
    print(f"\nREFUSED: {message}\nNothing was read or written.", file=sys.stderr)
    raise SystemExit(2)


def assert_local(uri: str, db_name: str) -> None:
    """The connection string must point ONLY at this machine (or the isolated
    Docker service) and the database name must be a dry-run one."""
    from pymongo.uri_parser import parse_uri

    if not uri or uri.startswith("mongodb+srv"):
        fail("the connection string is empty or a remote (mongodb+srv) cluster")
    try:
        hosts = [host for host, _port in parse_uri(uri)["nodelist"]]
    except Exception as exc:  # noqa: BLE001
        fail(f"cannot read the connection string ({exc.__class__.__name__})")
    remote = [h for h in hosts if h not in LOCAL_HOSTS]
    if remote or not hosts:
        fail(f"the connection string points outside this machine: {remote or 'no host'}")
    if not db_name.startswith(DB_PREFIX):
        fail(f"the database name must start with '{DB_PREFIX}' (got '{db_name}')")


def assert_marker(sync_db) -> None:
    """Only a database created by restore_local.py is accepted."""
    if sync_db[MARKER].find_one({"purpose": "dryrun"}) is None:
        fail("this database was not created by restore_local.py (no dry-run marker)")


def assert_no_env_files() -> None:
    """Inside the dry-run image (DRYRUN_IN_IMAGE=1) no `.env*` file may exist: a
    production secret baked into the image would defeat the isolation. Looks in
    the application folder, the working directory, the home folders and the
    root; set DRYRUN_SCAN_ROOTS (colon separated) to test elsewhere."""
    if os.environ.get("DRYRUN_IN_IMAGE") != "1" and "DRYRUN_SCAN_ROOTS" not in os.environ:
        return
    roots = os.environ.get("DRYRUN_SCAN_ROOTS", "/app:/tmp:/root:/home").split(":")
    found: list[str] = []
    for root in filter(None, roots):
        base = Path(root)
        if base.is_dir():
            found += [str(p) for p in base.rglob(".env*")]
    found += [str(p) for p in Path("/").glob(".env*")] if "DRYRUN_SCAN_ROOTS" not in os.environ else []
    if found:
        fail("a .env file is present in the dry-run image: " + ", ".join(found[:5]))


if __name__ == "__main__":        # python scripts/dryrun/_guard.py  -> image check
    assert_no_env_files()
    print("OK: no .env file in the image")
