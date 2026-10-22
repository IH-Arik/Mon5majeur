from datetime import date

from app.modules.players.nba_night import GLOBAL_LEAGUE_START_DATE, night_number_from

START = GLOBAL_LEAGUE_START_DATE  # 2026-10-20, regular-season opening night
SCHEDULE = [date(2026, 10, 20), date(2026, 10, 21), date(2026, 10, 22), date(2026, 10, 24)]


def test_opening_night_is_night_1():
    assert night_number_from(SCHEDULE, date(2026, 10, 20)) == 1


def test_10_21_is_night_2():
    assert night_number_from(SCHEDULE, date(2026, 10, 21)) == 2


def test_a_day_without_games_is_not_counted():
    # 10/23 has no game: 10/24 is the 4th night
    assert night_number_from(SCHEDULE, date(2026, 10, 24)) == 4


def test_before_the_season_there_is_no_number():
    assert night_number_from(SCHEDULE + [date(2026, 10, 5)], date(2026, 10, 5)) is None


def test_preseason_dates_do_not_count():
    assert night_number_from([date(2026, 10, 10)] + SCHEDULE, date(2026, 10, 21)) == 2
