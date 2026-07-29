from datetime import date, datetime, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import BadRequestException, NotFoundException
from app.modules.leagues.constants import (
    GLOBAL_LEAGUE_BUDGET,
    LEAGUE_STATUS_WAITING,
    LEAGUE_TYPE_GLOBAL,
    LEAGUE_TYPE_PRIVATE,
    MATCH_DAYS_BY_SIZE,
)
from app.modules.leagues.model import League, LeagueMembership, LeagueMatch
from app.modules.leagues.repository import LeagueRepository, MatchRepository, MembershipRepository
from app.modules.leagues.schema import (
    CreateLeagueRequest,
    CreatePublicLeagueRequest,
    GlobalLeagueStatusResponse,
    JoinPrivateLeagueResponse,
    KickTeamCompatRequest,
    LeagueMatchResponse,
    LeagueResponse,
    MatchPairCompatResponse,
    MatchPlayerInfo,
    MyLeagueResponse,
    MyMatchTodayCompatResponse,
    PublicLeagueCompatResponse,
    TeamInfoResponse,
    UpdateLeagueCompatRequest,
)
from app.modules.users.model import User


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


async def _lineup_lock_info(
    user_id: PydanticObjectId, league_id: PydanticObjectId, today: date
) -> tuple[bool, int | None]:
    """(lineup_submitted, lock_in_seconds) for a user/league on `today`.

    Lock = earliest game tip-off for `today` (same rule LineupService enforces
    at submit time). lock_in_seconds contract: None = no game scheduled today
    (nothing to lock against), 0 = already locked, >0 = seconds until lock.
    """
    from app.modules.lineups.model import LineupSubmission
    from app.modules.players.model import NBAGame

    submission = await LineupSubmission.find_one(
        LineupSubmission.user_id == user_id,
        LineupSubmission.league_id == league_id,
        LineupSubmission.nba_date == today,
    )
    submitted = submission is not None

    earliest_game = await NBAGame.find(
        NBAGame.nba_date == today,
        NBAGame.tip_off_time != None,  # noqa: E711
    ).sort(+NBAGame.tip_off_time).first_or_none()

    lock_in_seconds: int | None = None
    if earliest_game and earliest_game.tip_off_time:
        now_utc = datetime.now(timezone.utc)
        tip_off = earliest_game.tip_off_time
        if tip_off.tzinfo is None:
            tip_off = tip_off.replace(tzinfo=timezone.utc)
        remaining = (tip_off - now_utc).total_seconds()
        lock_in_seconds = max(0, int(remaining))

    return submitted, lock_in_seconds


