# Sourced by run_backend.sh and run_script.sh: the ONLY place the simulator's settings live.
# Set in this shell only; no .env file is read (the process starts from an empty folder).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$(cd "$HERE/../.." && pwd)"
PY="${M5M_BACKEND_PYTHON:-$HOME/.venvs/m5m-backend/bin/python}"
[ -x "$PY" ] || { echo "Python environment not found: $PY (see scripts/local_sim/README.md, step 1)"; exit 1; }

export MONGODB_URI="${M5M_LOCAL_URI:-mongodb://127.0.0.1:27019}"
export MONGODB_DB_NAME="${M5M_LOCAL_DB:-m5m_local_sim}"
export SECRET_KEY="local-simulator-not-a-secret-0123456789abcdef"
export ENVIRONMENT="development"
export DEBUG="true"                 # with no SMTP: the OTP code is written in the backend's terminal
export ENABLE_SCHEDULER="false"
export PYTHONPATH="$BACKEND"
export PYTHONDONTWRITEBYTECODE=1
unset SMTP_HOST FCM_CREDENTIALS_PATH GOALSERVE_API_KEY SENTRY_DSN

WORK="$(mktemp -d)"                 # empty working folder: no .env can be found from here
cd "$WORK" || exit 1
trap 'rm -rf "$WORK"' EXIT

"$PY" - <<PYEOF || exit 2
import sys
sys.path.insert(0, "$HERE")
from app.core.config import get_settings
from _guard import check_settings
check_settings(get_settings())
print("guard OK: local database", get_settings().MONGODB_DB_NAME, "- no outside service configured")
PYEOF
