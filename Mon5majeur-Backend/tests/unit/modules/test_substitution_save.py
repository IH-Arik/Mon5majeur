"""Saving a lineup with a substitute (duels and Global League).

Price read from the database (10M max), same checks as a starter, never a
starter or the 6th Man, outside the budget, and untouchable once locked.
"""
from __future__ import annotations

import asyncio
import re
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from beanie import PydanticObjectId

from app.exceptions.errors import ForbiddenException
from app.modules.leagues import global_router as gr
from app.modules.leagues import selection_service as ss
from app.modules.leagues.schema import PlayersSelectionRequest
from app.modules.leagues.substitution_save import prepare_substitute

NIGHT = date(2026, 10, 20)
LAKERS, CELTICS, KNICKS = "Los Angeles Lakers", "Boston Celtics", "New York Knicks"


def oid(n: int) -> str:
    return f"{n:024x}"


def starter(n: int, price: int = 20) -> dict:
    return {"id": oid(n), "name": f"S{n}", "position": "PG", "price": f"{price}M"}


TEAM = [starter(n) for n in range(1, 6)]            # 5 x 20M = the whole 100M budget
SIXTH = {"id": oid(77), "name": "Sixth", "position": "SF", "price": "6M"}


def sub_req(n: int = 99, price: str = "1M") -> dict:
    """What the app sends: a cheap-looking price that must be ignored."""
    return {"id": oid(n), "name": f"Sub{n}", "position": "SG", "price": price}


@pytest.fixture
def db(monkeypatch):
    """Players and tonight's games, as the model module sees them."""
    import app.modules.players.model as pm

    players = {
        99: SimpleNamespace(id=PydanticObjectId(oid(99)), full_name="Sub Ninety-Nine",
                            team_name=LAKERS, team_goalserve_id="LAL", is_out=False, daily_price=7.0),
        98: SimpleNamespace(id=PydanticObjectId(oid(98)), full_name="Ten Million",
                            team_name=CELTICS, team_goalserve_id="BOS", is_out=False, daily_price=10.0),
        97: SimpleNamespace(id=PydanticObjectId(oid(97)), full_name="Too Dear",
                            team_name=LAKERS, team_goalserve_id="LAL", is_out=False, daily_price=12.0),
        96: SimpleNamespace(id=PydanticObjectId(oid(96)), full_name="Rests Tonight",
                            team_name=KNICKS, team_goalserve_id="NYK", is_out=False, daily_price=5.0),
        95: SimpleNamespace(id=PydanticObjectId(oid(95)), full_name="Hurt Guy",
                            team_name=LAKERS, team_goalserve_id="LAL", is_out=True, daily_price=5.0),
    }
    games = [SimpleNamespace(home_team_name=LAKERS, away_team_name=CELTICS,
                             home_team_id="LAL", away_team_id="BOS", nba_date=NIGHT, status="scheduled")]

    class Player:
        @staticmethod
        async def get(pid):
            return players.get(int(str(pid), 16))

    class NBAGame:
        nba_date = object()

        @staticmethod
        def find(*_):
            async def to_list():
                return games

            return SimpleNamespace(to_list=to_list)

    monkeypatch.setattr(pm, "Player", Player)
    monkeypatch.setattr(pm, "NBAGame", NBAGame)
    return players


def prep(**kw):
    base = dict(provided=True, requested=None, existing=None, existing_set_at=None,
                starters=TEAM, sixth_man=None, nba_date=NIGHT)
    base.update(kw)
    return asyncio.run(prepare_substitute(**base))


# ── the checks ───────────────────────────────────────────────────────────────

def test_price_is_read_from_the_database_not_the_request(db):
    stored, set_at = prep(requested=sub_req(99, price="1M"))     # the app claims 1M, db says 7M
    assert stored["price"] == "7M" and stored["id"] == oid(99) and stored["name"] == "Sub99"
    assert set_at is not None


def test_ten_million_exactly_is_accepted(db):
    stored, _ = prep(requested=sub_req(98))
    assert stored["price"] == "10M"


def test_over_ten_million_is_refused_whatever_the_request_says(db):
    with pytest.raises(ForbiddenException, match=re.escape("The substitute costs 12M — must be 10M or less")):
        prep(requested=sub_req(97, price="3M"))


def test_a_starter_cannot_be_the_substitute(db):
    with pytest.raises(ForbiddenException, match="The substitute cannot also be a starter"):
        prep(requested=starter(3))