class LeagueService:
    def __init__(
        self,
        league_repo: LeagueRepository,
        membership_repo: MembershipRepository,
        match_repo: MatchRepository,
    ) -> None:
        self.league_repo = league_repo
        self.membership_repo = membership_repo
        self.match_repo = match_repo

    # ── Global League ─────────────────────────────────────────────────────────

    async def get_global_league_status(self, user: User) -> GlobalLeagueStatusResponse:
        league = await self.league_repo.get_global_league()
        if not league:
            return GlobalLeagueStatusResponse(joined=False)

        membership = await self.membership_repo.get_membership(league.id, user.id)
        return GlobalLeagueStatusResponse(
            joined=membership is not None,
            league_id=league.id,
            status=league.status,
            current_week=league.current_week,
            current_match_day=league.current_match_day,
        )

    async def join_global_league(self, user: User) -> LeagueResponse:
        league = await self.league_repo.get_global_league()
        if not league:
            # Auto-create the global league if it doesn't exist yet
            from app.database.counters import next_seq
            league = await League(
                name="NBA Global League",
                type=LEAGUE_TYPE_GLOBAL,
                budget=GLOBAL_LEAGUE_BUDGET,
                max_size=999999,
                status=LEAGUE_STATUS_WAITING,
            ).insert()
            league.auto_id = await next_seq("leagues")
            await league.save()

        existing = await self.membership_repo.get_membership(league.id, user.id)
        if existing:
            raise BadRequestException("Already joined the Global League")

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()
        await league.save_updated(current_size=league.current_size + 1)

        return LeagueResponse(
            id=league.id,
            name=league.name,
            type=league.type,
            status=league.status,
            budget=league.budget,
            max_size=league.max_size,
            current_size=league.current_size,
            invite_code=league.invite_code,
            current_match_day=league.current_match_day,
            current_week=league.current_week,
            total_match_days=league.total_match_days,
            started_at=league.started_at,
            created_at=league.created_at,
        )

    # ── Private / Public League ───────────────────────────────────────────────

    async def create_league(self, user: User, payload: CreateLeagueRequest) -> LeagueResponse:
        from app.database.counters import next_seq

        invite_code = None
        if payload.type == LEAGUE_TYPE_PRIVATE:
            invite_code = League.generate_invite_code()

        league = await League(
            name=payload.name,
            type=payload.type,
            budget=payload.budget,
            max_size=payload.max_size,
            invite_code=invite_code,
            admin_id=user.id,
            total_match_days=MATCH_DAYS_BY_SIZE.get(payload.max_size, 18),
            current_size=1,
        ).insert()

        league.auto_id = await next_seq("leagues")
        await league.save()

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()

        return self._to_response(league)

    async def join_by_invite_code(self, user: User, invite_code: str) -> LeagueResponse:
        invite_code = invite_code.strip().upper()
        league = await self.league_repo.get_by_invite_code(invite_code)
        if not league:
            raise NotFoundException("Invalid invite code")
        if league.status != LEAGUE_STATUS_WAITING:
            raise BadRequestException("This league has already started")
        if league.current_size >= league.max_size:
            raise BadRequestException("League is full")

        existing = await self.membership_repo.get_membership(league.id, user.id)
        if existing:
            raise BadRequestException("Already in this league")

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()
        await league.save_updated(current_size=league.current_size + 1)

        return self._to_response(league)

    async def join_public_league(self, user: User, league_id: PydanticObjectId) -> LeagueResponse:
        league = await self.league_repo.get(league_id)
        if not league or league.type != "public":
            raise NotFoundException("Public league not found")
        if league.status != LEAGUE_STATUS_WAITING:
            raise BadRequestException("This league has already started")
        if league.current_size >= league.max_size:
            raise BadRequestException("League is full")

        existing = await self.membership_repo.get_membership(league.id, user.id)
        if existing:
            raise BadRequestException("Already in this league")

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()
        await league.save_updated(current_size=league.current_size + 1)
        return self._to_response(league)

    # ── My Leagues ────────────────────────────────────────────────────────────

    async def get_my_leagues(self, user: User, search: str | None = None) -> list[MyLeagueResponse]:
        memberships = await self.membership_repo.get_user_memberships(user.id)
        if not memberships:
            return []

        league_ids = [m.league_id for m in memberships]
        membership_map = {m.league_id: m for m in memberships}

        leagues = await League.find({"_id": {"$in": league_ids}}).to_list()

        if search:
            q = search.lower()
            leagues = [l for l in leagues if q in l.name.lower()]

        result = []
        for league in leagues:
            m = membership_map[league.id]
            result.append(MyLeagueResponse(
                id=league.id,
                name=league.name,
                type=league.type,
                status=league.status,
                budget=league.budget,
                max_size=league.max_size,
                current_size=league.current_size,
                current_match_day=league.current_match_day,
                current_week=league.current_week,
                total_match_days=league.total_match_days,
                rank=m.rank,
                wins=m.wins,
                losses=m.losses,
                points_for=m.points_for,
                points_against=m.points_against,
            ))

        return result

    # ── My Matches Today ──────────────────────────────────────────────────────

    async def get_my_matches_today(self, user: User) -> list[LeagueMatchResponse]:
        today = date.today()
        matches = await self.match_repo.get_user_matches_today(user.id, today)
        if not matches:
            return []

        league_ids = list({m.league_id for m in matches})
        leagues = await League.find({"_id": {"$in": league_ids}}).to_list()
        league_map = {l.id: l for l in leagues}

        user_ids: set[PydanticObjectId] = set()
        for m in matches:
            user_ids.add(m.home_user_id)
            user_ids.add(m.away_user_id)

        from app.modules.users.model import User as UserModel
        users = await UserModel.find({"_id": {"$in": list(user_ids)}}).to_list()
        user_map = {u.id: u for u in users}

        result = []
        for match in matches:
            league = league_map.get(match.league_id)
            home_u = user_map.get(match.home_user_id)
            away_u = user_map.get(match.away_user_id)

            result.append(LeagueMatchResponse(
                id=match.id,
                league_id=match.league_id,
                league_name=league.name if league else "Unknown",
                match_day=match.match_day,
                nba_date=match.nba_date,
                status=match.status,
                home=MatchPlayerInfo(
                    user_id=match.home_user_id,
                    team_name=home_u.team_name if home_u else None,
                    team_logo=home_u.team_logo if home_u else None,
                ),
                away=MatchPlayerInfo(
                    user_id=match.away_user_id,
                    team_name=away_u.team_name if away_u else None,
                    team_logo=away_u.team_logo if away_u else None,
                ),
                home_score=match.home_score,
                away_score=match.away_score,
            ))

        return result

    # ── Public leagues list ───────────────────────────────────────────────────

    async def list_public_leagues(self, offset: int = 0, limit: int = 20) -> tuple[list[LeagueResponse], int]:
        query = League.find(League.type == "public", League.status == LEAGUE_STATUS_WAITING)
        total = await query.count()
        leagues = await query.skip(offset).limit(limit).to_list()
        return [self._to_response(l) for l in leagues], total

    async def get_join_screen(self) -> "JoinScreenResponse":
        from app.modules.leagues.schema import JoinScreenResponse, PublicLeagueListItem
        query = League.find(League.type == "public", League.status == LEAGUE_STATUS_WAITING)
        total = await query.count()
        preview = await query.limit(4).to_list()
        return JoinScreenResponse(
            public_leagues_preview=[
                PublicLeagueListItem(
                    id=l.id,
                    name=l.name,
                    current_size=l.current_size,
                    max_size=l.max_size,
                    budget=l.budget,
                    status=l.status,
                )
                for l in preview
            ],
            public_leagues_total=total,
        )

    # ── Waiting Room Detail ───────────────────────────────────────────────────

    async def get_league_detail(self, league_id: PydanticObjectId, user: User) -> "LeagueDetailResponse":
        from app.modules.leagues.schema import LeagueDetailResponse, TeamInfoResponse
        from app.modules.users.model import User as UserModel

        league = await self.league_repo.get(league_id)
        if not league:
            raise NotFoundException("League not found")

        # Verify user is a member (or superuser)
        if not user.is_superuser:
            membership = await self.membership_repo.get_membership(league_id, user.id)
            if not membership:
                raise NotFoundException("League not found")

        members = await self.membership_repo.get_league_members(league_id)
        user_ids = [m.user_id for m in members]
        users = await UserModel.find({"_id": {"$in": user_ids}}).to_list()
        user_map = {u.id: u for u in users}

        teams = [
            TeamInfoResponse(
                team_id=user_map[m.user_id].auto_id if m.user_id in user_map else None,
                team_name=user_map[m.user_id].team_name if m.user_id in user_map else None,
                team_logo=user_map[m.user_id].team_logo if m.user_id in user_map else None,
            )
            for m in members
        ]

        status = league.status
        return LeagueDetailResponse(
            id=str(league.id),
            leauge_name=league.name,
            leauge_description=league.description or "",
            leauge_logo=league.logo or "",
            team_budget=f"{league.budget}M",
            max_team_number=str(league.max_size),
            join_code=league.invite_code,
            creator=str(league.admin_id) if league.admin_id else None,
            current_match_day=league.current_match_day,
            is_ready=status != "waiting",
            is_started=status in ("regular_season", "playoffs"),
            is_active=status not in ("completed", "cancelled"),
            created_at=league.created_at,
            start_date=league.started_at,
            teams=teams,
        )

    # ── Leave League ──────────────────────────────────────────────────────────

    async def leave_league(self, league_id: PydanticObjectId, user: User) -> dict:
        league = await self.league_repo.get(league_id)
        if not league:
            raise NotFoundException("League not found")

        if league.status not in ("waiting",):
            raise BadRequestException("Cannot leave a league that has already started")

        membership = await self.membership_repo.get_membership(league_id, user.id)
        if not membership:
            raise BadRequestException("You are not a member of this league")

        if league.admin_id == user.id:
            raise BadRequestException("League creator cannot leave — delete the league instead")

        await membership.delete()
        await league.save_updated(current_size=max(0, league.current_size - 1))

        if league.auto_id:
            try:
                from app.modules.leagues.ws_router import emit_team_left
                await emit_team_left(
                    league_auto_id=league.auto_id,
                    team_id=None,
                    team_name=user.team_name or "",
                )
            except Exception:
                pass

        return {"detail": "Left the league successfully"}

    # ── Kick Member ───────────────────────────────────────────────────────────

    async def kick_member(
        self, league_id: PydanticObjectId, target_user_id: PydanticObjectId, requester: User
    ) -> dict:
        league = await self.league_repo.get(league_id)
        if not league:
            raise NotFoundException("League not found")

        # Only the league creator or a superuser can kick
        if not requester.is_superuser and league.admin_id != requester.id:
            from app.exceptions.errors import ForbiddenException
            raise ForbiddenException("Only the league creator can kick members")

        if league.status != "waiting":
            raise BadRequestException("Cannot kick members after the league has started")

        if target_user_id == league.admin_id:
            raise BadRequestException("Cannot kick the league creator")

        membership = await self.membership_repo.get_membership(league_id, target_user_id)
        if not membership:
            raise BadRequestException("User is not in this league")

        target_user = await User.get(target_user_id)
        await membership.delete()
        await league.save_updated(current_size=max(0, league.current_size - 1))

        if league.auto_id:
            try:
                from app.modules.leagues.ws_router import emit_team_kicked
                await emit_team_kicked(
                    league_auto_id=league.auto_id,
                    team_id=None,
                    team_name=target_user.team_name if target_user else "",
                )
            except Exception:
                pass

        return {"detail": "Member kicked successfully"}

    # ── Delete League ────────────────────────────────────────────────────────

    async def delete_league(self, league_id: PydanticObjectId, requester: User) -> None:
        league = await self.league_repo.get(league_id)
        if not league:
            raise NotFoundException("League not found")

        if not requester.is_superuser and league.admin_id != requester.id:
            from app.exceptions.errors import ForbiddenException
            raise ForbiddenException("Only the league creator can delete the league")

        if league.status not in ("waiting", "cancelled"):
            raise BadRequestException("Cannot delete a league that has already started")

        # Remove all memberships first
        await LeagueMembership.find(LeagueMembership.league_id == league_id).delete()
        await league.delete()

    # ── Start League (by creator) ─────────────────────────────────────────────

    async def start_league_by_creator(
        self, league_id: PydanticObjectId, requester: User
    ) -> dict:
        from datetime import datetime, timezone
        from app.modules.leagues.engine import start_league

        league = await self.league_repo.get(league_id)
        if not league:
            raise NotFoundException("League not found")

        if not requester.is_superuser and league.admin_id != requester.id:
            from app.exceptions.errors import ForbiddenException
            raise ForbiddenException("Only the league creator can start the league")

        members = await self.membership_repo.get_league_members(league_id)
        if len(members) < 2:
            raise BadRequestException("Need at least 2 members to start")

        today = datetime.now(timezone.utc).date()
        updated = await start_league(league_id, today)

        if updated.auto_id:
            try:
                from app.modules.leagues.ws_router import emit_league_started
                await emit_league_started(updated.auto_id)
            except Exception:
                pass

        return {
            "detail": f"League started. Total match days: {updated.total_match_days}",
            "current_match_day": updated.current_match_day,
            "total_match_days": updated.total_match_days,
        }

    # ── Django-compat: Public Leagues ─────────────────────────────────────────

    async def create_public_league_compat(
        self, user: User, payload: CreatePublicLeagueRequest
    ) -> PublicLeagueCompatResponse:
        from app.database.counters import next_seq

        budget = payload.budget_int if payload.budget_int in (80, 100) else 100
        max_size = payload.max_size_int if payload.max_size_int in (4, 6, 8, 10) else 10

        league = await League(
            name=payload.leauge_name,
            type="public",
            budget=budget,
            max_size=max_size,
            description=payload.leauge_description,
            logo=payload.leauge_logo,
            admin_id=user.id,
            total_match_days=MATCH_DAYS_BY_SIZE.get(max_size, 18),
            current_size=1,
        ).insert()

        league.auto_id = await next_seq("leagues")
        await league.save()

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()
        return await self._to_compat_response(league, [user])

    async def get_active_public_leagues_compat(self) -> list[PublicLeagueCompatResponse]:
        from app.modules.users.model import User as UserModel

        leagues = await League.find(
            League.type == "public",
            League.status == LEAGUE_STATUS_WAITING,
        ).to_list()

        result: list[PublicLeagueCompatResponse] = []
        for league in leagues:
            members = await self.membership_repo.get_league_members(league.id)
            user_ids = [m.user_id for m in members]
            users = await UserModel.find({"_id": {"$in": user_ids}}).to_list() if user_ids else []
            result.append(await self._to_compat_response(league, users))

        return result

    async def join_public_by_auto_id(self, user: User, auto_id: int) -> dict:
        from app.modules.leagues.ws_router import emit_team_joined

        league = await League.find_one(League.auto_id == auto_id)
        if not league or league.type != "public":
            raise NotFoundException("Public league not found")
        if league.status != LEAGUE_STATUS_WAITING:
            raise BadRequestException("This league has already started")
        if league.current_size >= league.max_size:
            raise BadRequestException("League is full")

        existing = await self.membership_repo.get_membership(league.id, user.id)
        if existing:
            raise BadRequestException("Already in this league")

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()
        await league.save_updated(current_size=league.current_size + 1)

        try:
            await emit_team_joined(
                league_auto_id=auto_id,
                team_id=user.auto_id,
                team_name=user.team_name or "",
                team_logo=user.team_logo or "",
                user_id=str(user.id),
            )
        except Exception:
            pass

        return {"detail": "Successfully joined the league."}

    async def get_public_league_by_auto_id(
        self, auto_id: int, user: User
    ) -> PublicLeagueCompatResponse:
        from app.modules.users.model import User as UserModel

        league = await League.find_one(League.auto_id == auto_id)
        if not league:
            raise NotFoundException("League not found")

        if not user.is_superuser:
            membership = await self.membership_repo.get_membership(league.id, user.id)
            if not membership:
                raise NotFoundException("League not found")

        members = await self.membership_repo.get_league_members(league.id)
        user_ids = [m.user_id for m in members]
        users = await UserModel.find({"_id": {"$in": user_ids}}).to_list() if user_ids else []
        return await self._to_compat_response(league, users)

    # ── My Leagues / Matches — compat ─────────────────────────────────────────

    async def get_my_leagues_compat(
        self, user: User, league_type: str | None = None
    ) -> list[PublicLeagueCompatResponse]:
        from app.modules.users.model import User as UserModel

        memberships = await self.membership_repo.get_user_memberships(user.id)
        if not memberships:
            return []

        league_ids = [m.league_id for m in memberships]
        query = League.find({"_id": {"$in": league_ids}})
        if league_type:
            query = League.find({"_id": {"$in": league_ids}, "type": league_type})

        leagues = await query.to_list()
        result: list[PublicLeagueCompatResponse] = []
        today = date.today()
        for league in leagues:
            members = await self.membership_repo.get_league_members(league.id)
            user_ids = [m.user_id for m in members]
            users = await UserModel.find({"_id": {"$in": user_ids}}).to_list() if user_ids else []
            compat = await self._to_compat_response(league, users)
            compat.lineup_submitted, compat.lock_in_seconds = await _lineup_lock_info(
                user.id, league.id, today
            )
            result.append(compat)
        return result

    async def get_my_matches_today_compat(self, user: User) -> list[MyMatchTodayCompatResponse]:
        from app.modules.live_scores.service import _is_premium
        from app.modules.users.model import User as UserModel

        today = date.today()
        has_live_access = _is_premium(user)

        matches = await self.match_repo.get_user_matches_today(user.id, today)
        # A live match this user can't watch live doesn't count as "today's
        # result" per spec — fall back to the last completed match instead.
        displayable = [m for m in matches if not (m.status == "live" and not has_live_access)]
        if not displayable:
            fallback = await self.match_repo.get_latest_completed_match(user.id)
            if fallback:
                displayable = [fallback]

        if not displayable:
            return []

        league_ids = list({m.league_id for m in displayable})
        leagues = await League.find({"_id": {"$in": league_ids}}).to_list()
        league_map = {l.id: l for l in leagues}

        user_ids: set = set()
        for m in displayable:
            user_ids.add(m.home_user_id)
            user_ids.add(m.away_user_id)
        users = await UserModel.find({"_id": {"$in": list(user_ids)}}).to_list()
        user_map = {u.id: u for u in users}

        result: list[MyMatchTodayCompatResponse] = []
        for match in displayable:
            league = league_map.get(match.league_id)
            home_u = user_map.get(match.home_user_id)
            away_u = user_map.get(match.away_user_id)
            pair = MatchPairCompatResponse(
                player_a_id=home_u.auto_id if home_u else None,
                player_a_name=home_u.team_name if home_u else None,
                player_b_id=away_u.auto_id if away_u else None,
                player_b_name=away_u.team_name if away_u else None,
                score_a=match.home_score or 0,
                score_b=match.away_score or 0,
            )
            is_live_for_user = match.status == "live" and has_live_access
            result.append(MyMatchTodayCompatResponse(
                id=match.auto_id or 0,
                league_id=(league.auto_id or 0) if league else 0,
                league_name=league.name if league else "",
                match_day=match.match_day,
                match_type="head_to_head",
                match_date=match.nba_date.isoformat(),
                status=match.status,
                player_scores=[],
                pairs=[pair],
                created_at=match.created_at.isoformat(),
                is_live_for_user=is_live_for_user,
                result_available=match.status in ("live", "completed"),
            ))
        return result

    # ── Internal ──────────────────────────────────────────────────────────────

    async def _to_compat_response(
        self, league: League, users: list
    ) -> PublicLeagueCompatResponse:
        from app.modules.users.model import User as UserModel

        user_map = {u.id: u for u in users}

        # Ensure admin user is in map (may not be in the passed-in users list)
        if league.admin_id and league.admin_id not in user_map:
            admin = await UserModel.get(league.admin_id)
            if admin:
                user_map[admin.id] = admin

        members = await self.membership_repo.get_league_members(league.id)
        teams = [
            TeamInfoResponse(
                team_id=user_map[m.user_id].auto_id if m.user_id in user_map else None,
                team_name=user_map[m.user_id].team_name if m.user_id in user_map else None,
                team_logo=user_map[m.user_id].team_logo if m.user_id in user_map else None,
            )
            for m in members
        ]

        # creator is the admin's auto_id (int) — Flutter compares against userProfile.id
        admin_auto_id: int | None = None
        if league.admin_id and league.admin_id in user_map:
            admin_auto_id = user_map[league.admin_id].auto_id

        status = league.status
        return PublicLeagueCompatResponse(
            id=league.auto_id,
            leauge_name=league.name,
            leauge_description=league.description or "",
            leauge_logo=league.logo or "",
            team_budget=f"{league.budget}M",
            max_team_number=str(league.max_size),
            join_code=league.invite_code,
            creator=admin_auto_id,
            current_match_day=league.current_match_day,
            is_ready=status != "waiting",
            is_started=status in ("regular_season", "playoffs"),
            is_active=status not in ("completed", "cancelled"),
            created_at=league.created_at,
            start_date=league.started_at,
            teams=teams,
        )

    # ── Django-compat: Private Leagues ───────────────────────────────────────

    async def create_private_league_compat(
        self, user: User, payload: CreatePublicLeagueRequest
    ) -> PublicLeagueCompatResponse:
        from app.database.counters import next_seq

        budget = payload.budget_int if payload.budget_int in (80, 100) else 100
        max_size = payload.max_size_int if payload.max_size_int in (4, 6, 8, 10) else 10
        invite_code = League.generate_invite_code()

        league = await League(
            name=payload.leauge_name,
            type=LEAGUE_TYPE_PRIVATE,
            budget=budget,
            max_size=max_size,
            invite_code=invite_code,
            description=payload.leauge_description,
            logo=payload.leauge_logo,
            admin_id=user.id,
            total_match_days=MATCH_DAYS_BY_SIZE.get(max_size, 18),
            current_size=1,
        ).insert()

        league.auto_id = await next_seq("leagues")
        await league.save()

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()
        return await self._to_compat_response(league, [user])

    async def get_private_league_by_auto_id(
        self, auto_id: int, user: User
    ) -> PublicLeagueCompatResponse:
        from app.modules.users.model import User as UserModel

        league = await League.find_one(League.auto_id == auto_id)
        if not league:
            raise NotFoundException("League not found")

        if not user.is_superuser:
            membership = await self.membership_repo.get_membership(league.id, user.id)
            if not membership:
                raise NotFoundException("League not found")

        members = await self.membership_repo.get_league_members(league.id)
        user_ids = [m.user_id for m in members]
        users = await UserModel.find({"_id": {"$in": user_ids}}).to_list() if user_ids else []
        return await self._to_compat_response(league, users)

    async def update_league_compat(
        self, auto_id: int, user: User, payload: UpdateLeagueCompatRequest
    ) -> PublicLeagueCompatResponse:
        from app.modules.users.model import User as UserModel

        league = await League.find_one(League.auto_id == auto_id)
        if not league:
            raise NotFoundException("League not found")

        if not user.is_superuser and league.admin_id != user.id:
            from app.exceptions.errors import ForbiddenException
            raise ForbiddenException("Only the league creator can update the league")

        if league.status != LEAGUE_STATUS_WAITING:
            raise BadRequestException("Cannot update a league that has already started")

        budget = payload.budget_int if payload.budget_int in (80, 100) else league.budget
        max_size = payload.max_size_int if payload.max_size_int in (4, 6, 8, 10) else league.max_size

        await league.save_updated(
            name=payload.leauge_name,
            logo=payload.leauge_logo,
            description=payload.leauge_description,
            budget=budget,
            max_size=max_size,
        )

        members = await self.membership_repo.get_league_members(league.id)
        user_ids = [m.user_id for m in members]
        users = await UserModel.find({"_id": {"$in": user_ids}}).to_list() if user_ids else []
        return await self._to_compat_response(league, users)

    async def delete_league_compat(self, auto_id: int, user: User) -> None:
        league = await League.find_one(League.auto_id == auto_id)
        if not league:
            raise NotFoundException("League not found")

        if not user.is_superuser and league.admin_id != user.id:
            from app.exceptions.errors import ForbiddenException
            raise ForbiddenException("Only the league creator can delete the league")

        if league.status not in ("waiting", "cancelled"):
            raise BadRequestException("Cannot delete a league that has already started")

        await LeagueMembership.find(LeagueMembership.league_id == league.id).delete()
        await league.delete()

    async def join_private_by_code(
        self, user: User, join_code: str
    ) -> JoinPrivateLeagueResponse:
        from app.modules.leagues.ws_router import emit_team_joined

        code = join_code.strip().upper()
        league = await self.league_repo.get_by_invite_code(code)
        if not league:
            raise NotFoundException("Invalid invite code")
        if league.status != LEAGUE_STATUS_WAITING:
            raise BadRequestException("This league has already started")
        if league.current_size >= league.max_size:
            raise BadRequestException("League is full")

        existing = await self.membership_repo.get_membership(league.id, user.id)
        if existing:
            raise BadRequestException("Already in this league")

        await LeagueMembership(league_id=league.id, user_id=user.id).insert()
        await league.save_updated(current_size=league.current_size + 1)

        if league.auto_id:
            try:
                await emit_team_joined(
                    league_auto_id=league.auto_id,
                    team_id=user.auto_id,
                    team_name=user.team_name or "",
                    team_logo=user.team_logo or "",
                    user_id=str(user.id),
                )
            except Exception:
                pass

        return JoinPrivateLeagueResponse(
            detail="Successfully joined the league.",
            league_id=league.auto_id,
        )

    async def kick_member_compat(
        self, payload: KickTeamCompatRequest, requester: User
    ) -> dict:
        from app.modules.users.model import User as UserModel

        league = await League.find_one(League.auto_id == payload.league_id)
        if not league:
            raise NotFoundException("League not found")

        if not requester.is_superuser and league.admin_id != requester.id:
            from app.exceptions.errors import ForbiddenException
            raise ForbiddenException("Only the league creator can kick members")

        if league.status != "waiting":
            raise BadRequestException("Cannot kick members after the league has started")

        target_user = await UserModel.find_one(UserModel.auto_id == payload.team_id)
        if not target_user:
            raise NotFoundException("User not found")

        if target_user.id == league.admin_id:
            raise BadRequestException("Cannot kick the league creator")

        membership = await self.membership_repo.get_membership(league.id, target_user.id)
        if not membership:
            raise BadRequestException("User is not in this league")

        await membership.delete()
        await league.save_updated(current_size=max(0, league.current_size - 1))

        if league.auto_id:
            try:
                from app.modules.leagues.ws_router import emit_team_kicked
                await emit_team_kicked(
                    league_auto_id=league.auto_id,
                    team_id=target_user.auto_id,
                    team_name=target_user.team_name or "",
                )
            except Exception:
                pass

        return {"detail": "Team kicked successfully"}

    async def start_league_compat(
        self, league_auto_id: int, requester: User
    ) -> dict:
        from datetime import datetime, timezone
        from app.modules.leagues.engine import start_league

        league = await League.find_one(League.auto_id == league_auto_id)
        if not league:
            raise NotFoundException("League not found")

        if not requester.is_superuser and league.admin_id != requester.id:
            from app.exceptions.errors import ForbiddenException
            raise ForbiddenException("Only the league creator can start the league")

        members = await self.membership_repo.get_league_members(league.id)
        if len(members) < 2:
            raise BadRequestException("Need at least 2 members to start")

        today = datetime.now(timezone.utc).date()
        updated = await start_league(league.id, today)

        if updated.auto_id:
            try:
                from app.modules.leagues.ws_router import emit_league_started
                await emit_league_started(updated.auto_id)
            except Exception:
                pass

        return {
            "detail": f"League started. Total match days: {updated.total_match_days}",
            "current_match_day": updated.current_match_day,
        }

    # ── Internal ──────────────────────────────────────────────────────────────

    def _to_response(self, league: League) -> LeagueResponse:
        return LeagueResponse(
            id=league.id,
            name=league.name,
            type=league.type,
            status=league.status,
            budget=league.budget,
            max_size=league.max_size,
            current_size=league.current_size,
            invite_code=league.invite_code,
            current_match_day=league.current_match_day,
            current_week=league.current_week,
            total_match_days=league.total_match_days,
            started_at=league.started_at,
            created_at=league.created_at,
        )
