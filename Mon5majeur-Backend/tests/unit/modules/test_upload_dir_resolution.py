"""
Regression test for the file-upload 500: UPLOAD_DIR was a bare relative
path ("uploads"), so where it actually resolved depended on the running
process's cwd. Every other endpoint worked fine because none of them touch
the filesystem, which is exactly why this was hard to spot from the outside
— the avatar-upload button silently 500'd on the deployed server while
`python -m` runs from the repo root masked the same bug locally.

Run standalone (the repo's tests/conftest.py is legacy SQLAlchemy and would
otherwise fail collection):
    ./.venv/Scripts/python.exe -m pytest tests/unit/modules/test_upload_dir_resolution.py --noconftest
"""
from __future__ import annotations

from pathlib import Path

from app.core.config import Settings


def _settings_with(upload_dir: str) -> Settings:
    # SECRET_KEY has no default (required), so a value has to be supplied
    # explicitly when constructing Settings outside of env-file loading.
    return Settings(SECRET_KEY="test-secret", UPLOAD_DIR=upload_dir)


def test_relative_upload_dir_is_anchored_to_the_project_root():
    s = _settings_with("uploads")
    resolved = Path(s.UPLOAD_DIR)

    assert resolved.is_absolute(), "a relative UPLOAD_DIR must not reach save_file() as-is"
    # Anchored at the actual codebase location, not the cwd Settings()
    # happened to be constructed from.
    assert resolved.name == "uploads"


def test_resolution_does_not_depend_on_the_working_directory(monkeypatch, tmp_path):
    """The bug: `Path("uploads")` means a different real directory depending
    on cwd. Prove the resolved path is identical regardless of cwd."""
    monkeypatch.chdir(tmp_path)
    from_elsewhere = Path(_settings_with("uploads").UPLOAD_DIR)

    monkeypatch.chdir(tmp_path.parent if tmp_path.parent.exists() else tmp_path)
    from_elsewhere_2 = Path(_settings_with("uploads").UPLOAD_DIR)

    assert from_elsewhere == from_elsewhere_2


def test_an_explicit_absolute_upload_dir_is_left_untouched(tmp_path):
    """An operator pointing UPLOAD_DIR at a mounted volume must get exactly
    that path back, not have it silently rewritten."""
    custom = str(tmp_path / "custom-uploads")
    s = _settings_with(custom)
    assert s.UPLOAD_DIR == custom
