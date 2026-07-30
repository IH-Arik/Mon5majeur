from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import ForbiddenException, NotFoundException
from app.modules.leagues.model import League, LeagueMatch
from app.modules.live_scores.schema import (
    LiveGlobalScore,
    LiveMatchScore,
    LivePlayerScore,
    PremiumStatusResponse,
)
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.scoring import compute_fantasy_score
from app.modules.users.model import User


def _is_premium(user: User) -> bool:
    if user.premium_until is None:
        return False
    return user.premium_until > datetime.now(timezone.utc)


class LiveScoreService:

    def get_premium_status(self, user: User) -> PremiumStatusResponse:
        return PremiumStatusResponse(
            is_premium=_is_premium(user),
            premium_until=user.premium_until,
        )

    async def get_live_match(
        self, user: User, match_id: PydanticObjectId
    ) -> LiveMatchScore:
        if not _is_premium(user):
            raise ForbiddenException(
                "Live scores require a premium subscription"
            )

        match = await LeagueMatch.get(match_id)
        if not match:
            raise NotFoundException("Match not found")

        # Verify user is a participant
        if user.id not in (match.home_user_id, match.away_user_id):
            raise ForbiddenException("You are not in this match")

        league = await League.get(match.league_id)

        home_players, home_score = await _get_live_players_for_user(
            match.home_user_id, league, match.match_day, match.nba_date
        )
        away_players, away_score = await _get_live_players_for_user(
            match.away_user_id, league, match.match_day, match.nba_date
        )

        home_user = await User.get(match.home_user_id)
        away_user = await User.get(match.away_user_id)

        return LiveMatchScore(
            match_id=match.id,
            league_id=match.league_id,
            league_name=league.name if league else "Unknown",
            nba_date=str(match.nba_date),
            home_user_id=match.home_user_id,
            away_user_id=match.away_user_id,
            home_team_name=home_user.team_name if home_user else None,
            away_team_name=away_user.team_name if away_user else None,
            home_score=round(home_score, 2),
            away_score=round(away_score, 2),
            match_status=match.status,
            home_players=home_players,
            away_players=away_players,
            is_stale=await _is_stale_for_date(match.nba_date),
            refreshed_at=datetime.now(timezone.utc),
        )

    async def get_global_live(self, user: User) -> LiveGlobalScore:
        """Live score for the user's Global League selection (spec §4.5:
        live score must also cover the Global League, not just duel leagues).
        No opponent, no bonuses — the Global League has neither."""
        if not _is_premium(user):
            raise ForbiddenException(
                "Live scores require a premium subscription"
            )

        from app.modules.players.compat_router import _nba_today

        league = await League.find_one(League.type == "global")
        if not league:
            raise NotFoundException("Global league not found")

        today = await _nba_today()
        sel = await _get_selection(user.id, league, league.current_match_day)

        if not sel:
            return LiveGlobalScore(
                league_id=league.id,
                league_name=league.name,
                total_score=0.0,
                players=[],
                is_stale=False,
                refreshed_at=datetime.now(timezone.utc),
            )

        players, total = await _build_live_players(
            sel.selected_players, sel.sixth_man_player, today
        )
        # sel.chef_curry is always False for the Global League (its own save
        # endpoint never accepts bonus flags) — kept here only for symmetry
        # with the duel path, never actually True in practice.
        if sel.chef_curry:
            total += 3

        return LiveGlobalScore(
            league_id=league.id,
            league_name=league.name,
            total_score=round(total, 2),
            players=players,
            is_stale=await _is_stale_for_date(today),
            refreshed_at=datetime.now(timezone.utc),
        )

    async def grant_premium(self, user: User, days: int) -> User:
        """Admin: extend premium_until by N days."""
        now = datetime.now(timezone.utc)
        base = max(user.premium_until or now, now)
        user.premium_until = base + timedelta(days=days)
        await user.save()
        return user


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

async def _get_selection(user_id: PydanticObjectId, league: League, match_day: int):
    from app.modules.lineups.compat_model import FlutterPlayerSelection

    return await FlutterPlayerSelection.find_one(
        FlutterPlayerSelection.user_id == user_id,
        FlutterPlayerSelection.league_auto_id == league.auto_id,
        FlutterPlayerSelection.match_day == match_day,
    )


