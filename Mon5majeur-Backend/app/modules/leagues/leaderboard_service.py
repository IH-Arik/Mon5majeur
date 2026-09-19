"""
Leaderboard service — Regular Season standings + Playoff bracket.

Standings:  reads LeagueMembership records, ranks by wins → differential → FP → head-to-head.
Playoffs:   reads PlayoffSeries documents for the given league.
"""
from functools import cmp_to_key

from beanie import PydanticObjectId

from app.exceptions.errors import NotFoundException
from app.modules.leagues.constants import MATCH_STATUS_COMPLETED
from app.modules.leagues.model import League, LeagueMatch, LeagueMembership
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
    "semi_final": "Semi Finals",
    "final":      "Final",
}

_ROUND_ORDER: list[str] = ["semi_final", "final"]


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


def _match_visible(viewer, match) -> bool:
    """False when `viewer` must not yet see this match's outcome (score
    paywall, QA 15/09/2026 item 4). No viewer = internal/system use = all."""
    if viewer is None:
        return True
    from app.modules.leagues.score_visibility import scores_hidden

    return not scores_hidden(viewer, status=match.status, nba_date=match.nba_date)


def tally_matches(member_map: dict, matches: list) -> None:
    """Add each completed match's points and win/loss to the members in
    `member_map` ({user_id: membership-like}). The one place the W/L/PF/PA
    arithmetic lives: engine.update_standings (stored totals) and the
    viewer-filtered standings both call it, so they can never disagree."""
    for match in matches:
        home = member_map.get(match.home_user_id)
        away = member_map.get(match.away_user_id)
        if home:
            home.points_for += match.home_score or 0.0
            home.points_against += match.away_score or 0.0
            if match.winner_id == match.home_user_id:
                home.wins += 1
            elif match.winner_id == match.away_user_id:
                home.losses += 1
        if away:
            away.points_for += match.away_score or 0.0
            away.points_against += match.home_score or 0.0
            if match.winner_id == match.away_user_id:
                away.wins += 1
            elif match.winner_id == match.home_user_id:
                away.losses += 1


async def viewer_memberships(
    league_id: PydanticObjectId, viewer
) -> list[LeagueMembership]:
    """The league's memberships as `viewer` is allowed to see them.

    Live Scoring subscribers (and system callers) get the stored totals. For
    everyone else the totals are rebuilt from only the matches whose scores
    are already released (09:00 Paris the morning after the night) — otherwise
    W/L/points/rank would reveal a result the paywall is hiding. Returns
    in-memory copies; nothing is saved."""
    from app.modules.leagues.score_visibility import has_live_access

    memberships = await LeagueMembership.find({"league_id": league_id}).to_list()
    if viewer is None or has_live_access(viewer):
        return memberships

    copies = [m.model_copy() for m in memberships]
    for m in copies:
        m.wins = 0
        m.losses = 0
        m.points_for = 0.0
        m.points_against = 0.0
    completed = await LeagueMatch.find(
        {"league_id": league_id, "status": MATCH_STATUS_COMPLETED}
    ).to_list()
    tally_matches(
        {m.user_id: m for m in copies},
        [m for m in completed if _match_visible(viewer, m)],
    )
    return copies


async def viewer_rank(league_id: PydanticObjectId, user_id, viewer) -> int | None:
    """`user_id`'s standing as `viewer` may see it (see viewer_memberships)."""
    ms = await viewer_memberships(league_id, viewer)
    if not ms:
        return None
    umap = await _user_map([m.user_id for m in ms])
    ranked = await ranked_memberships(league_id, umap, ms, viewer=viewer)
    for rank, m in enumerate(ranked, start=1):
        if m.user_id == user_id:
            return rank
    return None


async def _head_to_head_winner(
    league_id: PydanticObjectId,
    user_a: PydanticObjectId,
    user_b: PydanticObjectId,
    viewer=None,
) -> PydanticObjectId | None:
    """Who won more of the regular-season meetings between these two
    (spec §4.6.2 tie-break step 3). None if never played or perfectly split —
    the caller falls through to the alphabetical last resort in that case."""
    matches = await LeagueMatch.find(
        LeagueMatch.league_id == league_id,
        LeagueMatch.status == MATCH_STATUS_COMPLETED,
        LeagueMatch.is_playoff == False,  # noqa: E712 — regular-season standings only
        {"$or": [
            {"home_user_id": user_a, "away_user_id": user_b},
            {"home_user_id": user_b, "away_user_id": user_a},
        ]},
    ).to_list()
    matches = [m for m in matches if _match_visible(viewer, m)]

    wins_a = sum(1 for m in matches if m.winner_id == user_a)
    wins_b = sum(1 for m in matches if m.winner_id == user_b)
    if wins_a == wins_b:
        return None
    return user_a if wins_a > wins_b else user_b


