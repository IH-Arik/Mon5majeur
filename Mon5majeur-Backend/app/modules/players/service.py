from __future__ import annotations

from datetime import date, datetime, timezone

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.exceptions.errors import NotFoundException
from app.modules.players.form_indicator import compute_and_store_form_indicators
from app.modules.players.model import NBAGame, Player, PlayerGameStats
from app.modules.players.nba_cdn import fetch_player_index
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
    # NBA CDN roster (best-effort) — no Goalserve roster/squad feed is
    # reachable on this account (see goalserve_client.py's module docstring),
    # and cdn.nba.com itself blocks most requests with an intermittent 403.
    # This exists only to catch a brand-new signee/rookie BEFORE their first
    # tracked game — sync_scores_for_date creates/matches players from actual
    # box scores regardless, which is the reliable path for anyone who's
    # played at least once.
    # ------------------------------------------------------------------

    async def sync_from_goalserve(self, league: str = "nba") -> int:
        """Fetch current NBA roster from NBA CDN playerIndex (best-effort)."""
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
    # Goalserve: sync schedule (any date, incl. upcoming — nba-shedule feed)
    # ------------------------------------------------------------------

    async def sync_schedule(self, nba_date: date | None = None) -> int:
        """Sync the game schedule for one date (defaults to today UTC)."""
        from app.modules.players.goalserve_client import fetch_schedule_for_date

        target_date = nba_date or datetime.now(timezone.utc).date()
        try:
            games_data = await fetch_schedule_for_date(target_date)
        except Exception as exc:
            logger.error("Goalserve schedule fetch failed: %s", exc)
            return 0

        count = 0
        for g in games_data:
            try:
                existing = await NBAGame.find_one(NBAGame.goalserve_id == g["goalserve_game_id"])
                game_doc = {
                    "goalserve_id": g["goalserve_game_id"],
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
                logger.warning("Failed to upsert game %s: %s", g.get("goalserve_game_id"), exc)

        logger.info("Synced %d games from Goalserve for %s", count, target_date)
        return count

    # ------------------------------------------------------------------
    # Goalserve: sync scores + full box score for a date, in one call
    # ------------------------------------------------------------------

    async def sync_scores_for_date(self, nba_date: date) -> int:
        """Fetch scores + box score for every game on `nba_date` and upsert
        NBAGame + PlayerGameStats. Also resolves each player against the
        Player collection by full name (there's no Goalserve roster/squad
        feed available on this account — see goalserve_client.py) — on a
        match, backfills that Player's goalserve_id/team_goalserve_id from
        this NBA-CDN-sourced legacy value to Goalserve's own IDs so future
        lookups are a direct id match; unmatched players get a new minimal
        Player record."""
        from app.modules.players.goalserve_client import fetch_scores_for_date

        try:
            games_data = await fetch_scores_for_date(nba_date)
        except Exception as exc:
            logger.error("Goalserve scores fetch failed for %s: %s", nba_date, exc)
            return 0

        count = 0
        for g in games_data:
            game_id = g["goalserve_game_id"]
            try:
                existing_game = await NBAGame.find_one(NBAGame.goalserve_id == game_id)
                game_doc = {
                    "goalserve_id": game_id,
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
                if existing_game:
                    for k, v in game_doc.items():
                        if k != "goalserve_id" and v is not None:
                            setattr(existing_game, k, v)
                    await existing_game.save()
                else:
                    await NBAGame(**game_doc).insert()
            except Exception as exc:
                logger.warning("Failed to upsert game %s: %s", game_id, exc)

            for p in g["players"]:
                try:
                    player = await self._resolve_goalserve_player(p)
                    if not player:
                        continue

                    existing_stat = await PlayerGameStats.find_one(
                        PlayerGameStats.goalserve_game_id == game_id,
                        PlayerGameStats.goalserve_player_id == p["goalserve_player_id"],
                    )
                    stat_fields = {
                        "goalserve_player_id": p["goalserve_player_id"],
                        "goalserve_game_id": game_id,
                        "player_id": player.id,
                        "nba_date": g["nba_date"],
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

                    if existing_stat:
                        for k, v in stat_fields.items():
                            setattr(existing_stat, k, v)
                        existing_stat.score_computed = False  # will be recomputed
                        await existing_stat.save()
                    else:
                        await PlayerGameStats(**stat_fields).insert()

                    count += 1
                except Exception as exc:
                    logger.warning(
                        "Failed to upsert stats player=%s game=%s: %s",
                        p.get("goalserve_player_id"), game_id, exc,
                    )

        logger.info("Synced %d player-stat rows from Goalserve for %s", count, nba_date)
        return count

    async def _resolve_goalserve_player(self, p: dict) -> Player | None:
        """Match a Goalserve box-score player entry to our Player collection
        by full name — the only identity signal we have without a roster
        feed. On match, backfill goalserve_id/team_goalserve_id (still
        holding NBA-CDN-era values) to Goalserve's own IDs. No match creates
        a new minimal Player record from the box-score data alone."""
        full_name = p["full_name"].strip()
        if not full_name:
            return None

        player = await Player.find_one(Player.full_name == full_name)
        if player:
            if player.goalserve_id != p["goalserve_player_id"] or player.team_goalserve_id != p["team_goalserve_id"]:
                player.goalserve_id = p["goalserve_player_id"]
                player.team_goalserve_id = p["team_goalserve_id"]
                await player.save()
            return player

        name_parts = full_name.split(" ", 1)
        try:
            return await Player(
                goalserve_id=p["goalserve_player_id"],
                first_name=name_parts[0],
                last_name=name_parts[1] if len(name_parts) > 1 else "",
                full_name=full_name,
                position=p["position"] or None,
                team_goalserve_id=p["team_goalserve_id"],
            ).insert()
        except Exception as exc:
            # goalserve_id is unique — a race with another sync could collide
            logger.warning("Could not create new Player for %s: %s", full_name, exc)
            return await Player.find_one(Player.goalserve_id == p["goalserve_player_id"])

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

        # Form indicator (spec Part 1 §4.0) — same cron pass, no separate
        # job. Must run after prices/avgs above so it reads today's fresh
        # PlayerGameStats state, though it recomputes its own averages
        # independently (plain means, not the weighted pricing average).
        try:
            form_updated = await compute_and_store_form_indicators(today)
            logger.info("Updated form indicator for %d players", form_updated)
        except Exception as exc:
            logger.warning("Form indicator recompute failed: %s", exc, exc_info=True)

        return count

    # ------------------------------------------------------------------
    # Injury: NBA CDN doesn't have a free injury feed — mark manually or skip
    # ------------------------------------------------------------------

    async def set_player_availability(
        self, player: Player, is_out: bool, reason: str | None = None
    ) -> bool:
        """Single entry point for flipping a player's IN/OUT status.

        Every injury source — the Goalserve feed once subscribed, or an admin
        marking a player by hand — must go through here, because the spec's
        "notify the users holding him" rule (§4.7 point 3) hangs off the
        IN → OUT *transition*, not off the status itself. Writing `is_out`
        directly would silently skip the alert.

        Returns True if the status actually changed.
        """
        if player.is_out == is_out:
            # Re-listed active, or still out for the same reason: no
            # transition, so no push. §4.7 "last known status wins".
            if is_out and reason and player.out_reason != reason:
                await player.save_updated(out_reason=reason)
            return False

        await player.save_updated(is_out=is_out, out_reason=reason if is_out else None)

        if is_out:
            from app.modules.notifications.service import NotificationService

            # Never let a notification failure undo an availability update —
            # a player wrongly left selectable is the worse outcome.
            try:
                await NotificationService().notify_player_out(
                    player_id=player.id,
                    player_name=player.full_name,
                    reason=reason or "Sidelined",
                )
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "notify_player_out failed for %s: %s", player.full_name, exc, exc_info=True
                )

        return True

    async def sync_injury_report(self) -> int:
        """
        NBA CDN has no free injury feed.
        Injury status can be inferred from DNP in box-scores (did_not_play=True).
        This method is a no-op until Goalserve basketball subscription is activated.

        When that feed is wired, map it per §4.7 (OUT_KEYWORDS against the
        report's `description`) and apply each result through
        set_player_availability() — that is what sends the "your player is
        OUT" push. Do not set `is_out` directly.
        """
        logger.info("sync_injury_report: skipped (no free NBA injury feed; use Goalserve when subscribed)")
        return 0
