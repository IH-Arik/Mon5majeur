from __future__ import annotations

from datetime import date, datetime, timezone

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.exceptions.errors import ForbiddenException, NotFoundException
from app.modules.bonuses.service import BonusService
from app.modules.leagues.model import League, LeagueMembership
from app.modules.lineups.constants import (
    BASE_BUDGET,
    LUXURY_TAX_EXTRA,
    REQUIRED_SLOTS,
    SIXTH_MAN_MAX_PRICE,
    SIXTH_MAN_SLOT_NAME,
    SLOT_ALLOWED_POSITIONS,
)
from app.modules.lineups.model import LineupSlot, LineupSubmission
from app.modules.lineups.schema import (
    LineupSlotResponse,
    LineupSubmissionResponse,
    MyLineupTodayResponse,
    SubmitLineupRequest,
)
from app.modules.players.model import NBAGame, Player
from app.modules.users.model import User

logger = get_logger(__name__)

CHEF_CURRY_BONUS_PTS = 3.0


class LineupService:
    def __init__(self, bonus_service: BonusService) -> None:
        self.bonuses = bonus_service

    # ------------------------------------------------------------------
    # Submit / update lineup
    # ------------------------------------------------------------------

    async def submit_lineup(self, user: User, payload: SubmitLineupRequest) -> LineupSubmissionResponse:
        league_id = PydanticObjectId(payload.league_id)
        nba_date = payload.nba_date

        # 1. Verify league membership
        league = await League.get(league_id)
        if not league:
            raise NotFoundException("League not found")

        membership = await LeagueMembership.find_one(
            LeagueMembership.league_id == league_id,
            LeagueMembership.user_id == user.id,
        )
        if not membership:
            raise ForbiddenException("You are not a member of this league")

        # 2. Check lock — block ALL submissions once the night's first tip-off has passed
        #    Lock = earliest game tip-off for this NBA date (variable every day, spec §4.1)
        earliest_game = await NBAGame.find(
            NBAGame.nba_date == nba_date,
            NBAGame.tip_off_time != None,  # noqa: E711
        ).sort(+NBAGame.tip_off_time).first_or_none()

        now_utc = datetime.now(timezone.utc)
        if earliest_game and earliest_game.tip_off_time and now_utc >= earliest_game.tip_off_time:
            raise ForbiddenException("Night is locked — the first game has already tipped off")

        existing_sub = await LineupSubmission.find_one(
            LineupSubmission.user_id == user.id,
            LineupSubmission.league_id == league_id,
            LineupSubmission.nba_date == nba_date,
        )
        if existing_sub and existing_sub.is_locked:
            raise ForbiddenException("Lineup is locked — tip-off has started")

        # 3. Validate bonuses (server-side, all bonuses are one-use per season)
        if payload.luxury_tax:
            if not await self.bonuses.can_use(user.id, league_id, "luxury_tax"):
                raise ForbiddenException("Luxury Tax bonus already used in this league")
        if payload.chef_curry:
            if not await self.bonuses.can_use(user.id, league_id, "chef_curry"):
                raise ForbiddenException("Chef Curry bonus already used in this league")
        if payload.sixth_man:
            if not await self.bonuses.can_use(user.id, league_id, "sixth_man"):
                raise ForbiddenException("6th Man bonus already used in this league")

        # 4. Budget computation
        budget = BASE_BUDGET + (LUXURY_TAX_EXTRA if payload.luxury_tax else 0)

        # 5. Resolve and validate each slot
        slot_data: list[dict] = []
        total_price: float = 0.0
        player_ids_seen: set[str] = set()

        for slot_input in payload.slots:
            slot_name = slot_input.slot.upper()
            player = await Player.get(PydanticObjectId(slot_input.player_id))
            if not player:
                raise NotFoundException(f"Player {slot_input.player_id} not found")

            # Position must match slot family
            allowed = SLOT_ALLOWED_POSITIONS.get(slot_name, ())
            if player.position not in allowed:
                raise ForbiddenException(
                    f"Player {player.full_name} (position={player.position}) "
                    f"cannot play in slot {slot_name}"
                )

            # No duplicates
            pid_str = str(player.id)
            if pid_str in player_ids_seen:
                raise ForbiddenException(f"Player {player.full_name} is listed twice")
            player_ids_seen.add(pid_str)

            # Player must not be OUT
            if player.is_out:
                raise ForbiddenException(f"Player {player.full_name} is OUT and cannot be selected")

            # Player must have a game today
            games_today = await NBAGame.find(NBAGame.nba_date == nba_date).to_list()
            team_ids_playing = {g.home_team_id for g in games_today} | {g.away_team_id for g in games_today}
            if player.team_goalserve_id not in team_ids_playing:
                raise ForbiddenException(
                    f"Player {player.full_name}'s team has no game on {nba_date}"
                )

            # 6th Man price constraint: must be ≤ 8M
            if slot_name == SIXTH_MAN_SLOT_NAME and player.daily_price > SIXTH_MAN_MAX_PRICE:
                raise ForbiddenException(
                    f"6th Man player {player.full_name} costs {player.daily_price}M — "
                    f"must be ≤ {SIXTH_MAN_MAX_PRICE}M"
                )

            # 6th Man is out of budget — don't add to total_price
            if slot_name != SIXTH_MAN_SLOT_NAME:
                total_price += player.daily_price

            slot_data.append({
                "slot": slot_name,
                "player": player,
                "price": player.daily_price,
                "is_sixth_man": slot_name == SIXTH_MAN_SLOT_NAME,
            })

        # 6. Budget check (5 starters only — 6th Man is out of budget)
        if total_price > budget:
            raise ForbiddenException(
                f"Total price {total_price}M exceeds budget {budget}M"
            )

        # 8. Consume bonuses (persist to DB only after all validation passes)
        if payload.luxury_tax:
            await self.bonuses.consume(user.id, league_id, "luxury_tax")
        if payload.chef_curry:
            await self.bonuses.consume(user.id, league_id, "chef_curry")
        if payload.sixth_man:
            await self.bonuses.consume(user.id, league_id, "sixth_man")

        # 9. Delete existing slots for this submission (replace flow)
        if existing_sub:
            await LineupSlot.find(
                LineupSlot.user_id == user.id,
                LineupSlot.league_id == league_id,
                LineupSlot.nba_date == nba_date,
            ).delete()
            await existing_sub.delete()

        # 10. Persist submission header
        now = datetime.now(timezone.utc)
        submission = LineupSubmission(
            user_id=user.id,
            league_id=league_id,
            nba_date=nba_date,
            submitted_at=now,
            luxury_tax_used=payload.luxury_tax,
            chef_curry_used=payload.chef_curry,
            sixth_man_used=payload.sixth_man,
        )
        await submission.insert()

        # 11. Persist all slots (including 6th Man — all 6 saved to DB)
        saved_slots: list[LineupSlot] = []
        for entry in slot_data:
            p: Player = entry["player"]
            slot_doc = LineupSlot(
                user_id=user.id,
                league_id=league_id,
                nba_date=nba_date,
                slot=entry["slot"],
                player_id=p.id,
                player_goalserve_id=p.goalserve_id,
                player_name=p.full_name,
                player_position=p.position or "",
                player_price=entry["price"],
                is_sixth_man=entry["is_sixth_man"],
            )
            await slot_doc.insert()
            saved_slots.append(slot_doc)

        return _build_response(submission, saved_slots, total_price)

    # ------------------------------------------------------------------
    # Get my lineup today
    # ------------------------------------------------------------------

    async def get_my_lineup(
        self,
        user: User,
        league_id: PydanticObjectId,
        nba_date: date | None = None,
    ) -> MyLineupTodayResponse:
        today = nba_date or datetime.now(timezone.utc).date()

        league = await League.get(league_id)
        if not league:
            raise NotFoundException("League not found")

        quota = await self.bonuses.get_quota(user.id, league_id)
        budget = BASE_BUDGET + (LUXURY_TAX_EXTRA if not quota.luxury_tax_used else 0)

        submission = await LineupSubmission.find_one(
            LineupSubmission.user_id == user.id,
            LineupSubmission.league_id == league_id,
            LineupSubmission.nba_date == today,
        )

        if not submission:
            return MyLineupTodayResponse(
                submitted=False,
                budget_available=float(budget),
            )

        slots = await LineupSlot.find(
            LineupSlot.user_id == user.id,
            LineupSlot.league_id == league_id,
            LineupSlot.nba_date == today,
        ).to_list()

        total_price = sum(s.player_price for s in slots)
        response = _build_response(submission, slots, total_price)

        return MyLineupTodayResponse(
            submitted=True,
            lineup=response,
            budget_available=float(budget),
        )

    # ------------------------------------------------------------------
    # Lock lineups (called at tip-off / 09:00 CRON)
    # ------------------------------------------------------------------

    async def lock_lineups_for_date(self, nba_date: date) -> int:
        submissions = await LineupSubmission.find(
            LineupSubmission.nba_date == nba_date,
            LineupSubmission.is_locked == False,  # noqa: E712
        ).to_list()

        now = datetime.now(timezone.utc)
        count = 0
        for sub in submissions:
            sub.is_locked = True
            sub.locked_at = now
            await sub.save()
            count += 1

        logger.info("Locked %d lineups for %s", count, nba_date)
        return count

    # ------------------------------------------------------------------
    # Finalize scores (called after all games final for that date)
    # ------------------------------------------------------------------

    async def finalize_lineup_scores(self, nba_date: date) -> int:
        submissions = await LineupSubmission.find(
            LineupSubmission.nba_date == nba_date,
            LineupSubmission.score_finalized == False,  # noqa: E712
        ).to_list()

        count = 0
        for sub in submissions:
            slots = await LineupSlot.find(
                LineupSlot.user_id == sub.user_id,
                LineupSlot.league_id == sub.league_id,
                LineupSlot.nba_date == nba_date,
            ).to_list()

            all_final = all(s.score_finalized for s in slots)
            if not all_final:
                continue

            scores = [s.fantasy_score or 0.0 for s in slots]

            if sub.sixth_man_used:
                # 6th Man: keep top 5 of all 6 scores (spec §4.4)
                scores = sorted(scores, reverse=True)[:5]

            total = sum(scores)

            # Chef Curry: +3pts flat bonus to duel score (spec §4.4)
            if sub.chef_curry_used:
                total += CHEF_CURRY_BONUS_PTS

            sub.total_score = round(total, 2)
            sub.score_finalized = True
            await sub.save()
            count += 1

        logger.info("Finalized scores for %d lineups on %s", count, nba_date)
        return count

    # ------------------------------------------------------------------
    # Fill slot scores from PlayerGameStats (called after game finalize)
    # ------------------------------------------------------------------

    async def fill_slot_scores_from_stats(self, nba_date: date) -> int:
        from app.modules.players.model import PlayerGameStats

        slots = await LineupSlot.find(
            LineupSlot.nba_date == nba_date,
            LineupSlot.score_finalized == False,  # noqa: E712
        ).to_list()

        count = 0
        for slot in slots:
            stat = await PlayerGameStats.find_one(
                PlayerGameStats.player_id == slot.player_id,
                PlayerGameStats.nba_date == nba_date,
                PlayerGameStats.score_computed == True,  # noqa: E712
            )
            if not stat:
                continue
            slot.fantasy_score = stat.fantasy_score
            slot.score_finalized = True
            await slot.save()
            count += 1

        return count


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _build_response(
    sub: LineupSubmission,
    slots: list[LineupSlot],
    total_price: float,
) -> LineupSubmissionResponse:
    slot_responses = [
        LineupSlotResponse(
            id=s.id,
            slot=s.slot,
            player_id=s.player_id,
            player_name=s.player_name,
            player_position=s.player_position,
            player_price=s.player_price,
            fantasy_score=s.fantasy_score,
            score_finalized=s.score_finalized,
            is_sixth_man=s.is_sixth_man,
        )
        for s in slots
    ]
    return LineupSubmissionResponse(
        id=sub.id,
        user_id=sub.user_id,
        league_id=sub.league_id,
        nba_date=sub.nba_date,
        submitted_at=sub.submitted_at,
        is_locked=sub.is_locked,
        locked_at=sub.locked_at,
        total_score=sub.total_score,
        score_finalized=sub.score_finalized,
        luxury_tax_used=sub.luxury_tax_used,
        chef_curry_used=sub.chef_curry_used,
        sixth_man_used=sub.sixth_man_used,
        slots=slot_responses,
        total_price=round(total_price, 1),
    )