async def _get_live_players_for_user(
    user_id: PydanticObjectId,
    league: League | None,
    match_day: int,
    nba_date: date,
) -> tuple[list[LivePlayerScore], float]:
    """A duel-league participant's live players + bonus-aware total, read
    from FlutterPlayerSelection — the store the team builder actually saves
    to (LineupSubmission/LineupSlot is a separate, unused system; reading
    from there meant this endpoint always returned an empty lineup)."""
    if league is None:
        return [], 0.0

    sel = await _get_selection(user_id, league, match_day)
    if not sel:
        return [], 0.0  # forfeit — no lineup submitted (spec §4.1)

    players, total = await _build_live_players(
        sel.selected_players, sel.sixth_man_player, nba_date
    )
    if sel.chef_curry:
        total += 3
    return players, total


async def _build_live_players(
    selected_players: list[dict],
    sixth_man_player: dict | None,
    nba_date: date,
) -> tuple[list[LivePlayerScore], float]:
    """Build live per-player scores; if a 6th Man is present, mark the top 5
    of 6 as counted (spec §4.4) and sum only those into the total."""
    all_players = list(selected_players)
    sixth_index = None
    if sixth_man_player is not None:
        sixth_index = len(all_players)
        all_players = all_players + [sixth_man_player]

    entries: list[dict] = []
    for idx, p in enumerate(all_players):
        raw_id = p.get("id")
        try:
            player_id = PydanticObjectId(str(raw_id))
        except Exception:
            continue

        player_doc = await Player.get(player_id)
        stat = await PlayerGameStats.find_one(
            PlayerGameStats.player_id == player_id,
            PlayerGameStats.nba_date == nba_date,
        )

        if stat and stat.score_computed:
            live_score = stat.fantasy_score or 0.0
            is_final = True
        elif stat:
            live_score = compute_fantasy_score(stat)
            is_final = False
        else:
            live_score = 0.0
            is_final = False

        # OUT player live -> 0, consistent with spec §4.7
        if player_doc and player_doc.is_out:
            live_score = 0.0

        entries.append({
            "player_id": player_id,
            "full_name": p.get("name") or (player_doc.full_name if player_doc else ""),
            "position": p.get("position") or (player_doc.position if player_doc else None),
            "team_name": player_doc.team_name if player_doc else None,
            "slot": "SIXTH_MAN" if idx == sixth_index else "STARTER",
            "points": stat.points if stat else 0,
            "rebounds": stat.rebounds if stat else 0,
            "assists": stat.assists if stat else 0,
            "steals": stat.steals if stat else 0,
            "blocks": stat.blocks if stat else 0,
            "turnovers": stat.turnovers if stat else 0,
            "minutes_played": stat.minutes_played if stat else 0,
            "fantasy_score_live": round(live_score, 2),
            "is_finalized": is_final,
        })

    if sixth_index is not None and len(entries) == 6:
        ranked = sorted(range(len(entries)), key=lambda i: entries[i]["fantasy_score_live"], reverse=True)
        counted = set(ranked[:5])
    else:
        counted = set(range(len(entries)))

    total = 0.0
    result: list[LivePlayerScore] = []
    for i, e in enumerate(entries):
        is_counted = i in counted
        if is_counted:
            total += e["fantasy_score_live"]
        result.append(LivePlayerScore(is_counted=is_counted, **e))

    return result, total


async def _is_stale_for_date(nba_date: date) -> bool:
    """True if a live game's box-score data hasn't been refreshed recently
    (spec §4.5: serve last cached score + is_stale: true, never 0/crash).

    NOTE: the spec says "refresh every 1 minute" but sync_live_games_job is
    actually scheduled every 20 minutes (see scheduler.py) — likely a
    Goalserve API quota constraint, exactly what the spec's own Phase-0 box
    flagged as needing validation. The threshold below matches the *real*
    cadence (with one missed-cycle tolerance), not the spec's stated number
    — using 2 minutes here would mark every live game stale permanently."""
    live_games = await NBAGame.find(
        NBAGame.nba_date == nba_date,
        NBAGame.status == "live",
    ).to_list()
    if not live_games:
        return False

    now = datetime.now(timezone.utc)
    for game in live_games:
        updated = game.updated_at
        if updated.tzinfo is None:
            updated = updated.replace(tzinfo=timezone.utc)
        if (now - updated) > timedelta(minutes=25):
            return True
    return False
