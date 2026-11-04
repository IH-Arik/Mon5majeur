#!/bin/bash
# Starts the backend for the simulator / emulator on http://127.0.0.1:8000.
#   bash scripts/local_sim/run_backend.sh
# The guard (_guard.py) refuses to start unless the database is local and named
# m5m_local_*, with no mail, push, feed or error-tracking service configured.
set -u
source "$(dirname "$0")/_env.sh"
echo "Backend on http://127.0.0.1:8000  (Ctrl+C to stop). OTP codes appear below."
exec "$PY" -m uvicorn app.main:app --host 127.0.0.1 --port 8000
