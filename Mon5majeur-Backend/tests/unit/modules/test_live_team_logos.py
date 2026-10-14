from types import SimpleNamespace

from app.modules.live_scores.schema import LiveMatchScore
from app.modules.live_scores.service import _logo_of


def test_logo_present():
    assert _logo_of(SimpleNamespace(team_logo="snake.png")) == "snake.png"


def test_empty_logo():
    assert _logo_of(SimpleNamespace(team_logo="")) == ""


def test_none_logo_is_an_empty_string():
    assert _logo_of(SimpleNamespace(team_logo=None)) == ""


def test_user_not_found_is_an_empty_string():
    assert _logo_of(None) == ""


def test_response_fields_default_to_empty_string_not_null():
    fields = LiveMatchScore.model_fields
    assert fields["home_team_logo"].default == ""
    assert fields["away_team_logo"].default == ""
