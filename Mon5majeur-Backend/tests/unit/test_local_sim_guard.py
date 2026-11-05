"""Safety rails of the local simulator (scripts/local_sim)."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace

import pytest

SIM = Path(__file__).resolve().parents[2] / "scripts" / "local_sim"
spec = importlib.util.spec_from_file_location("local_sim_guard", SIM / "_guard.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def settings(**kw):
    base = dict(MONGODB_URI="mongodb://127.0.0.1:27019", MONGODB_DB_NAME="m5m_local_sim",
                ENVIRONMENT="development", SMTP_HOST="", FCM_CREDENTIALS_PATH="",
                GOALSERVE_API_KEY="", SENTRY_DSN="", ENABLE_SCHEDULER=False)
    base.update(kw)
    return SimpleNamespace(**base)


def test_the_expected_local_setup_is_accepted():
    guard.check_settings(settings())
    guard.check_settings(settings(MONGODB_URI="mongodb://localhost:27019"))


@pytest.mark.parametrize("kw", [
    dict(MONGODB_URI=""),
    dict(MONGODB_URI="mongodb+srv://u:p@cluster0.abc.mongodb.net/"),
    dict(MONGODB_URI="mongodb://prod.example.com:27017"),
    dict(MONGODB_URI="mongodb://127.0.0.1:27019,prod.example.com:27017"),
    dict(MONGODB_DB_NAME="mon5majeur_db"),
    dict(MONGODB_DB_NAME="local_m5m"),
    dict(ENVIRONMENT="production"),
    dict(SMTP_HOST="smtp.example.com"),
    dict(FCM_CREDENTIALS_PATH="/secrets/firebase.json"),
    dict(GOALSERVE_API_KEY="abc"),
    dict(SENTRY_DSN="https://x@sentry.io/1"),
    dict(ENABLE_SCHEDULER=True),
])
def test_anything_else_is_refused(kw):
    with pytest.raises(SystemExit) as e:
        guard.check_settings(settings(**kw))
    assert e.value.code == 2


def test_the_launchers_set_everything_themselves():
    env = (SIM / "_env.sh").read_text()
    assert 'ENABLE_SCHEDULER="false"' in env and "unset SMTP_HOST FCM_CREDENTIALS_PATH" in env
    assert "mktemp -d" in env                      # empty working folder: no .env can be read
    assert "127.0.0.1" in env and "mongodb+srv" not in env
    assert "check_settings(get_settings())" in env  # the guard runs before anything starts
    compose = (SIM / "docker-compose.local.yml").read_text()
    assert '"127.0.0.1:27019:27017"' in compose     # the database is not reachable from the network
