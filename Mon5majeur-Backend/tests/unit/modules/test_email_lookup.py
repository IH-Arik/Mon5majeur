"""QA 30/09 #8 #1: "Name@x.com" must find the account stored as "name@x.com"."""
from __future__ import annotations

import asyncio

from app.modules.users import repository as repo_mod


class _Expr:
    def __init__(self, value):
        self.value = value


class _Field:
    def __eq__(self, other):  # User.email == "x" builds the query value
        return _Expr(other)


def _stub(monkeypatch, stored: set[str]):
    calls = []

    class _User:
        email = _Field()

        @staticmethod
        async def find_one(query):
            calls.append(query)
            if isinstance(query, _Expr):
                return query.value if query.value in stored else None
            pattern = query["email"]["$regex"]
            import re

            return next((e for e in stored if re.match(pattern, e, re.I)), None)

    monkeypatch.setattr(repo_mod, "User", _User)
    return calls


def _lookup(email):
    repo = repo_mod.UserRepository.__new__(repo_mod.UserRepository)
    return asyncio.run(repo.get_by_email(email))


def test_capitalised_login_finds_the_lowercase_account(monkeypatch):
    _stub(monkeypatch, {"arik@gmail.com"})
    assert _lookup("Arik@gmail.com") == "arik@gmail.com"


def test_account_stored_with_capitals_is_found_from_lowercase(monkeypatch):
    _stub(monkeypatch, {"Arik@gmail.com"})
    assert _lookup("arik@gmail.com") == "Arik@gmail.com"


def test_exact_match_does_not_need_the_regex(monkeypatch):
    calls = _stub(monkeypatch, {"arik@gmail.com"})
    assert _lookup("arik@gmail.com") == "arik@gmail.com"
    assert len(calls) == 1


def test_regex_metacharacters_are_escaped(monkeypatch):
    _stub(monkeypatch, {"a.b@gmail.com"})
    assert _lookup("a+b@gmail.com") is None  # "+" must not act as a pattern
    assert _lookup("A.B@gmail.com") == "a.b@gmail.com"
