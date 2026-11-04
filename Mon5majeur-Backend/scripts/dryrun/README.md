# Dry-run of the substitute rule on real data (read-only on production)

Goal: recompute two past nights with the new code and compare with the scores that
were published (expected: zero difference), then try fictitious lineups with a
substitute. Nothing is ever written to production.

All paths below are from the backend folder (`Mon5majeur-Backend/`).

## 0. Check the sandbox WITHOUT any data

Do this first. It proves the sandbox cannot reach the internet or production, that the
safety guards refuse a remote connection string, and that the image holds no `.env`.
No export is needed.

```bash
C="docker compose -f scripts/dryrun/docker-compose.dryrun.yml"

$C build runner            # builds scripts/dryrun/Dockerfile.dryrun (not the production Dockerfile)
$C up -d dryrun-mongo
```
Expected: the build ends without "BUILD STOPPED"; `dryrun-mongo` is "Started".

```bash
# a) the runner has no route to the internet: no connection may open
$C run --rm runner python -c "import socket; socket.create_connection(('8.8.8.8', 53), timeout=5)"
$C run --rm runner python -c "import socket; socket.create_connection(('1.1.1.1', 443), timeout=5)"
```
Expected: both fail, e.g. `OSError: [Errno 101] Network is unreachable` or a timeout.
If either one connects: STOP, do not continue, tell me. (Name resolution may or may not
answer inside Docker's internal network; only an open connection matters.)

```bash
# b) the guards refuse a remote connection string and a production-looking name
$C run --rm -e MONGODB_URI='mongodb+srv://u:p@cluster0.example.mongodb.net/' runner \
    python /app/scripts/dryrun/restore_local.py /export
$C run --rm -e MONGODB_URI='mongodb://prod.example.com:27017' runner \
    python /app/scripts/dryrun/restore_local.py /export
$C run --rm -e MONGODB_DB_NAME=mon5majeur_db runner \
    python /app/scripts/dryrun/restore_local.py /export
```
Expected, three times: `REFUSED: ...` followed by `Nothing was read or written.`
(messages: "remote (mongodb+srv) cluster", "points outside this machine: ['prod.example.com']",
"the database name must start with 'dryrun_'"), and exit code 2.

```bash
# c) compare.py refuses a database that restore_local.py did not create
$C run --rm runner python /app/scripts/dryrun/compare.py
```
Expected: `REFUSED: this database was not created by restore_local.py (no dry-run marker)`.

```bash
# d) no .env file in the image
$C run --rm runner python /app/scripts/dryrun/_guard.py
$C run --rm runner sh -c 'find /app /tmp /root /home -name ".env*"; ls -A / | grep "^.env"; echo done'
```
Expected: `OK: no .env file in the image`, then only `done`.
The runner also runs this check by itself at every start and stops if a `.env*` file is
found (`restore_local.py` and `compare.py` call it first).

Then clean up the check: `$C down -v`.

## 1. Export (on your machine, read-only on production)

### 1a. Atlas: a temporary read-only user and a temporary IP

In Atlas, for the project that holds `mon5majeur_db`:

1. **Database Access -> Add New Database User.** Authentication: password (generate one).
   *Database User Privileges -> Specific Privileges -> Add Privilege:* role `read`,
   database `mon5majeur_db` (leave collection empty). Remove any other built-in role.
   Under *Temporary User*, choose "Delete after 6 hours".
2. **Network Access -> Add IP Address -> Add Current IP Address**, and tick *Temporary*
   ("Delete after 6 hours"). Do not use 0.0.0.0/0.
3. **Database -> Connect -> Drivers**: copy the connection string and put the user and
   password of step 1 in it. Do not paste it anywhere except the hidden prompt below.

### 1b. Run the export

The connection string is typed at a hidden prompt: it never appears on screen, in the
command line or in the shell history. (zsh, the macOS default. In bash:
`read -rsp 'Production URI (hidden): ' EXPORT_MONGODB_URI; echo`.)

```bash
read -rs "EXPORT_MONGODB_URI?Production URI (hidden): "; echo
export EXPORT_MONGODB_URI
export EXPORT_DB_NAME='mon5majeur_db'

# a) choose the nights: lineups, games final, lineups with an absent 10M+ starter.
#    Pick one normal night and one with a high number in the last column.
python scripts/dryrun/export_nights.py --suggest

# b) export the two nights into scripts/dryrun/export
#    (the script refuses any folder that git does not ignore)
python scripts/dryrun/export_nights.py --night 2026-10-21 --night 2026-10-30

unset EXPORT_MONGODB_URI EXPORT_DB_NAME      # production is no longer reachable from this shell
```

What the script does and does not do (header of `export_nights.py`): only
`find`/`distinct` on 7 collections; never reads `users`; whitelisted fields only; user and
league ids replaced by consistent aliases (random key, never stored); the output is
scanned for emails, tokens and secret field names, and the export is cancelled and deleted
if one is found.

### 1c. Remove the access right away

* Atlas -> **Database Access**: delete the temporary user (even if it would expire).
* Atlas -> **Network Access**: delete your IP entry.
* Close the terminal window (or `unset` as above) so no variable is left.

## 2. Load the export in the sandbox

```bash
C="docker compose -f scripts/dryrun/docker-compose.dryrun.yml"
$C up -d dryrun-mongo
$C run --rm runner python /app/scripts/dryrun/restore_local.py /export
```
The sandbox network is `internal: true`: the containers cannot reach the internet or
production, whatever the connection string says (checked in step 0). On top of that,
`restore_local.py` and `compare.py` refuse to run unless the connection string points at
`localhost`, `127.0.0.1` or the `dryrun-mongo` service, the database is named `dryrun_*`,
and (for `compare.py`) the database carries the marker written by the restore.
`compare.py` checks the value the application would REALLY use (environment, then any
`.env`), not just what you typed. The image is built from `Dockerfile.dryrun`: only the
application code and three scripts, never a `.env`.

## 3. Dry-run

```bash
$C run --rm runner python /app/scripts/dryrun/compare.py
```
* Part A: Global League archive and duel close recomputed with the current code (the real
  functions) vs the published scores. Exit code 1 if any difference; each one is listed
  with the user alias, the published value and the recomputed value.
* Part B: fictitious lineups with a substitute in their own fictitious league and users.
  Prints, per lineup, who played, who was replaced, and the totals with the substitute.

A difference in part A does not always come from the substitute: a stat correction made
after publication (`rescore_rounding.py`, `resync_night.py`) also shows up. Send me the list.

## 4. Clean up

```bash
$C down -v                          # drops the sandbox database
rm -rf scripts/dryrun/export        # the exported files
```
