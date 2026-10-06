"""QA #9 7.2: weeks count from the season's first game, not the ISO week."""
from datetime import date

from app.modules.leagues.global_score_service import season_week_number


def test_first_week_is_the_week_of_the_first_game():
    first_game = date(2026, 10, 4)          # a Sunday
    assert season_week_number(date(2026, 9, 28), first_game) == 1


def test_following_weeks_count_up_not_iso():
    first_game = date(2026, 10, 4)
    assert season_week_number(date(2026, 10, 5), first_game) == 2
    assert season_week_number(date(2026, 10, 12), first_game) == 3
    # ISO week of Oct 5 2026 is 41: no longer what is shown
    assert date(2026, 10, 5).isocalendar().week == 41


def test_never_below_one():
    assert season_week_number(date(2026, 9, 14), date(2026, 10, 4)) == 1
