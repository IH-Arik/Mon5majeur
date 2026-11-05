"""Alert when the player a user holds as SUBSTITUTE is OUT for tonight."""
from __future__ import annotations

import asyncio
from datetime import date
from types import SimpleNamespace

from app.modules.notifications.i18n import localize
from app.modules.notifications.service import NotificationService

NIGHT = date(2026, 10, 6)
P = "6" * 24                      # the player who is OUT


def doc(user, *, starters=(), sixth=None, substitute=None):
    return SimpleNamespace(
        user_id=user,
        selected_players=[{"id": i} for i in starters],
        sixth_man_player={"id": sixth} if sixth else None,
        substitute_player={"id": substitute} if substitute else None,
    )


def run(monkeypatch, docs):
    from app.modules.lineups import compat_model, model as lineup_model

    queries = []

    class Store:
        @staticmethod
        def find(query, *a, **k):
            queries.append(query)
            return SimpleNamespace(to_list=_async(docs))

    class NoSlots:
        player_id = nba_date = score_finalized = None

        @staticmethod
        def find(*a, **k):
            return SimpleNamespace(to_list=_async([]))

    monkeypatch.setattr(compat_model, "FlutterPlayerSelection", Store)
    monkeypatch.setattr(lineup_model, "LineupSlot", NoSlots)
    svc = NotificationService()
    sent = []

    async def capture(**kw):
        sent.append(kw)

    monkeypatch.setattr(svc, "send_push_to_user", capture)
    asyncio.run(svc.notify_player_out(player_id=P, player_name="Joel Embiid", reason="Ankle", nba_date=NIGHT))
    return sent, queries


def _async(value):
    async def to_list():
        return value

    return to_list


def test_the_search_includes_the_substitute(monkeypatch):
    _, queries = run(monkeypatch, [])
    clauses = queries[0]["$or"]
    assert {"substitute_player.id": {"$in": [P, P]}} in clauses


def test_a_substitute_holder_gets_the_dedicated_alert(monkeypatch):
    sent, _ = run(monkeypatch, [doc("u1", starters=["a", "b"], substitute=P)])
    assert len(sent) == 1
    assert sent[0]["title"] == "Your substitute Joel Embiid is OUT tonight"
    assert sent[0]["body"] == "Change him before tip-off."
    assert sent[0]["data"]["type"] == "player_out" and sent[0]["data"]["role"] == "substitute"
    assert sent[0]["notification_type"] == "player_out"        # same preference as the usual alert


def test_a_starter_holder_keeps_the_usual_alert(monkeypatch):
    sent, _ = run(monkeypatch, [doc("u1", starters=[P, "b"])])
    assert sent[0]["title"] == "Joel Embiid is OUT"
    assert sent[0]["body"] == "Reason: Ankle. Update your lineup before tip-off."
    assert "role" not in sent[0]["data"]


def test_a_sixth_man_holder_keeps_the_usual_alert(monkeypatch):
    sent, _ = run(monkeypatch, [doc("u1", starters=["a"], sixth=P)])
    assert sent[0]["title"] == "Joel Embiid is OUT"


def test_starter_in_one_league_substitute_in_another_is_one_usual_push(monkeypatch):
    sent, _ = run(monkeypatch, [doc("u1", substitute=P), doc("u1", starters=[P])])
    assert len(sent) == 1 and sent[0]["title"] == "Joel Embiid is OUT"


def test_substitute_in_three_leagues_is_one_push(monkeypatch):
    sent, _ = run(monkeypatch, [doc("u1", substitute=P)] * 3)
    assert len(sent) == 1


def test_each_user_gets_the_alert_that_fits(monkeypatch):
    sent, _ = run(monkeypatch, [doc("u1", starters=[P]), doc("u2", substitute=P)])
    by_user = {s["user_id"]: s["title"] for s in sent}
    assert by_user == {"u1": "Joel Embiid is OUT", "u2": "Your substitute Joel Embiid is OUT tonight"}


# ── French, through the same translation table as the other notifications ────

def test_french_text_of_the_substitute_alert():
    title, body = localize("Your substitute Joel Embiid is OUT tonight", "Change him before tip-off.", "fr")
    assert (title, body) == ("Ton remplaçant Joel Embiid est OUT ce soir", "Change-le avant le coup d'envoi.")


def test_english_stays_english():
    en = ("Your substitute Joel Embiid is OUT tonight", "Change him before tip-off.")
    assert localize(*en, "en") == en and localize(*en, None) == en


def test_the_usual_alert_translation_is_unchanged():
    assert localize("Joel Embiid is OUT", "Reason: Ankle. Update your lineup before tip-off.", "fr") == (
        "Joel Embiid est absent (OUT)",
        "Motif : Ankle. Mets à jour ta composition avant le coup d'envoi.",
    )