def test_the_sixth_man_cannot_be_the_substitute(db):
    with pytest.raises(ForbiddenException, match=re.escape("The substitute cannot also be the 6th Man")):
        prep(requested=sub_req(99), sixth_man={"id": oid(99)})


def test_a_player_who_does_not_play_tonight_is_refused(db):
    with pytest.raises(ForbiddenException, match="Rests Tonight does not play tonight"):
        prep(requested=sub_req(96))


def test_an_out_player_is_refused(db):
    with pytest.raises(ForbiddenException, match="Hurt Guy is OUT and cannot be selected"):
        prep(requested=sub_req(95))


def test_unknown_player_and_missing_id_are_refused(db):
    with pytest.raises(ForbiddenException, match="not found"):
        prep(requested=sub_req(12345))
    with pytest.raises(ForbiddenException, match="must have an id"):
        prep(requested={"name": "x"})


def test_no_game_scheduled_skips_the_night_checks_like_for_starters(db):
    assert prep(requested=sub_req(96), nba_date=None)[0]["id"] == oid(96)      # not playing: not checked
    with pytest.raises(ForbiddenException, match="must be 10M or less"):       # the price still is
        prep(requested=sub_req(97), nba_date=None)


def test_messages_reuse_the_patterns_the_app_already_translates(db):
    # copied from lib/core/utils/server_message.dart
    plays = re.compile(r"^(.+) does not play tonight$")
    out = re.compile(r"^(?:Player )?(.+) is OUT and cannot be selected$")
    with pytest.raises(ForbiddenException) as e1:
        prep(requested=sub_req(96))
    with pytest.raises(ForbiddenException) as e2:
        prep(requested=sub_req(95))
    assert plays.match(str(e1.value)) and out.match(str(e2.value))


# ── field sent / null / absent (older apps) ──────────────────────────────────

EXISTING = {"id": oid(99), "name": "Sub99", "position": "SG", "price": "7M"}


def test_null_removes_the_substitute(db):
    assert prep(requested=None, existing=EXISTING) == (None, None)


def test_absent_field_keeps_the_existing_substitute(db):
    kept, set_at = prep(provided=False, existing=EXISTING, existing_set_at="then")
    assert kept == EXISTING and set_at == "then"


def test_absent_field_and_none_before_stays_none(db):
    assert prep(provided=False, existing=None) == (None, None)


def test_old_app_made_him_a_starter_he_is_dropped_not_refused(db):
    team = TEAM[:4] + [EXISTING]
    assert prep(provided=False, existing=EXISTING, starters=team) == (None, None)


def test_old_app_made_him_the_sixth_man_he_is_dropped_not_refused(db):
    assert prep(provided=False, existing=EXISTING, sixth_man={"id": oid(99)}) == (None, None)


# ── the duel save, end to end ────────────────────────────────────────────────

LEAGUE = SimpleNamespace(id="L", auto_id=7, budget=100, type="public", current_match_day=3)
USER = SimpleNamespace(id="U")


def duel_save(db, *, existing=None, fail_bonus=False, locked=False, team=None, **extra):
    leagues = MagicMock(); leagues.find_one = AsyncMock(return_value=LEAGUE); leagues.auto_id = MagicMock()
    memberships = MagicMock(); memberships.find_one = AsyncMock(return_value=object())
    matches = MagicMock()
    matches.find_one = AsyncMock(return_value=SimpleNamespace(nba_date=NIGHT, is_playoff=False, auto_id=11))
    sels = MagicMock(); sels.find_one = AsyncMock(return_value=existing)
    created = SimpleNamespace(delete=AsyncMock())
    sels.return_value.insert = AsyncMock(return_value=created)
    bonus = MagicMock(); bonus.return_value.can_use = AsyncMock(return_value=True)
    sync = AsyncMock(side_effect=ForbiddenException("x") if fail_bonus else None)
    ensure = AsyncMock(side_effect=ForbiddenException("Lineup locked until the 09:00 publication")) \
        if locked else AsyncMock(return_value=SimpleNamespace(lock_in_seconds=600))
    with patch.object(ss, "League", leagues), \
            patch("app.modules.leagues.model.LeagueMembership", memberships), \
            patch.object(ss, "LeagueMatch", matches), \
            patch.object(ss, "FlutterPlayerSelection", sels), \
            patch("app.modules.bonuses.service.BonusService", bonus), \
            patch.object(ss, "_sync_bonus", sync), \
            patch.object(ss, "_validate_selection", AsyncMock()), \
            patch("app.modules.leagues.lineup_state.ensure_open", ensure):
        out = asyncio.run(ss.save_player_selection(7, 3, team or TEAM, USER, **extra))
    return out, sels


