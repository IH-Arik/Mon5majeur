"""Arik QA item 4: saving a duel team answered 500 although it was saved."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def test_the_backend_has_no_undefined_name():
    # The 500 came from a name removed from save_player_selection but still
    # returned at its end (NameError after the write). ruff F821 catches it.
    r = subprocess.run(
        [sys.executable, "-m", "ruff", "check", "app", "--select", "F821",
         "--no-cache", "--output-format", "concise"],
        cwd=ROOT, capture_output=True, text=True,
    )
    real = [
        line for line in r.stdout.splitlines()
        if "F821" in line and "Response`" not in line   # string type hints only
    ]
    assert real == []
