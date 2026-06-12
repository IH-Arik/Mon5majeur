"""
League engine: start league, round-robin scheduling, standings, playoffs.

Called by CRON at 09:00 Paris after all fantasy scores are final.
Order: scores → standings → prices (never reverse this order).
"""
from __future__ import annotations

import itertools
from datetime import date, datetime, timedelta, timezone

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.exceptions.errors import BadRequestException, NotFoundException
from app.modules.leagues.constants import (
    LEAGUE_STATUS_COMPLETED,
    LEAGUE_STATUS_PLAYOFFS,
    LEAGUE_STATUS_REGULAR,
    LEAGUE_STATUS_WAITING,
    MATCH_DAYS_BY_SIZE,
    MATCH_STATUS_COMPLETED,
)
from app.modules.leagues.model import League, LeagueMatch, LeagueMembership

logger = get_logger(__name__)


# ---------------------------------------------------------------------------
# Start league + round-robin schedule
# ---------------------------------------------------------------------------

async def start_league(league_id: PydanticObjectId, first_nba_date: date) -> League:
    """
    Transition a waiting league to regular_season and generate all match-day
    pairings. Each match day maps to one NBA date (passed in or incremented).
    """
    league = await League.get(league_id)
    if not league:
        raise NotFoundException("League not found")
    if league.status != LEAGUE_STATUS_WAITING:
        raise BadRequestException("League is not in waiting state")

    memberships = await LeagueMembership.find(
        LeagueMembership.league_id == league_id
    ).to_list()

    n_members = len(memberships)
    if n_members < 4:
        raise BadRequestException("Need at least 4 members to start a league")
    if n_members % 2 != 0:
        raise BadRequestException(
            f"League must have an even number of players (4/6/8/10) to start — "
            f"currently {n_members} members"
        )

    user_ids = [m.user_id for m in memberships]
    schedule = _round_robin_schedule(user_ids)
    total_match_days = len(schedule)

    # One NBA date per match day (consecutive days — skip no days for simplicity;
    # CRON will skip non-game-days naturally)
    for md_index, pairings in enumerate(schedule):
        nba_date = first_nba_date + timedelta(days=md_index)
        match_day = md_index + 1
        for home_id, away_id in pairings:
            await LeagueMatch(
                league_id=league_id,
                match_day=match_day,
                nba_date=nba_date,
                home_user_id=home_id,
                away_user_id=away_id,
            ).insert()

    now = datetime.now(timezone.utc)
    league.status = LEAGUE_STATUS_REGULAR
    league.current_match_day = 1
    league.current_week = 1
    league.total_match_days = total_match_days
    league.started_at = now
    await league.save()

    logger.info(
        "Started league %s: %d match days, %d members",
        league_id, total_match_days, len(user_ids),
    )
    return league


