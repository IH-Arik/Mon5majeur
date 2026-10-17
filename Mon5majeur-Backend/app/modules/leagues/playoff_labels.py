"""Round and game number of a play-off match (QA #13 item 2).

A play-off LeagueMatch is already tagged with its series and game number; the
round (semi_final / final) lives on the series. A regular-season match has
neither: both come back as None, so nothing changes for it.
"""
from __future__ import annotations

from beanie import PydanticObjectId

PlayoffLabel = tuple[str | None, int | None]


def label_of(match, round_by_series: dict) -> PlayoffLabel:
    """(round, game_number) of `match`, (None, None) outside the play-offs."""
    series_id = getattr(match, "playoff_series_id", None)
    if not getattr(match, "is_playoff", False) or series_id is None:
        return None, None
    return round_by_series.get(series_id), getattr(match, "playoff_game_number", None)


async def rounds_by_series(matches) -> dict[PydanticObjectId, str]:
    """Round of every series the given matches belong to (one query)."""
    from app.modules.leagues.playoff_model import PlayoffSeries

    ids = {m.playoff_series_id for m in matches if getattr(m, "playoff_series_id", None)}
    if not ids:
        return {}
    series = await PlayoffSeries.find({"_id": {"$in": list(ids)}}).to_list()
    return {s.id: s.round for s in series}


async def next_playoff_label(league_id, user_id) -> PlayoffLabel:
    """(round, game_number) of the player's next play-off match in the league:
    the first one not played yet (upcoming or live). (None, None) when the
    player has no match to come (qualified and waiting, eliminated, champion)."""
    from app.modules.leagues.model import LeagueMatch

    match = await LeagueMatch.find(
        {
            "league_id": league_id,
            "is_playoff": True,
            "status": {"$in": ["upcoming", "live"]},
            "$or": [{"home_user_id": user_id}, {"away_user_id": user_id}],
        }
    ).sort("match_day").first_or_none()
    if match is None:
        return None, None
    return label_of(match, await rounds_by_series([match]))
