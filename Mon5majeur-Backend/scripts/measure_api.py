"""Time the API actions of QA #10 20 step 1 / step 7 (before / after migration).

    API_BASE=https://api.mon5majeur.com TOKEN=<access token of a TEST account> \
        python scripts/measure_api.py

Each endpoint is called 5 times; min / median / max wall time is printed. Use a
test account's token (never a real user's). Only GET requests are sent.
"""
from __future__ import annotations

import os
import statistics
import sys
import time
import urllib.request

ACTIONS = {
    "open Data (all players)": "/api/players-today/?all=true&size=1000",
    "Global result, last night": "/api/global-leagues/result/?offset=0",
    "Global result, night before": "/api/global-leagues/result/?offset=1",
    "Global leaderboard (weekly)": "/api/global-leagues/leaderboard/?period=weekly&offset=0",
    "Global leaderboard (monthly)": "/api/global-leagues/leaderboard/?period=monthly&offset=0",
    "my leagues (home)": "/api/private-leagues/my_leagues/",
}


def timed(url: str, token: str) -> float:
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=60) as resp:
        resp.read()
    return time.perf_counter() - start


def main() -> int:
    base, token = os.environ.get("API_BASE"), os.environ.get("TOKEN")
    if not base or not token:
        print("Set API_BASE and TOKEN (a test account's access token).")
        return 2
    print(f"{'action':34} {'min':>7} {'median':>8} {'max':>7}   (seconds, 5 calls)")
    for label, path in ACTIONS.items():
        try:
            runs = [timed(base.rstrip("/") + path, token) for _ in range(5)]
        except Exception as exc:  # noqa: BLE001
            print(f"{label:34} FAILED: {exc}")
            continue
        print(f"{label:34} {min(runs):7.2f} {statistics.median(runs):8.2f} {max(runs):7.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
