import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "compare_databases",
    Path(__file__).resolve().parents[3] / "scripts" / "compare_databases.py",
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_identical_databases_have_no_difference():
    assert mod.diff_counts({"players": 609, "users": 29}, {"players": 609, "users": 29}) == []


def test_missing_and_different_collections_are_reported():
    out = mod.diff_counts({"players": 609, "users": 29}, {"players": 600, "leagues": 3})
    assert ("players", 609, 600) in out
    assert ("users", 29, 0) in out
    assert ("leagues", 0, 3) in out