def _round_robin_schedule(user_ids: list[PydanticObjectId]) -> list[list[tuple]]:
    """
    Home-and-away round-robin (spec §4.6.2): everyone faces everyone twice (aller + retour).
    n players → 2*(n-1) match days. n must be even (caller validates).
    Returns list of rounds; each round is a list of (home_id, away_id) tuples.
    """
    players = list(user_ids)
    n = len(players)

    aller: list[list[tuple]] = []
    for _ in range(n - 1):
        pairings = [(players[i], players[n - 1 - i]) for i in range(n // 2)]
        aller.append(pairings)
        # Standard circle rotation: fix first player, rotate the rest
        players = [players[0]] + [players[-1]] + players[1:-1]

    # Retour: reverse home/away for each round
    retour = [[(away, home) for home, away in round_] for round_ in aller]
    return aller + retour


# ---------------------------------------------------------------------------
# Score a match day
# ---------------------------------------------------------------------------

async def score_match_day(league_id: PydanticObjectId, match_day: int, nba_date: date) -> int:
    """
    Pull LineupSubmission total_scores for both sides, set match scores,
    determine winner, mark complete.
    Returns number of matches processed.
    """
    from app.modules.lineups.model import LineupSubmission

    matches = await LeagueMatch.find(
        LeagueMatch.league_id == league_id,
        LeagueMatch.match_day == match_day,
        LeagueMatch.nba_date == nba_date,
    ).to_list()

    count = 0
    for match in matches:
        home_sub = await LineupSubmission.find_one(
            LineupSubmission.user_id == match.home_user_id,
            LineupSubmission.league_id == league_id,
            LineupSubmission.nba_date == nba_date,
            LineupSubmission.score_finalized == True,  # noqa: E712
        )
        away_sub = await LineupSubmission.find_one(
            LineupSubmission.user_id == match.away_user_id,
            LineupSubmission.league_id == league_id,
            LineupSubmission.nba_date == nba_date,
            LineupSubmission.score_finalized == True,  # noqa: E712
        )

        home_score = home_sub.total_score if home_sub else 0.0
        away_score = away_sub.total_score if away_sub else 0.0

        # Tie → home wins (spec §4.6.2: "there are never draws")
        if home_score >= away_score:
            winner_id = match.home_user_id
        else:
            winner_id = match.away_user_id

        match.home_score = home_score
        match.away_score = away_score
        match.winner_id = winner_id
        match.status = MATCH_STATUS_COMPLETED
        await match.save()
        count += 1

    return count


# ---------------------------------------------------------------------------
# Update standings
# ---------------------------------------------------------------------------

async def update_standings(league_id: PydanticObjectId) -> None:
    """Recompute wins/losses/points_for/points_against/rank for all members."""
    memberships = await LeagueMembership.find(
        LeagueMembership.league_id == league_id
    ).to_list()

    member_map = {m.user_id: m for m in memberships}

    # Reset
    for m in memberships:
        m.wins = 0
        m.losses = 0
        m.points_for = 0.0
        m.points_against = 0.0

    completed_matches = await LeagueMatch.find(
        LeagueMatch.league_id == league_id,
        LeagueMatch.status == MATCH_STATUS_COMPLETED,
    ).to_list()

    for match in completed_matches:
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

    # Sort by: wins desc → point differential desc → total points scored desc (spec §4.6.2)
    sorted_members = sorted(
        memberships,
        key=lambda m: (m.wins, m.points_for - m.points_against, m.points_for),
        reverse=True,
    )
    for rank, m in enumerate(sorted_members, start=1):
        m.rank = rank
        await m.save()


# ---------------------------------------------------------------------------
# Advance match day
# ---------------------------------------------------------------------------

async def advance_match_day(league_id: PydanticObjectId) -> League:
    """
    Increment current_match_day. If all regular-season days done → playoffs or complete.
    """
    league = await League.get(league_id)
    if not league:
        raise NotFoundException("League not found")

    if league.status == LEAGUE_STATUS_REGULAR:
        if league.current_match_day >= league.total_match_days:
            # Regular season over — check if we need playoffs
            if league.max_size >= 4:
                league.status = LEAGUE_STATUS_PLAYOFFS
            else:
                league.status = LEAGUE_STATUS_COMPLETED
                league.ended_at = datetime.now(timezone.utc)
        else:
            league.current_match_day += 1
            league.current_week = (league.current_match_day - 1) // 2 + 1

    elif league.status == LEAGUE_STATUS_PLAYOFFS:
        # Playoffs are handled separately; this just marks completion
        league.status = LEAGUE_STATUS_COMPLETED
        league.ended_at = datetime.now(timezone.utc)

    await league.save()
    return league


# ---------------------------------------------------------------------------
# Full CRON pipeline for one date (called at 09:00 Paris)
# ---------------------------------------------------------------------------

async def run_daily_close(nba_date: date) -> dict:
    """
    Run the full daily close in strict order:
    1. Score match days for all active leagues
    2. Update standings
    3. Advance match days
    Returns a summary dict.
    """
    active_leagues = await League.find(
        {"status": {"$in": [LEAGUE_STATUS_REGULAR, LEAGUE_STATUS_PLAYOFFS]}}
    ).to_list()

    results = {"leagues_processed": 0, "matches_scored": 0}

    for league in active_leagues:
        try:
            scored = await score_match_day(league.id, league.current_match_day, nba_date)
            results["matches_scored"] += scored

            await update_standings(league.id)
            await advance_match_day(league.id)
            results["leagues_processed"] += 1
        except Exception as exc:
            logger.error("Daily close failed for league %s: %s", league.id, exc)

    logger.info("Daily close done: %s", results)
    return results
