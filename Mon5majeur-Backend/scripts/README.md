# Backend scripts

Run them **from the backend folder** (`Mon5majeur-Backend/`, where `.env` is),
for example:

```bash
./.venv/Scripts/python.exe scripts/promote_admin.py user@example.com
```

| Script | What it does |
|---|---|
| `promote_admin.py` | grant / revoke dashboard admin access for a user |
| `backfill_lineup_nba_date.py` | one-off: stamp old lineups with their NBA date (dry run by default, `--apply` writes) |
| `seed_all_data.py`, `seed_today_test_data.py`, `seed_demo_week_*.py`, `seed_public_league_*.py`, `expand_todays_players.py` | demo / test data for a LOCAL database. Never run on production |
| `compare_databases.py` | read-only count comparison of two databases (see `docs/ATLAS_MIGRATION.md`) |
| `measure_api.py` | times the slow API actions with a test account's token |
