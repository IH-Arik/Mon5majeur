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
    LEAGUE_STATUS_PLAYOFFS,
    LEAGUE_STATUS_REGULAR,
    LEAGUE_STATUS_WAITING,
    MATCH_DAYS_BY_SIZE,
    MATCH_STATUS_COMPLETED,
    MATCH_STATUS_LIVE,
    MATCH_STATUS_UPCOMING,
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
    for r in range(n - 1):
        pairings = []
        for i in range(n // 2):
            home, away = players[i], players[n - 1 - i]
            # Alternate home/away by round parity (spec pseudocode) — without
            # this, the player fixed at index 0 by the rotation below plays
            # every single aller match at home and every retour match away,
            # instead of alternating through the season. Since ties go to
            # the home team, that's a real fairness gap, not just cosmetic.
            if r % 2 == 1:
                home, away = away, home
            pairings.append((home, away))
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
    Score both sides of every duel from the team each user actually built.

    NOTE: the Flutter team-builder writes to FlutterPlayerSelection (the
    Django-compat store), NOT LineupSubmission — that's a separate, unused
    system. Reading LineupSubmission here (as before) meant every duel
    silently resolved 0-0/home-wins regardless of what anyone picked. This
    reads the selection that's actually saved, and scores it the same way
    the Result tab does — including strategic bonuses (Luxury Tax/Chef
    Curry/6th Man, spec §4.4) via selection_service.score_full_selection.
    """
    from app.modules.leagues.selection_service import score_full_selection
    from app.modules.lineups.compat_model import FlutterPlayerSelection

    league = await League.get(league_id)
    if not league:
        return 0

    matches = await LeagueMatch.find(
        LeagueMatch.league_id == league_id,
        LeagueMatch.match_day == match_day,
        LeagueMatch.nba_date == nba_date,
    ).to_list()

    async def _user_score(user_id: PydanticObjectId) -> float:
        sel = await FlutterPlayerSelection.find_one(
            FlutterPlayerSelection.user_id == user_id,
            FlutterPlayerSelection.league_auto_id == league.auto_id,
            FlutterPlayerSelection.match_day == match_day,
        )
        if not sel:
            return 0.0  # forfeit — no lineup submitted (spec §4.1)
        return await score_full_selection(sel, nba_date)

    count = 0
    for match in matches:
        home_score = await _user_score(match.home_user_id)
        away_score = await _user_score(match.away_user_id)

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
# Live status sync (spec §4.5 / Night's Results)
# ---------------------------------------------------------------------------

async def sync_match_live_status(nba_date: date) -> int:
    """Flip today's still-"upcoming" LeagueMatch rows to "live" once any game
    for this NBA date has tipped off. Without this, LeagueMatch.status only
    ever moves upcoming -> completed (at the 09:00 close) and never passes
    through "live" — which silently breaks both the Night's Results LIVE
    badge and the Live Score feature, since both gate on this field.
    Called every 20 min from sync_live_games_job, alongside the box-score
    poll — cheap since it only touches rows still stuck at "upcoming"."""
    from app.modules.players.model import NBAGame

    games = await NBAGame.find(NBAGame.nba_date == nba_date).to_list()
    if not any(g.status in ("live", "final") for g in games):
        return 0

    matches = await LeagueMatch.find(
        LeagueMatch.nba_date == nba_date,
        LeagueMatch.status == MATCH_STATUS_UPCOMING,
    ).to_list()

    count = 0
    for match in matches:
        match.status = MATCH_STATUS_LIVE
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

    # Full tie-break cascade (spec §4.6.2): wins → differential → points_for →
    # head-to-head → alphabetical pseudo. Shared with the Standings tab and
    # playoff seeding so all three agree on the same order.
    from app.modules.leagues.leaderboard_service import ranked_memberships
    from app.modules.users.model import User as UserModel

    user_ids = [m.user_id for m in memberships]
    users = await UserModel.find({"_id": {"$in": user_ids}}).to_list() if user_ids else []
    umap = {u.id: u for u in users}

    sorted_members = await ranked_memberships(league_id, umap, memberships)
    for rank, m in enumerate(sorted_members, start=1):
        m.rank = rank
        await m.save()


# ---------------------------------------------------------------------------
# Advance match day
# ---------------------------------------------------------------------------

async def advance_match_day(league_id: PydanticObjectId) -> League:
    """
    Increment current_match_day. Once all regular-season days are done, hand
    off to the playoff engine (spec §4.6.3: every league — min size is 4 —
    goes Regular season → Playoffs → winner, there's no size-based skip).
    Playoff-status leagues are advanced by playoff_engine.advance_playoffs
    instead (called from run_daily_close), not from here.
    """
    league = await League.get(league_id)
    if not league:
        raise NotFoundException("League not found")

    if league.status == LEAGUE_STATUS_REGULAR:
        if league.current_match_day >= league.total_match_days:
            league.status = LEAGUE_STATUS_PLAYOFFS
            await league.save()

            from app.modules.leagues.playoff_engine import start_playoffs
            await start_playoffs(league)
            return league
        else:
            league.current_match_day += 1
            league.current_week = (league.current_match_day - 1) // 2 + 1

    await league.save()
    return league


# ---------------------------------------------------------------------------
# Full CRON pipeline for one date (called at 09:00 Paris)
# ---------------------------------------------------------------------------

async def run_daily_close(nba_date: date) -> dict:
    """
    Run the full daily close in strict order:
    1. Score match days for all active leagues (regular season and playoffs
       alike — playoff games are just tagged LeagueMatch rows, scored the
       same way)
    2. Regular season: update standings, advance match day (or hand off to
       playoffs once the season's done)
       Playoffs: advance the bracket (next game / next round / completion)
       — regular-season standings are frozen once playoffs start, so
       update_standings does not run for them.
    Returns a summary dict.
    """
    from app.modules.leagues.playoff_engine import advance_playoffs

    active_leagues = await League.find(
        {"status": {"$in": [LEAGUE_STATUS_REGULAR, LEAGUE_STATUS_PLAYOFFS]}}
    ).to_list()

    results = {"leagues_processed": 0, "matches_scored": 0}

    for league in active_leagues:
        try:
            scored = await score_match_day(league.id, league.current_match_day, nba_date)
            results["matches_scored"] += scored

            if league.status == LEAGUE_STATUS_REGULAR:
                await update_standings(league.id)
                await advance_match_day(league.id)
            else:
                await advance_playoffs(league, nba_date)
            results["leagues_processed"] += 1
        except Exception as exc:
            logger.error("Daily close failed for league %s: %s", league.id, exc)

    logger.info("Daily close done: %s", results)
    return results


# ---------------------------------------------------------------------------
# Auto-delete leagues the creator never started (spec §4.6.2: "A league not
# started within 7 days is auto deleted"). Called once a day by CRON.
# ---------------------------------------------------------------------------

async def delete_stale_waiting_leagues() -> int:
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    stale = await League.find(
        League.status == LEAGUE_STATUS_WAITING,
        League.created_at < cutoff,
    ).to_list()

    count = 0
    for league in stale:
        await LeagueMembership.find(LeagueMembership.league_id == league.id).delete()
        await league.delete()
        count += 1

    if count:
        logger.info("Auto-deleted %d league(s) not started within 7 days", count)
    return count