def saved_doc(existing=None):
    return SimpleNamespace(
        selected_players=TEAM, submitted_at=None, nba_date=NIGHT, luxury_tax=False, chef_curry=False,
        sixth_man_player=None, substitute_player=existing, substitute_set_at="then" if existing else None,
        save=AsyncMock(),
    )


def test_duel_save_stores_the_substitute_with_the_db_price_and_a_date(db):
    _, sels = duel_save(db, substitute_player=sub_req(99), substitute_provided=True)
    kw = sels.call_args.kwargs
    assert kw["substitute_player"]["price"] == "7M" and kw["substitute_set_at"] is not None


def test_the_substitute_is_outside_the_budget(db):
    # five starters use the WHOLE 100M; a 10M substitute on top must not matter
    out, sels = duel_save(db, substitute_player=sub_req(98), substitute_provided=True)
    assert out["current_balance"] == 0
    assert sels.call_args.kwargs["substitute_player"]["price"] == "10M"
    # and the starters' own budget is still enforced
    too_dear = [starter(n, 21) for n in range(1, 6)]
    with pytest.raises(ForbiddenException, match="exceeds budget"):
        duel_save(db, team=too_dear, substitute_player=sub_req(98), substitute_provided=True)


def test_duel_save_without_the_field_keeps_the_substitute(db):
    doc = saved_doc(EXISTING)
    duel_save(db, existing=doc)                                    # an older app: field absent
    assert doc.substitute_player == EXISTING and doc.substitute_set_at == "then"


def test_duel_save_with_null_removes_the_substitute(db):
    doc = saved_doc(EXISTING)
    duel_save(db, existing=doc, substitute_player=None, substitute_provided=True)
    assert doc.substitute_player is None and doc.substitute_set_at is None


def test_duel_save_old_app_makes_him_sixth_man_he_is_dropped(db):
    doc = saved_doc(EXISTING)
    duel_save(db, existing=doc, sixth_man_player={"id": oid(99), "price": "6M"})
    assert doc.substitute_player is None


def test_duel_save_refuses_a_substitute_who_is_also_the_sixth_man(db):
    with pytest.raises(ForbiddenException, match="cannot also be the 6th Man"):
        duel_save(db, sixth_man_player={"id": oid(99), "price": "6M"},
                  substitute_player=sub_req(99), substitute_provided=True)


@pytest.mark.parametrize("change", ["add", "change", "remove"])
def test_locked_lineup_the_substitute_cannot_be_added_changed_or_removed(db, change):
    doc = saved_doc(EXISTING if change != "add" else None)
    request = {"add": sub_req(99), "change": sub_req(98), "remove": None}[change]
    with pytest.raises(ForbiddenException, match="locked"):
        duel_save(db, existing=doc, locked=True, substitute_player=request, substitute_provided=True)
    doc.save.assert_not_awaited()
    assert doc.substitute_player == (EXISTING if change != "add" else None)


def test_a_failed_bonus_debit_puts_the_previous_substitute_back(db):
    doc = saved_doc(EXISTING)
    with pytest.raises(ForbiddenException):
        duel_save(db, existing=doc, fail_bonus=True, substitute_player=sub_req(98), substitute_provided=True)
    assert doc.substitute_player == EXISTING and doc.substitute_set_at == "then"


# ── the Global League save ───────────────────────────────────────────────────

def global_save(db, payload, doc=None, locked=False):
    league = SimpleNamespace(id="L", auto_id=1, current_match_day=1)
    built = {}

    async def build(league_, selected, user_id, substitute=None):
        built["substitute"] = substitute
        return "response"

    async def league_fn():
        return league

    async def night():
        return NIGHT

    async def tonight(*_):
        return doc

    sels = MagicMock(); sels.find_one = AsyncMock(return_value=None)
    sels.side_effect = lambda **kw: SimpleNamespace(**kw, insert=AsyncMock())
    games = MagicMock(); games.find.return_value.count = AsyncMock(return_value=1)
    ensure = AsyncMock(side_effect=ForbiddenException("Lineup locked until the 09:00 publication")) \
        if locked else AsyncMock()
    with patch.object(gr, "_get_global_league", league_fn), \
            patch.object(gr, "_composing_night", night), \
            patch.object(gr, "_tonight_selection", tonight), \
            patch.object(gr, "FlutterPlayerSelection", sels), \
            patch.object(gr, "NBAGame", games), \
            patch.object(gr, "_build_response", build), \
            patch.object(ss, "_validate_selection", AsyncMock()), \
            patch("app.modules.leagues.lineup_state.ensure_open", ensure):
        asyncio.run(gr.post_global_selection(payload, USER))
    return built, sels


