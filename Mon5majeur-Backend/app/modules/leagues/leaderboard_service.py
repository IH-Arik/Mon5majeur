"""
Leaderboard service — Regular Season standings + Playoff bracket.

Standings:  reads LeagueMembership records, ranks by wins → differential → FP → head-to-head.
Playoffs:   reads PlayoffSeries documents for the given league.
"""
from app.exceptions.errors import NotFoundException
from app.modules.leagues.model import League, LeagueMembership
from app.modules.leagues.playoff_model import PlayoffSeries
from app.modules.leagues.schema import (
    PlayoffBracketResponse,
    PlayoffGameResponse,
    PlayoffRoundResponse,
    PlayoffSeriesResponse,
    StandingsEntry,
    StandingsResponse,
)
from app.modules.users.model import User

_ROUND_LABELS: dict[str, str] = {
    "quarter_final": "Quarter Finals",
    "semi_final":    "Semi Finals",
    "final":         "Final",
}

_ROUND_ORDER: list[str] = ["quarter_final", "semi_final", "final"]


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _league_or_404(league_auto_id: int) -> League:
    league = await League.find_one(League.auto_id == league_auto_id)
    if not league:
        raise NotFoundException(f"League {league_auto_id} not found")
    return league


async def _user_map(user_ids: list) -> dict:
    """Fetch User objects by ObjectId list → {ObjectId: User}."""
    users = await User.find({"_id": {"$in": user_ids}}).to_list()
    return {u.id: u for u in users}


def _display_name(user: User | None) -> str:
    if user is None:
        return "Unknown"
    return user.team_name or (user.email.split("@")[0] if user.email else "Unknown")


# ── Standings ─────────────────────────────────────────────────────────────────

async def get_standings(league_auto_id: int) -> StandingsResponse:
    league = await _league_or_404(league_auto_id)

    memberships = await LeagueMembership.find(
        LeagueMembership.league_id == league.id
    ).to_list()

    if not memberships:
        return StandingsResponse(
            league_id=league_auto_id,
            league_name=league.name,
            playoff_spots=4,
            teams=[],
        )

    user_ids = [m.user_id for m in memberships]
    umap = await _user_map(user_ids)

    def _sort_key(m: LeagueMembership):
        diff = m.points_for - m.points_against
        return (-m.wins, -diff, -m.points_for)

    sorted_ms = sorted(memberships, key=_sort_key)
    playoff_spots = min(4, len(sorted_ms))

    teams: list[StandingsEntry] = []
    for rank, m in enumerate(sorted_ms, start=1):
        user = umap.get(m.user_id)
        diff = m.points_for - m.points_against
        teams.append(StandingsEntry(
            rank=rank,
            team_id=user.auto_id or 0 if user else 0,
            team_name=_display_name(user),
            wins=m.wins,
            losses=m.losses,
            points_for=round(m.points_for, 1),
            points_against=round(m.points_against, 1),
            differential=round(diff, 1),
            is_playoff_spot=(rank <= playoff_spots),
        ))

    return StandingsResponse(
        league_id=league_auto_id,
        league_name=league.name,
        playoff_spots=playoff_spots,
        teams=teams,
    )


# ── Playoff Bracket ───────────────────────────────────────────────────────────

async def get_playoff_bracket(league_auto_id: int) -> PlayoffBracketResponse:
    league = await _league_or_404(league_auto_id)

    all_series = await PlayoffSeries.find(
        PlayoffSeries.league_id == league.id
    ).to_list()

    # Collect all participant user IDs
    all_user_ids = list({
        uid
        for s in all_series
        for uid in (s.team_a_id, s.team_b_id)
        if uid is not None
    })
    umap = await _user_map(all_user_ids)

    def _series_to_response(s: PlayoffSeries) -> PlayoffSeriesResponse:
        user_a = umap.get(s.team_a_id)
        user_b = umap.get(s.team_b_id)
        winner = umap.get(s.winner_id) if s.winner_id else None

        games = [
            PlayoffGameResponse(
                game_number=g.game_number,
                score_a=int(g.score_a),
                score_b=int(g.score_b),
                winner_team=_display_name(
                    user_a if g.winner_id == s.team_a_id else user_b
                ) if g.winner_id else "",
            )
            for g in s.games
        ]

        return PlayoffSeriesResponse(
            series_index=s.series_index,
            round=s.round,
            team_a_id=user_a.auto_id or 0 if user_a else 0,
            team_a_name=_display_name(user_a),
            team_b_id=user_b.auto_id or 0 if user_b else 0,
            team_b_name=_display_name(user_b),
            wins_a=s.wins_a,
            wins_b=s.wins_b,
            games=games,
            winner_id=winner.auto_id if winner else None,
            winner_name=_display_name(winner) if winner else None,
            is_complete=s.is_complete,
        )

    rounds: list[PlayoffRoundResponse] = []
    for round_type in _ROUND_ORDER:
        round_series = sorted(
            [s for s in all_series if s.round == round_type],
            key=lambda s: s.series_index,
        )
        if not round_series:
            continue
        rounds.append(PlayoffRoundResponse(
            round_type=round_type,
            round_name=_ROUND_LABELS.get(round_type, round_type),
            series=[_series_to_response(s) for s in round_series],
        ))

    return PlayoffBracketResponse(
        league_id=league_auto_id,
        league_name=league.name,
        rounds=rounds,
    )
