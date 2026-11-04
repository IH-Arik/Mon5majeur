"""Safety rails of the dry-run kit (scripts/dryrun)."""
import importlib.util
import shutil
import subprocess
from pathlib import Path

import pytest

DRYRUN = Path(__file__).resolve().parents[2] / "scripts" / "dryrun"


def load(name):
    spec = importlib.util.spec_from_file_location(f"dryrun_{name}", DRYRUN / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


guard = load("_guard")


# ── connection string and database name ──────────────────────────────────────

@pytest.mark.parametrize("uri", [
    "mongodb://127.0.0.1:27017", "mongodb://localhost:27018", "mongodb://dryrun-mongo:27017",
    "mongodb://127.0.0.1:27017,localhost:27018",
])
def test_local_connection_strings_are_accepted(uri):
    guard.assert_local(uri, "dryrun_m5m")


@pytest.mark.parametrize("uri", [
    "", "mongodb+srv://u:p@cluster0.abc.mongodb.net/", "mongodb://prod.example.com:27017",
    "mongodb://127.0.0.1:27017,prod.example.com:27017", "mongodb://u:p@10.0.0.5:27017",
])
def test_anything_else_is_refused(uri):
    with pytest.raises(SystemExit) as e:
        guard.assert_local(uri, "dryrun_m5m")
    assert e.value.code == 2


@pytest.mark.parametrize("name", ["mon5majeur_db", "", "m5m_dryrun"])
def test_a_database_name_without_the_dryrun_prefix_is_refused(name):
    with pytest.raises(SystemExit):
        guard.assert_local("mongodb://127.0.0.1:27017", name)


# ── no .env file in the image ────────────────────────────────────────────────

def test_env_check_is_a_no_op_outside_the_image(monkeypatch):
    monkeypatch.delenv("DRYRUN_IN_IMAGE", raising=False)
    monkeypatch.delenv("DRYRUN_SCAN_ROOTS", raising=False)
    guard.assert_no_env_files()


def test_clean_folder_passes(monkeypatch, tmp_path):
    (tmp_path / "app.py").write_text("x")
    monkeypatch.setenv("DRYRUN_SCAN_ROOTS", str(tmp_path))
    guard.assert_no_env_files()


@pytest.mark.parametrize("name", [".env", ".env.prod", ".env.example", "sub/.env.local"])
def test_any_env_file_stops_the_runner(monkeypatch, tmp_path, name):
    f = tmp_path / name
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("MONGODB_URI=secret")
    monkeypatch.setenv("DRYRUN_SCAN_ROOTS", str(tmp_path))
    with pytest.raises(SystemExit) as e:
        guard.assert_no_env_files()
    assert e.value.code == 2


# ── the export only writes where git ignores ─────────────────────────────────

@pytest.mark.skipif(shutil.which("git") is None, reason="git not installed")
class TestExportFolder:
    export = load("export_nights")

    def test_default_folder_is_scripts_dryrun_export_and_is_ignored(self):
        assert self.export.DEFAULT_OUT == DRYRUN / "export"
        self.export.ensure_ignored_by_git(self.export.DEFAULT_OUT)

    def test_a_folder_git_does_not_ignore_is_refused(self):
        with pytest.raises(SystemExit, match="not ignored"):
            self.export.ensure_ignored_by_git(DRYRUN / "not_ignored")

    def test_a_folder_outside_the_repository_is_refused(self, tmp_path):
        with pytest.raises(SystemExit, match="REFUSED"):
            self.export.ensure_ignored_by_git(tmp_path / "out")


# ── the image: dedicated Dockerfile, nothing copied wholesale ────────────────

def test_dryrun_image_never_copies_the_backend_folder_wholesale():
    text = (DRYRUN / "Dockerfile.dryrun").read_text()
    copies = [l.split()[1:] for l in text.splitlines() if l.startswith("COPY")]
    assert ["."] not in [c[:1] for c in copies] and not any(c[0] in (".", "./") for c in copies)
    assert "find /app" in text and "BUILD STOPPED" in text           # the build fails on a .env
    assert "DRYRUN_IN_IMAGE=1" in text                               # the runner checks it too


def test_compose_uses_the_dedicated_dockerfile_and_an_internal_network():
    text = (DRYRUN / "docker-compose.dryrun.yml").read_text()
    assert "dockerfile: scripts/dryrun/Dockerfile.dryrun" in text
    assert "internal: true" in text


def test_restore_and_compare_run_the_image_check_first():
    for name in ("restore_local", "compare"):
        src = (DRYRUN / f"{name}.py").read_text()
        assert "assert_no_env_files()" in src
