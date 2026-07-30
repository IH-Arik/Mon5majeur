"""
Playoff engine (spec §4.6.3): Top-4 seeded straight into semifinals, each
round BO3, seeding budget bonus, winner → league completion.

Reuses the regular-season lineup/lock/budget pipeline for playoff games —
every playoff game is a normal LeagueMatch (scored by engine.score_match_day
exactly like a regular-season duel), just tagged with is_playoff/seed/series
fields so the team-builder, lock countdown, and bonus logic all keep working
unchanged. This module only owns the bracket: creating series, recording
each game's result onto its series, advancing rounds, and completing the
league once the final is won.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.modules.leagues.constants import LEAGUE_STATUS_COMPLETED, MATCH_STATUS_COMPLETED
from app.modules.leagues.model import League, LeagueMatch, LeagueMembership
from app.modules.leagues.playoff_model import PlayoffGame, PlayoffSeries

logger = get_logger(__name__)

# Regular rank (1-4) → extra budget for every playoff game (spec §4.6.3).
SEED_BUDGET_BONUS: dict[int, float] = {1: 4.0, 2: 2.0, 3: 1.0, 4: 0.0}


def _playoff_home(
    game_number: int, higher_seed_id: PydanticObjectId, lower_seed_id: PydanticObjectId
) -> tuple[PydanticObjectId, PydanticObjectId]:
    """Game 1 & 3 → higher seed home; Game 2 → lower seed home (spec §4.6.3)."""
    if game_number == 2:
        return lower_seed_id, higher_seed_id
    return higher_seed_id, lower_seed_id


async def _last_nba_date(league_id: PydanticObjectId) -> date | None:
    last = await LeagueMatch.find(
        LeagueMatch.league_id == league_id
    ).sort(-LeagueMatch.nba_date).first_or_none()
    return last.nba_date if last else None


async def _insert_series_game(
    league: League,
    round_type: str,
    series_index: int,
    team_a_id: PydanticObjectId,
    team_b_id: PydanticObjectId,
    seed_a: int | None,
    seed_b: int | None,
    nba_date: date,
    match_day: int,
) -> None:
    """Create a series + its Game 1. `match_day` is passed in (rather than
    derived from league.current_match_day here) so that two series starting
    on the same night — both semifinals — share the same match_day instead
    of each bumping it further."""
    series = await PlayoffSeries(
        league_id=league.id,
        round=round_type,
        series_index=series_index,
        team_a_id=team_a_id,
        team_b_id=team_b_id,
        seed_a=seed_a,
        seed_b=seed_b,
    ).insert()

    home_id, away_id = _playoff_home(1, team_a_id, team_b_id)

    await LeagueMatch(
        league_id=league.id,
        match_day=match_day,
        nba_date=nba_date,
        home_user_id=home_id,
        away_user_id=away_id,
        is_playoff=True,
        playoff_series_id=series.id,
        playoff_game_number=1,
        home_seed=seed_a if home_id == team_a_id else seed_b,
        away_seed=seed_b if away_id == team_b_id else seed_a,
    ).insert()


async def start_playoffs(league: League) -> None:
    """Seed the Top 4 (spec §4.6.3: in a 4-team league this is everyone) and
    create both semifinal series' Game 1. Called once, right after the
    regular season's last match day is scored and standings are final."""
    from app.modules.leagues.leaderboard_service import ranked_memberships
    from app.modules.users.model import User

    memberships = await LeagueMembership.find(
        LeagueMembership.league_id == league.id
    ).to_list()
    if len(memberships) < 4:
        logger.error("Cannot start playoffs for league %s: fewer than 4 members", league.id)
        return

    user_ids = [m.user_id for m in memberships]
    users = await User.find({"_id": {"$in": user_ids}}).to_list()
    umap = {u.id: u for u in users}

    top4 = (await ranked_memberships(league.id, umap, memberships))[:4]
    seed_of = {m.user_id: i + 1 for i, m in enumerate(top4)}

    last_date = await _last_nba_date(league.id)
    next_date = (last_date or datetime.now(timezone.utc).date()) + timedelta(days=1)
    match_day = league.current_match_day + 1

    seed1, seed2, seed3, seed4 = (m.user_id for m in top4)

    # Series 0: seed 1 vs seed 4. Series 1: seed 2 vs seed 3. Same match_day
    # and nba_date — both semifinals tip off the same night.
    await _insert_series_game(league, "semi_final", 0, seed1, seed4, seed_of[seed1], seed_of[seed4], next_date, match_day)
    await _insert_series_game(league, "semi_final", 1, seed2, seed3, seed_of[seed2], seed_of[seed3], next_date, match_day)

    league.current_match_day = match_day
    await league.save()

    logger.info(
        "Started playoffs for league %s: seeds 1=%s 2=%s 3=%s 4=%s",
        league.id, seed1, seed2, seed3, seed4,
    )


