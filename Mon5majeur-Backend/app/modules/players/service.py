from __future__ import annotations

from datetime import date, datetime, timezone

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.exceptions.errors import NotFoundException
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.nba_cdn import fetch_boxscore, fetch_player_index, fetch_schedule_for_date, fetch_today_scoreboard
from app.modules.players.pricing import recompute_player_price
from app.modules.players.repository import PlayerRepository
from app.modules.players.schema import PlayerSearchParams, PlayerTodayItem
from app.modules.players.scoring import compute_and_stamp
from app.shared.pagination import Page, PaginationParams

logger = get_logger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class PlayerService:
    def __init__(self, repo: PlayerRepository) -> None:
        self.repo = repo

    # ------------------------------------------------------------------
    # Basic CRUD
    # ------------------------------------------------------------------

    async def get_player(self, player_id: PydanticObjectId) -> Player:
        player = await self.repo.get(player_id)
        if not player:
            raise NotFoundException("Player not found")
        return player

    async def search_players(
        self, params: PlayerSearchParams, pagination: PaginationParams
    ) -> Page[Player]:
        items, total = await self.repo.search(
            q=params.q,
            league=params.league,
            position=params.position,
            team_id=params.team_id,
            offset=pagination.offset,
            limit=pagination.limit,
        )
        return Page.create(items, total, pagination)

    # ------------------------------------------------------------------
    # Today's players (for lineup picker)
    # ------------------------------------------------------------------

    async def get_players_today(self, nba_date: date | None = None) -> list[PlayerTodayItem]:
        """Return all active players whose team plays today, enriched with game time."""
        today = nba_date or datetime.now(timezone.utc).date()

        games = await NBAGame.find(NBAGame.nba_date == today).to_list()
        if not games:
            return []

        team_ids_playing: set[str] = set()
        game_by_team: dict[str, NBAGame] = {}
        for g in games:
            team_ids_playing.add(g.home_team_id)
            team_ids_playing.add(g.away_team_id)
            game_by_team[g.home_team_id] = g
            game_by_team[g.away_team_id] = g

        players = await Player.find(
            {"team_goalserve_id": {"$in": list(team_ids_playing)}, "is_active": True}
        ).sort(+Player.daily_price).to_list()

        result: list[PlayerTodayItem] = []
        for p in players:
            game = game_by_team.get(p.team_goalserve_id or "")
            opponent = None
            if game:
                if p.team_goalserve_id == game.home_team_id:
                    opponent = game.away_team_name
                else:
                    opponent = game.home_team_name

            result.append(PlayerTodayItem(
                id=p.id,
                full_name=p.full_name,
                position=p.position,
                team_name=p.team_name,
                team_goalserve_id=p.team_goalserve_id,
                image_url=p.image_url,
                is_out=p.is_out,
                out_reason=p.out_reason,
                daily_price=p.daily_price,
                avg_fantasy_score=p.avg_fantasy_score,
                game_time=game.tip_off_time if game else None,
                opponent_team_name=opponent,
            ))
        return result

    # ------------------------------------------------------------------
    # NBA CDN: sync players roster (replaces Goalserve)
    # ------------------------------------------------------------------

    async def sync_from_goalserve(self, league: str = "nba") -> int:
        """Fetch current NBA roster from NBA CDN playerIndex."""
        try:
            players_data = await fetch_player_index()
        except Exception as exc:
            logger.error("NBA CDN player index fetch failed: %s", exc)
            return 0

        count = 0
        for p in players_data:
            try:
                await self.repo.upsert_from_goalserve({
                    "goalserve_id": p["nba_player_id"],
                    "first_name": p["first_name"],
                    "last_name": p["last_name"],
                    "full_name": p["full_name"],
                    "position": p["position"],
                    "team_name": f"{p['team_city']} {p['team_name']}".strip(),
                    "team_goalserve_id": p["team_id"],
                    "jersey_number": p["jersey_number"],
                    "height": p["height"],
                    "weight": p["weight"],
                    "league": league,
                    "is_active": p["is_active"],
                })
                count += 1
            except Exception as exc:
                logger.warning("Failed to upsert player %s: %s", p.get("nba_player_id"), exc)

        logger.info("Synced %d players from NBA CDN", count)
        return count

    # ------------------------------------------------------------------
    # NBA CDN: sync schedule (replaces Goalserve)
    # ------------------------------------------------------------------

    async def sync_schedule(self, nba_date: date | None = None) -> int:
        """
        Sync today's NBA game schedule.
        Uses todaysScoreboard for current day; scheduleLeagueV2 for specific dates.
        """
        try:
            if nba_date is None:
                games_data = await fetch_today_scoreboard()
            else:
                games_data = await fetch_schedule_for_date(nba_date)
        except Exception as exc:
            logger.error("NBA CDN schedule fetch failed: %s", exc)
            return 0

        count = 0
        for g in games_data:
            try:
                existing = await NBAGame.find_one(NBAGame.goalserve_id == g["nba_game_id"])
                game_doc = {
                    "goalserve_id": g["nba_game_id"],
                    "nba_date": g["nba_date"],
                    "home_team_id": g["home_team_id"],
                    "away_team_id": g["away_team_id"],
                    "home_team_name": g["home_team_name"],
                    "away_team_name": g["away_team_name"],
                    "status": g["status"],
                    "tip_off_time": g["tip_off_utc"],
                    "home_score": g.get("home_score"),
                    "away_score": g.get("away_score"),
                }
                if existing:
                    for k, v in game_doc.items():
                        if k != "goalserve_id" and v is not None:
                            setattr(existing, k, v)
                    await existing.save()
                else:
                    await NBAGame(**game_doc).insert()
                count += 1
            except Exception as exc:
                logger.warning("Failed to upsert game %s: %s", g.get("nba_game_id"), exc)

        logger.info("Synced %d games from NBA CDN", count)
        return count

    # ------------------------------------------------------------------
    # NBA CDN: sync box-score stats (replaces Goalserve)
    # ------------------------------------------------------------------

    async def sync_game_stats(self, goalserve_game_id: str) -> int:
        """Fetch box-score from NBA CDN and upsert PlayerGameStats."""
        boxscore = await fetch_boxscore(goalserve_game_id)
        if not boxscore:
            return 0

        # Update game status/score in NBAGame
        try:
            game_doc = await NBAGame.find_one(NBAGame.goalserve_id == goalserve_game_id)
            if game_doc:
                game_doc.status = boxscore["status"]
                if boxscore.get("home_score") is not None:
                    game_doc.home_score = boxscore["home_score"]
                if boxscore.get("away_score") is not None:
                    game_doc.away_score = boxscore["away_score"]
                await game_doc.save()
        except Exception as exc:
            logger.warning("Failed to update NBAGame for %s: %s", goalserve_game_id, exc)

        count = 0
        for p in boxscore["players"]:
            try:
                # Resolve player by NBA player ID (stored in goalserve_id field)
                player = await Player.find_one(Player.goalserve_id == p["nba_player_id"])
                if not player:
                    continue

                existing = await PlayerGameStats.find_one(
                    PlayerGameStats.goalserve_game_id == goalserve_game_id,
                    PlayerGameStats.goalserve_player_id == p["nba_player_id"],
                )

                stat_fields = {
                    "goalserve_player_id": p["nba_player_id"],
                    "goalserve_game_id": goalserve_game_id,
                    "player_id": player.id,
                    "nba_date": p["nba_date"],
                    "minutes_played": p["minutes_played"],
                    "did_not_play": p["did_not_play"],
                    "points": p["points"],
                    "rebounds": p["rebounds"],
                    "assists": p["assists"],
                    "steals": p["steals"],
                    "blocks": p["blocks"],
                    "turnovers": p["turnovers"],
                    "field_goals_made": p["field_goals_made"],
                    "field_goals_attempted": p["field_goals_attempted"],
                    "threepoint_made": p["threepoint_made"],
                    "threepoint_attempted": p["threepoint_attempted"],
                    "freethrow_made": p["freethrow_made"],
                    "freethrow_attempted": p["freethrow_attempted"],
                }

                if existing:
                    for k, v in stat_fields.items():
                        setattr(existing, k, v)
                    existing.score_computed = False  # will be recomputed
                    await existing.save()
                else:
                    await PlayerGameStats(**stat_fields).insert()

                count += 1
            except Exception as exc:
                logger.warning(
                    "Failed to upsert stats player=%s game=%s: %s",
                    p.get("nba_player_id"), goalserve_game_id, exc,
                )

        logger.info("Synced %d player-stat rows for game %s (NBA CDN)", count, goalserve_game_id)
        return count

    # ------------------------------------------------------------------
    # Scoring: compute fantasy scores for a game (called after final)
    # ------------------------------------------------------------------

    async def finalize_game_scores(self, goalserve_game_id: str) -> int:
        stats = await PlayerGameStats.find(
            PlayerGameStats.goalserve_game_id == goalserve_game_id,
            PlayerGameStats.score_computed == False,  # noqa: E712
        ).to_list()

        count = 0
        for s in stats:
            compute_and_stamp(s)
            await s.save()
            count += 1

        logger.info("Finalized %d fantasy scores for game %s", count, goalserve_game_id)
        return count

    # ------------------------------------------------------------------
    # Pricing: recompute all player prices (called after daily score finalize)
    # ------------------------------------------------------------------

    async def recompute_all_prices(self) -> int:
        today = datetime.now(timezone.utc).date()
        players = await Player.find(Player.is_active == True).to_list()  # noqa: E712
        count = 0
        for player in players:
            try:
                await recompute_player_price(player, today)
                await player.save()
                count += 1
            except Exception as exc:
                logger.warning("Price recompute failed player=%s: %s", player.id, exc)

        logger.info("Recomputed prices for %d players", count)
        return count

    # ------------------------------------------------------------------
    # Injury: NBA CDN doesn't have a free injury feed — mark manually or skip
    # ------------------------------------------------------------------

    async def sync_injury_report(self) -> int:
        """
        NBA CDN has no free injury feed.
        Injury status can be inferred from DNP in box-scores (did_not_play=True).
        This method is a no-op until Goalserve basketball subscription is activated.
        """
        logger.info("sync_injury_report: skipped (no free NBA injury feed; use Goalserve when subscribed)")
        return 0