def req(**fields):
    return PlayersSelectionRequest(selected_players=TEAM, **fields)


def test_global_save_accepts_a_substitute_unlike_a_bonus(db):
    built, sels = global_save(db, req(substitute_player=sub_req(99)))
    assert sels.call_args.kwargs["substitute_player"]["price"] == "7M"
    assert built["substitute"]["price"] == "7M"


def test_global_save_still_refuses_bonuses(db):
    with pytest.raises(ForbiddenException, match="Bonuses are not available"):
        global_save(db, req(chef_curry=True, substitute_player=sub_req(99)))


def test_global_save_absent_keeps_null_removes_and_locked_refuses(db):
    doc = saved_doc(EXISTING)
    global_save(db, req(), doc=doc)
    assert doc.substitute_player == EXISTING                       # older app
    global_save(db, req(substitute_player=None), doc=doc)
    assert doc.substitute_player is None                           # explicit null
    doc2 = saved_doc(EXISTING)
    with pytest.raises(ForbiddenException, match="locked"):
        global_save(db, req(substitute_player=sub_req(98)), doc=doc2, locked=True)
    assert doc2.substitute_player == EXISTING


def test_global_save_refuses_a_substitute_who_is_a_starter(db):
    with pytest.raises(ForbiddenException, match="cannot also be a starter"):
        global_save(db, req(substitute_player=starter(2)))


# ── an opponent's substitute is hidden until the first tip-off ───────────────

def global_day_view(started: bool):
    """get_global_match_result for the viewer 'ME', with two other members; the
    spy records what each member's substitute visibility was."""
    ME, OTHER = PydanticObjectId(oid(0xB1)), PydanticObjectId(oid(0xB2))
    seen = {}

    async def league_fn():
        return SimpleNamespace(id="L", auto_id=1, name="Global")

    async def matchday(*_):
        return NIGHT, True

    async def today():
        return NIGHT

    async def status(*_):
        return "scheduled"

    async def total(*_):
        return 0.0

    async def items(user_id, *_a, include_selection, show_substitute):
        seen[user_id] = show_substitute
        return [], None, None

    async def locked():
        return started

    def finder(rows):
        def find(*_):
            async def to_list():
                return rows

            return SimpleNamespace(to_list=to_list)

        return find

    members = [SimpleNamespace(user_id=ME), SimpleNamespace(user_id=OTHER)]
    users = [SimpleNamespace(id=ME, auto_id=1, team_name="Me", email="m@x", full_name="Me"),
             SimpleNamespace(id=OTHER, auto_id=2, team_name="Other", email="o@x", full_name="Other")]

    class Members:
        league_id = _F = object()
        find = staticmethod(finder(members))

    class Users:
        find = staticmethod(finder(users))

    with patch.object(gr, "_get_global_league", league_fn), \
            patch.object(gr, "_global_matchday_date", matchday), \
            patch.object(gr, "_nba_today", today), \
            patch.object(gr, "_global_status_for_date", status), \
            patch.object(gr, "_global_total_for_user", total), \
            patch.object(gr, "_global_selection_items", items), \
            patch.object(gr, "_is_locked_today", locked), \
            patch.object(gr, "LeagueMembership", Members), \
            patch.object(gr, "User", Users), \
            patch.object(gr, "global_night_number", AsyncMock(return_value=1)):
        asyncio.run(gr.get_global_match_result(1, SimpleNamespace(id=ME)))
    return seen, ME, OTHER


def test_global_day_view_hides_the_others_substitute_before_tip_off():
    seen, me, other = global_day_view(started=False)
    assert seen[me] is True and seen[other] is False


def test_global_day_view_shows_everyones_substitute_after_tip_off():
    seen, me, other = global_day_view(started=True)
    assert seen[me] is True and seen[other] is True
