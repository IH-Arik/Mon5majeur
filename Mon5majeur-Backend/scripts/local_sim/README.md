# Local simulator: backend + MongoDB on your Mac, app on the iOS simulator / Android emulator

Everything stays on this Mac. The production server, its database, mail, push and
sports-feed services are never contacted: the guard (`_guard.py`) refuses to start
unless the database is local and named `m5m_local_*`, and no outside service is configured.

All paths are from `Mon5majeur-Backend/`.

## 1. One-time setup
```bash
/opt/homebrew/bin/python3 -m venv ~/.venvs/m5m-backend
~/.venvs/m5m-backend/bin/python -m pip install -r requirements.txt
```

## 2. Database (Docker, reachable only from this Mac on 127.0.0.1:27019)
```bash
docker compose -f scripts/local_sim/docker-compose.local.yml up -d
```

## 3. Test data
```bash
bash scripts/local_sim/run_script.sh make_scenarios.py --state open    # tonight: lineups still open
bash scripts/local_sim/run_script.sh make_scenarios.py --state live    # tonight: games in progress
```
It EMPTIES the local database first. It creates 6 accounts (`me`, `me2`, `r1`..`r4` @example.com,
password `Local-test-1`), the Global League, a private duel league ("Local Duel League", id 2), 120
players on 12 teams, and a night already published by the REAL close code (the Global archive and
the duel close), with substitutes: `me` = an absent starter replaced (with Chef Curry), `r1` = an
absent starter and no substitute, `r2` = a 0-minute starter replaced, `r3` = a substitute that did
not enter (and a 6th Man in the duel).

## 4. Backend
```bash
bash scripts/local_sim/run_backend.sh          # http://127.0.0.1:8000, Ctrl+C to stop
```
No `.env` is read. With `DEBUG=true` and no SMTP, **the OTP code of a sign-up is printed in this
terminal** (no e-mail is sent), so you can create a new account from the app. Google and Apple
sign-in are not used locally: use the seeded accounts or an e-mail sign-up.

## 5. Check the server before opening the app
```bash
~/.venvs/m5m-backend/bin/python scripts/local_sim/check_local.py --state open   # or --state live
```
Real HTTP calls on the real local database; prints PASS / FAIL (the `open` run saves lineups for
`me`: run make_scenarios.py again before repeating it).

## 6. App
iOS simulator (the Mac's 127.0.0.1 is the simulator's own 127.0.0.1):
```bash
cd ../mon5majeur_app-main
~/fvm/versions/3.38.4/bin/flutter run -d "iPhone 16 Pro" --dart-define=API_BASE_URL=http://127.0.0.1:8000
```
Android emulator (10.0.2.2 is the Mac as seen from the emulator):
```bash
~/fvm/versions/3.38.4/bin/flutter run -d <emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:8000
```
Without `--dart-define` the app uses production. A release build that does not point at
`https://api.mon5majeur.com` refuses to start. Usage statistics are switched off whenever the
address is not production. Plain HTTP is allowed to these local addresses in Android debug builds
only (`android/app/src/debug`); iOS needs no exception for the app's HTTP calls (checked on a
simulator).

## 7. Stop and clean up
```bash
# Ctrl+C in the backend terminal, then:
docker compose -f scripts/local_sim/docker-compose.local.yml down -v     # throws the database away
```
