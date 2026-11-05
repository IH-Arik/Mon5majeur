"""Smoke test of the substitute rule through the REAL local API (HTTP + MongoDB).

    python scripts/local_sim/check_local.py --state open     # after make_scenarios.py --state open
    python scripts/local_sim/check_local.py --state live     # after make_scenarios.py --state live

Talks only to http://127.0.0.1:8000 (the local backend). The 'open' run saves
lineups for the account me@example.com, so re-run make_scenarios.py before
running it again. Prints PASS / FAIL per check and exits 1 if any fails.
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:8000"
PASSWORD = "Local-test-1"
results: list[tuple[bool, str]] = []


def call(method, path, token=None, body=None):
    req = urllib.request.Request(
        BASE + path, method=method, data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw.decode(errors="replace")}


def check(ok: bool, label: str, detail: str = "") -> bool:
    results.append((ok, label))
    print(("  PASS  " if ok else "  FAIL  ") + label + (f"   [{detail}]" if detail and not ok else ""))
    return ok


def login(name):
    code, data = call("POST", "/api/auth/login/", body={"email": f"{name}@example.com", "password": PASSWORD})
    assert code == 200, f"login {name}: {code} {data}"
    return data["access"]


def by_team(scores, name):
    return next(s for s in scores if s["team_name"] == f"Local {name}")


def pick_lineup(token):
    """Five cheapest 12M+ players, one per position, and cheap (<=8M) substitutes."""
    code, data = call("GET", "/api/players-today/?size=200", token)
    players = data["results"]
    price = lambda p: float(str(p["price"]).replace("M", ""))
    starters = []
    for pos in ("PG", "SG", "SF", "PF", "C"):
        starters.append(min((p for p in players if p["position"] == pos and price(p) >= 12), key=price))
    ids = {p["id"] for p in starters}
    cheap = [p for p in players if price(p) <= 8 and p["id"] not in ids]
    dear = [p for p in players if price(p) > 10 and p["id"] not in ids]
    return starters, cheap, dear


def api(p):
    return {k: p[k] for k in ("id", "name", "position", "team", "team_id", "status", "price")}


def counted_sum_checks(page, where):
    """Every visible lineup of a duel page: the points of the players flagged
    "counted" (+3 with Chef Curry) are exactly its total."""
    for ps in page.get("player_scores", []):
        if ps.get("selection_hidden"):
            continue
        items = list(ps.get("selection", [])) + ([ps["substitute"]] if ps.get("substitute") else [])
        total = sum(i["score"] for i in items if i.get("counted"))
        if ps.get("bonus") == "chef_curry":
            total += 3
        check(total == ps["total_points"], f"{where}: {ps['team_name']} counted points = total",
              f"counted {total}, total {ps['total_points']}")


def published_night_checks():
    print("\nPublished night (computed by the REAL close code):")
    me = login("me")
    code, g = call("GET", "/api/global-leagues/result/?offset=0", me)
    check(code == 200 and g.get("available"), "Global: last published night is available", str(g)[:120])
    sub = g.get("substitution") or {}
    check(sub.get("status") == "entered", "Global (me): the substitute came in", str(sub))
    absent = [p for p in g.get("selection", []) if p.get("absent")]
    check(len(absent) == 1 and absent[0]["id"] == sub.get("replaced_id"),
          "Global (me): exactly the replaced starter is flagged absent", str(absent))
    check(len(g.get("selection", [])) == 5 and g.get("substitute") is not None,
          "Global (me): 5 starters listed + the substitute apart")

    code, d = call("GET", "/api/private-leagues/matches/2/1/", me)
    check(code == 200, "Duel day 1: result page answers", str(d)[:120])
    ps = d.get("player_scores", [])
    check(by_team(ps, "me")["substitution"]["status"] == "entered", "Duel (me, with Chef Curry): entered")
    check(by_team(ps, "r1")["substitute"] is None and by_team(ps, "r1")["substitution"] is None,
          "Duel (r1): no substitute -> nothing")
    check(by_team(ps, "r2")["substitution"]["status"] == "entered", "Duel (r2): 0-minute starter replaced")
    check(by_team(ps, "r3")["substitution"]["status"] == "not_entered", "Duel (r3): substitute did not enter")
    counted_sum_checks(d, "Duel day 1")
    me_score = by_team(ps, "me")
    check(me_score["total_points"] > 0 and not d.get("scores_hidden"), "Duel (me): points shown (premium)")


def open_checks():
    print("\nTonight, lineups open:")
    me = login("me")
    starters, cheap, dear = pick_lineup(me)
    sub = cheap[0]
    body = {"selected_players": [api(p) for p in starters]}

    code, r = call("POST", "/api/global-leagues/players-selection/",
                   me, {**body, "substitute_player": {**api(sub), "price": "1M"}})      # the app claims 1M
    check(code == 200, "Global save with a substitute is accepted", f"{code} {r}")
    stored = r.get("substitute_player") or {}
    check(stored.get("price") == f"{float(sub['price'].replace('M', '')):g}M",
          "price re-read from the database (the claimed 1M is ignored)", str(stored.get("price")))
    check((r.get("substitution") or {}).get("status") == "pending", "substitution is pending before tip-off", str(r.get("substitution")))

    code, r = call("POST", "/api/global-leagues/players-selection/", me, {**body, "substitute_player": api(dear[0])})
    check(code == 403 and "must be 10M or less" in json.dumps(r), "a substitute over 10M is refused", f"{code} {r}")
    code, r = call("POST", "/api/global-leagues/players-selection/", me, {**body, "substitute_player": api(starters[0])})
    check(code == 403 and "cannot also be a starter" in json.dumps(r), "a starter as substitute is refused", f"{code} {r}")
    code, r = call("GET", "/api/global-leagues/players-selection/", me)
    check((r.get("substitute_player") or {}).get("id") == sub["id"], "a refused save left the substitute untouched")

    code, r = call("POST", "/api/global-leagues/players-selection/", me, body)           # field absent: an older app
    check(code == 200 and (r.get("substitute_player") or {}).get("id") == sub["id"],
          "older app (field absent): the substitute is kept", f"{code}")
    code, r = call("POST", "/api/global-leagues/players-selection/", me, {**body, "substitute_player": None})
    check(code == 200 and r.get("substitute_player") is None, "explicit null removes the substitute", f"{code}")

    code, r = call("POST", "/api/private-leagues/2/2/players-selection/", me,
                   {**body, "luxury_tax": False, "chef_curry": False, "sixth_man_player": None,
                    "substitute_player": api(sub)})
    check(code == 200, "Duel save with a substitute is accepted", f"{code} {r}")
    code, r = call("GET", "/api/private-leagues/2/2/players-selection/", me)
    check((r.get("substitute_player") or {}).get("id") == sub["id"], "Duel: GET returns my substitute")

    print("\nHidden before the first tip-off:")
    code, d = call("GET", "/api/private-leagues/matches/2/2/", me)
    ps = d.get("player_scores", [])
    check(by_team(ps, "r1")["selection_hidden"] and by_team(ps, "r1")["substitute"] is None,
          "me looks at r1 (opponent): lineup and substitute hidden")
    check(by_team(ps, "me")["substitute"] is not None, "me looks at me: my substitute is shown")
    r1 = login("r1")
    code, d = call("GET", "/api/private-leagues/matches/2/2/", r1)
    ps = d.get("player_scores", [])
    check(by_team(ps, "me")["substitute"] is None, "r1 looks at me (opponent): my substitute is hidden")
    check(by_team(ps, "r1")["substitute"] is not None, "r1 looks at r1: his substitute is shown")


def live_checks():
    print("\nTonight, games in progress:")
    me, me2, r1 = login("me"), login("me2"), login("r1")
    code, g = call("GET", "/api/v1/live/global", me)
    check(code == 200 and (g.get("substitution") or {}).get("status") == "pending",
          "Live Global (me): pending, a starter's game is still on", f"{code} {g.get('substitution')}")
    # A starter whose own game is final with no minute is OUT at once (with or without a
    # substitute); nobody is REPLACED before every game of the lineup is final.
    out = [p for p in g.get("players", []) if p.get("is_absent")]
    check(len(out) == 1 and out[0]["minutes_played"] == 0 and out[0]["is_finalized"] is False,
          "Live Global (me): only the 0-minute starter whose game is final is OUT; nobody replaced yet", str(out)[:120])
    check(g.get("substitute") is not None and len(g.get("players", [])) == 5, "Live Global (me): substitute apart, 5 listed")
    code, g2 = call("GET", "/api/v1/live/global", me2)
    check((g2.get("substitution") or {}).get("status") == "entered", "Live Global (me2): every game final -> entered",
          str(g2.get("substitution")))
    check(sum(1 for p in g2.get("players", []) if p.get("is_absent")) == 1, "Live Global (me2): the replaced starter is greyed")

    code, d = call("GET", "/api/private-leagues/matches/2/2/", me)
    match_id = next(p["match_object_id"] for p in d["pairs"] if p["player_a_name"] == "Local me")
    code, live = call("GET", f"/api/v1/live/match/{match_id}", me)
    check(code == 200 and (live.get("home_substitution") or {}).get("status") == "pending",
          "Live duel (me): pending", f"{code} {live.get('home_substitution')}")
    check(live.get("away_substitute") is not None, "Live duel: the opponent's substitute is visible once games started")
    code, d1 = call("GET", "/api/private-leagues/matches/2/2/", r1)
    counted_sum_checks(d1, "Duel day 2 (live night, r1's view)")
    counted_sum_checks(d, "Duel day 2 (live night, my view)")
    check(by_team(d1["player_scores"], "me")["substitution"]["status"] == "pending",
          "Result page (r1 looks at me): pending, not replaced yet")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--state", choices=["open", "live"], required=True)
    args = ap.parse_args()
    code, health = call("GET", "/health")
    if code != 200:
        sys.exit("The local backend does not answer on http://127.0.0.1:8000 (run_backend.sh).")
    published_night_checks()
    open_checks() if args.state == "open" else live_checks()
    failed = [label for ok, label in results if not ok]
    print(f"\n{len(results) - len(failed)} PASS, {len(failed)} FAIL")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