async def ranked_memberships(
    league_id: PydanticObjectId,
    umap: dict,
    memberships: list[LeagueMembership] | None = None,
    viewer=None,
) -> list[LeagueMembership]:
    """Full standings order (spec §4.6.2): wins → differential → points_for →
    head-to-head → alphabetical pseudo (deterministic last resort). Shared by
    the Standings tab and playoff seeding so both agree on the same order.
    Pass `memberships` when the caller already holds in-memory, not-yet-saved
    updates (e.g. update_standings mid-recompute) — otherwise this re-queries
    the DB itself, which would rank on stale wins/points_for."""
    if memberships is None:
        memberships = await LeagueMembership.find(
            LeagueMembership.league_id == league_id
        ).to_list()

    async def _cmp(a: LeagueMembership, b: LeagueMembership) -> int:
        if a.wins != b.wins:
            return -1 if a.wins > b.wins else 1
        diff_a, diff_b = a.differential, b.differential
        if diff_a != diff_b:
            return -1 if diff_a > diff_b else 1
        if a.points_for != b.points_for:
            return -1 if a.points_for > b.points_for else 1

        h2h = await _head_to_head_winner(league_id, a.user_id, b.user_id, viewer)
        if h2h is not None:
            return -1 if h2h == a.user_id else 1

        name_a = _display_name(umap.get(a.user_id))
        name_b = _display_name(umap.get(b.user_id))
        return -1 if name_a < name_b else (1 if name_a > name_b else 0)

    # cmp_to_key's comparator must be sync; _cmp is async (needs DB lookups
    # for head-to-head), so pre-resolve every pairwise comparison once up
    # front — memberships lists are tiny (max 10), this is cheap.
    resolved: dict[tuple, int] = {}
    for i, a in enumerate(memberships):
        for b in memberships[i + 1:]:
            resolved[(a.user_id, b.user_id)] = await _cmp(a, b)
            resolved[(b.user_id, a.user_id)] = -resolved[(a.user_id, b.user_id)]

    def _sync_cmp(a: LeagueMembership, b: LeagueMembership) -> int:
        if a.user_id == b.user_id:
            return 0
        return resolved[(a.user_id, b.user_id)]

    return sorted(memberships, key=cmp_to_key(_sync_cmp))


# ── Standings ─────────────────────────────────────────────────────────────────

async def get_standings(league_auto_id: int, viewer=None) -> StandingsResponse:
    league = await _league_or_404(league_auto_id)

    # Only what `viewer` may already see (score paywall) — see viewer_memberships.
    memberships = await viewer_memberships(league.id, viewer)

    if not memberships:
        return StandingsResponse(
            league_id=league_auto_id,
            league_name=league.name,
            playoff_spots=4,
            teams=[],
        )

    user_ids = [m.user_id for m in memberships]
    umap = await _user_map(user_ids)

    sorted_ms = await ranked_memberships(league.id, umap, memberships, viewer=viewer)
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

async def get_playoff_bracket(league_auto_id: int, viewer=None) -> PlayoffBracketResponse:
    from app.modules.leagues.model import LeagueMatch
    from app.modules.leagues.score_visibility import release_iso, scores_hidden

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

    # The duel behind each playoff game — gives the app a match_day to open
    # the match detail with, and the status the score paywall depends on.
    series_ids = [s.id for s in all_series]
    playoff_matches = (
        await LeagueMatch.find({"playoff_series_id": {"$in": series_ids}}).to_list()
        if series_ids
        else []
    )
    match_by_game = {
        (m.playoff_series_id, m.playoff_game_number): m for m in playoff_matches
    }

    def _series_to_response(s: PlayoffSeries) -> PlayoffSeriesResponse:
        user_a = umap.get(s.team_a_id)
        user_b = umap.get(s.team_b_id)

        games = []
        wins_a = wins_b = 0
        any_hidden = False
        for g in s.games:
            m = match_by_game.get((s.id, g.game_number))
            status = m.status if m else ("completed" if g.winner_id else "upcoming")
            hidden = viewer is not None and scores_hidden(
                viewer, status=status, nba_date=(m.nba_date if m else g.nba_date)
            )
            any_hidden = any_hidden or hidden
            if not hidden and g.winner_id == s.team_a_id:
                wins_a += 1
            elif not hidden and g.winner_id == s.team_b_id:
                wins_b += 1
            games.append(
                PlayoffGameResponse(
                    game_number=g.game_number,
                    score_a=0 if hidden else int(g.score_a),
                    score_b=0 if hidden else int(g.score_b),
                    winner_team=(
                        _display_name(user_a if g.winner_id == s.team_a_id else user_b)
                        if g.winner_id and not hidden
                        else ""
                    ),
                    match_day=m.match_day if m else None,
                    match_status=status,
                    scores_hidden=hidden,
                    scores_release_at=(
                        release_iso(m.nba_date if m else g.nba_date) if hidden else None
                    ),
                )
            )

        # A series result would leak a paywalled game's outcome, so it is
        # only reported once every game in it has been revealed.
        winner = umap.get(s.winner_id) if (s.winner_id and not any_hidden) else None

        return PlayoffSeriesResponse(
            series_index=s.series_index,
            round=s.round,
            team_a_id=user_a.auto_id or 0 if user_a else 0,
            team_a_name=_display_name(user_a),
            team_b_id=user_b.auto_id or 0 if user_b else 0,
            team_b_name=_display_name(user_b),
            wins_a=wins_a if viewer is not None else s.wins_a,
            wins_b=wins_b if viewer is not None else s.wins_b,
            games=games,
            winner_id=winner.auto_id if winner else None,
            winner_name=_display_name(winner) if winner else None,
            is_complete=s.is_complete and not any_hidden,
            has_hidden_scores=any_hidden,
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
