from __future__ import annotations

from datetime import datetime, timedelta, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import ForbiddenException, NotFoundException
from app.modules.leagues.model import LeagueMatch
from app.modules.lineups.model import LineupSlot, LineupSubmission
from app.modules.live_scores.schema import (
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

        from app.modules.leagues.model import League
        league = await League.get(match.league_id)

        home_players = await _get_live_players(
            match.home_user_id, match.league_id, match.nba_date
        )
        away_players = await _get_live_players(
            match.away_user_id, match.league_id, match.nba_date
        )

        home_score = sum(p.fantasy_score_live for p in home_players)
        away_score = sum(p.fantasy_score_live for p in away_players)

        from app.modules.users.model import User as UserModel
        home_user = await UserModel.get(match.home_user_id)
        away_user = await UserModel.get(match.away_user_id)

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
            refreshed_at=datetime.now(timezone.utc),
        )

    async def grant_premium(self, user: User, days: int) -> User:
        """Admin: extend premium_until by N days."""
        now = datetime.now(timezone.utc)
        base = max(user.premium_until or now, now)
        user.premium_until = base + timedelta(days=days)
        await user.save()
        return user


async def _get_live_players(
    user_id: PydanticObjectId,
    league_id: PydanticObjectId,
    nba_date,
) -> list[LivePlayerScore]:
    slots = await LineupSlot.find(
        LineupSlot.user_id == user_id,
        LineupSlot.league_id == league_id,
        LineupSlot.nba_date == nba_date,
    ).to_list()

    result: list[LivePlayerScore] = []
    for slot in slots:
        stat = await PlayerGameStats.find_one(
            PlayerGameStats.player_id == slot.player_id,
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
            stat = None

        result.append(LivePlayerScore(
            player_id=slot.player_id,
            full_name=slot.player_name,
            position=slot.player_position or None,
            team_name=None,
            slot=slot.slot,
            points=stat.points if stat else 0,
            rebounds=stat.rebounds if stat else 0,
            assists=stat.assists if stat else 0,
            steals=stat.steals if stat else 0,
            blocks=stat.blocks if stat else 0,
            turnovers=stat.turnovers if stat else 0,
            minutes_played=stat.minutes_played if stat else 0,
            fantasy_score_live=round(live_score, 2),
            is_finalized=is_final,
        ))

    return result
