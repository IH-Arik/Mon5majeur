#!/bin/bash
# Runs one of the simulator's Python scripts with the same guarded settings.
#   bash scripts/local_sim/run_script.sh make_scenarios.py --state open
set -u
source "$(dirname "$0")/_env.sh"
SCRIPT="$HERE/$1"; shift
exec "$PY" "$SCRIPT" "$@"