async def _notify_league_winner(league: League, winner_id: PydanticObjectId) -> None:
    from app.modules.notifications.service import NotificationService

    await NotificationService().send_push_to_user(
        user_id=winner_id,
        title="🏆 You won the league!",
        body=f"You're the champion of {league.name}. Congratulations!",
        data={"type": "league_playoff_winner", "league_id": str(league.id)},
    )


async def advance_playoffs(league: League, nba_date: date) -> None:
    """Called once a day (after engine.score_match_day) for any PLAYOFFS
    league. Folds today's just-scored playoff games onto their series,
    advances a series to its next game, advances a completed semifinal
    round into the final, or completes the league once the final is won."""
    todays_matches = await LeagueMatch.find(
        LeagueMatch.league_id == league.id,
        LeagueMatch.is_playoff == True,  # noqa: E712
        LeagueMatch.nba_date == nba_date,
        LeagueMatch.status == MATCH_STATUS_COMPLETED,
        LeagueMatch.playoff_series_id != None,  # noqa: E711
    ).to_list()
    if not todays_matches:
        return

    touched_rounds: set[str] = set()
    # Shared across every series advancing tonight, so two series both
    # needing a next game (e.g. both semis going to game 3) land on the
    # same match_day/night instead of each bumping current_match_day further.
    next_match_day: int | None = None
    next_date = nba_date + timedelta(days=1)

    for match in todays_matches:
        series = await PlayoffSeries.get(match.playoff_series_id)
        if not series or series.is_complete:
            continue
        touched_rounds.add(series.round)

        is_a_home = match.home_user_id == series.team_a_id
        score_a = (match.home_score if is_a_home else match.away_score) or 0.0
        score_b = (match.away_score if is_a_home else match.home_score) or 0.0

        series.games.append(PlayoffGame(
            game_number=match.playoff_game_number or len(series.games) + 1,
            score_a=score_a,
            score_b=score_b,
            nba_date=nba_date,
            winner_id=match.winner_id,
        ))
        if match.winner_id == series.team_a_id:
            series.wins_a += 1
        else:
            series.wins_b += 1

        if series.wins_a == 2 or series.wins_b == 2:
            series.winner_id = series.team_a_id if series.wins_a == 2 else series.team_b_id
            series.is_complete = True
        await series.save()

        if not series.is_complete:
            if next_match_day is None:
                next_match_day = league.current_match_day + 1
            next_game_no = (match.playoff_game_number or 1) + 1
            home_id, away_id = _playoff_home(next_game_no, series.team_a_id, series.team_b_id)

            await LeagueMatch(
                league_id=league.id,
                match_day=next_match_day,
                nba_date=next_date,
                home_user_id=home_id,
                away_user_id=away_id,
                is_playoff=True,
                playoff_series_id=series.id,
                playoff_game_number=next_game_no,
                home_seed=series.seed_a if home_id == series.team_a_id else series.seed_b,
                away_seed=series.seed_b if away_id == series.team_b_id else series.seed_a,
            ).insert()

    if next_match_day is not None:
        league.current_match_day = next_match_day
        await league.save()

    for round_type in touched_rounds:
        if round_type == "semi_final":
            semis = await PlayoffSeries.find(
                PlayoffSeries.league_id == league.id,
                PlayoffSeries.round == "semi_final",
            ).to_list()
            if len(semis) == 2 and all(s.is_complete for s in semis):
                existing_final = await PlayoffSeries.find_one(
                    PlayoffSeries.league_id == league.id,
                    PlayoffSeries.round == "final",
                )
                if not existing_final:
                    await _start_final(league, semis, nba_date)

        elif round_type == "final":
            final = await PlayoffSeries.find_one(
                PlayoffSeries.league_id == league.id,
                PlayoffSeries.round == "final",
            )
            if final and final.is_complete and league.status != LEAGUE_STATUS_COMPLETED:
                league.status = LEAGUE_STATUS_COMPLETED
                league.ended_at = datetime.now(timezone.utc)
                await league.save()
                await _notify_league_winner(league, final.winner_id)
                logger.info("League %s completed — winner %s", league.id, final.winner_id)


async def _start_final(league: League, semis: list[PlayoffSeries], nba_date: date) -> None:
    """Both semifinal winners' own seeds carry forward — the better-seeded
    winner is team_a (higher seed) for the final's home rules/budget bonus."""
    winners: list[tuple[PydanticObjectId, int]] = []
    for s in semis:
        winner_seed = s.seed_a if s.winner_id == s.team_a_id else s.seed_b
        winners.append((s.winner_id, winner_seed or 99))

    winners.sort(key=lambda w: w[1])  # lower seed number = better
    (team_a_id, seed_a), (team_b_id, seed_b) = winners

    next_date = nba_date + timedelta(days=1)
    match_day = league.current_match_day + 1
    await _insert_series_game(league, "final", 0, team_a_id, team_b_id, seed_a, seed_b, next_date, match_day)
    league.current_match_day = match_day
    await league.save()
    logger.info("Started final for league %s: seed %s vs seed %s", league.id, seed_a, seed_b)
