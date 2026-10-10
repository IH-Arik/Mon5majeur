# Moving the database next to the server (QA #10, item 20)

Goal: the MongoDB Atlas database in the same AWS region as the API server
(Stockholm, `eu-north-1`), so every query stops making the round trip to
South Africa. **Only the database location changes**: no app or calculation
change. Do it on a day without games, in the daytime (Paris time), never close
to the 09:00 publication, and before October 14.

Whoever runs this needs the Atlas account (or Robin creates the cluster and
sends the connection string).

## 0. Measure before (keep the numbers)

```bash
API_BASE=https://api.mon5majeur.com TOKEN=<test account access token> \
  python scripts/measure_api.py
```
Also note, from the API logs, the time of confirming a lineup and of changing a
match day in Results. Save the output as "before".

## 1. Full backup of the current database (kept until everything is verified)

```bash
mongodump --uri="$OLD_URI" --db=mon5majeur_db --gzip --archive=backup-before-migration-$(date +%F).gz
```
Store the file off the server. Do not delete the old database.

## 2. Create the new cluster

Atlas -> Create -> **Flex**, provider **AWS**, region **eu-north-1 (Stockholm)**.
If Flex is not offered there, pick the closest European region that offers it
and tell the team which one. Create a database user and allow the server's IP
in Network Access. Copy the connection string (`NEW_URI`).

## 3. Copy the data

```bash
mongorestore --uri="$NEW_URI" --gzip --archive=backup-before-migration-<date>.gz
```
(Indexes are recreated by `mongorestore`; the app also declares them on start.)

## 4. Verify (read-only)

```bash
OLD_URI=... NEW_URI=... DB_NAME=mon5majeur_db python scripts/compare_databases.py
```
Every collection must show the same count (players, users, leagues, lineups,
results) and the script must end with "OK". Then open a past match day and the
weekly ranking against the new database and check the scores are identical.

## 5. Switch

On the AWS server, in `.env.prod`, replace the database connection string
(variable name as in `.env.example`), then:

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.override.prod.yml up -d --no-deps api scheduler
```
`--no-deps` on purpose: the compose file also lists a local `mongodb` service
that production does not use. Check the logs: no connection error, and the
scheduler lists its jobs.

## 6. Measure after

Run `scripts/measure_api.py` again and compare with "before". Target: each
action under one second.

## Rollback

Put the old connection string back in `.env.prod` and run the same `up -d
--no-deps api scheduler`. The old database was left intact, so nothing is lost
(data written after the switch stays only in the new one).
