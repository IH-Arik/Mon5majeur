from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import ForbiddenException, NotFoundException
from app.modules.bonuses.live_access import sync_live_scoring
from app.modules.leagues.model import League, LeagueMatch
from app.modules.leagues.substitution import ENTERED, best_five_flags
from app.modules.leagues.substitution_service import describe, did_not_play_ids, resolve_substitution
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
    premium_until = user.premium_until
    if premium_until.tzinfo is None:  # MongoDB round-trips datetimes as naive UTC
        premium_until = premium_until.replace(tzinfo=timezone.utc)
    return premium_until > datetime.now(timezone.utc)


async def _ensure_premium(user: User) -> None:
    # The Shop's Live Scoring expiry lives on the bonus inventory; if it is
    # ahead of premium_until, catch up before refusing (QA 24/09 #6).
    if not _is_premium(user):
        await sync_live_scoring(user)
    if not _is_premium(user):
        raise ForbiddenException("Live scores require a premium subscription")


def _logo_of(user) -> str:
    """The team's saved avatar; "" when there is none or no user (never null)."""
    return (user.team_logo or "") if user else ""


class LiveScoreService:

    async def get_premium_status(self, user: User) -> PremiumStatusResponse:
        if not _is_premium(user):
            await sync_live_scoring(user)
        return PremiumStatusResponse(
            is_premium=_is_premium(user),
            premium_until=user.premium_until,
        )

    async def get_live_match(
        self, user: User, match_id: PydanticObjectId
    ) -> LiveMatchScore:
        await _ensure_premium(user)

        match = await LeagueMatch.get(match_id)
        if not match:
            raise NotFoundException("Match not found")

        # The live tab of a duel league shows EVERY match of the league
        # (QA #9 12.1): a participant, or any member of the same league.
        if user.id not in (match.home_user_id, match.away_user_id):
            from app.modules.leagues.model import LeagueMembership

            member = await LeagueMembership.find_one(
                LeagueMembership.league_id == match.league_id,
                LeagueMembership.user_id == user.id,
            )
            if member is None:
                raise ForbiddenException("You are not in this match")

        league = await League.get(match.league_id)

        # An opponent's Chef Curry (+3 from the first point) would give his
        # bonus away before the 09:00 reveal, so it is left out of the score
        # shown for any team that is not the viewer's own; the published
        # result adds it. (QA #9 10.1 point of attention.)
        # An opponent's substitute is lineup information: shown only once the
        # night has started (first tip-off), like the rest of the lineup on the
        # Result page. A team's own substitute is always shown to its owner.
        started = match.status in ("live", "completed")
        if not started and league is not None:
            from app.modules.leagues.selection_service import _lock_in_seconds

            started = await _lock_in_seconds(league.auto_id, match.match_day) == 0

        home_players, home_score, home_sub, home_state = await _get_live_players_for_user(
            match.home_user_id, league, match.match_day, match.nba_date,
            show_chef_curry=user.id == match.home_user_id,
            show_substitute=started or user.id == match.home_user_id,
        )
        away_players, away_score, away_sub, away_state = await _get_live_players_for_user(
            match.away_user_id, league, match.match_day, match.nba_date,
            show_chef_curry=user.id == match.away_user_id,
            show_substitute=started or user.id == match.away_user_id,
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
            home_jersey_index=home_user.jersey_index if home_user else 0,
            away_jersey_index=away_user.jersey_index if away_user else 0,
            home_team_logo=_logo_of(home_user),
            away_team_logo=_logo_of(away_user),
            home_score=round(home_score, 2),
            away_score=round(away_score, 2),
            match_status=match.status,
            has_live_games=await _showing_night(match.nba_date),
            home_players=home_players,
            away_players=away_players,
            home_substitute=home_sub,
            away_substitute=away_sub,
            home_substitution=home_state,
            away_substitution=away_state,
            is_stale=await _is_stale_for_date(match.nba_date),
            refreshed_at=datetime.now(timezone.utc),
        )

    async def get_global_live(self, user: User) -> LiveGlobalScore:
        """Live score for the user's Global League selection (spec §4.5:
        live score must also cover the Global League, not just duel leagues).
        No opponent, no bonuses — the Global League has neither."""
        await _ensure_premium(user)

        from app.modules.players.compat_router import _nba_today

        league = await League.find_one(League.type == "global")
        if not league:
            raise NotFoundException("Global league not found")

        # The night Live is still showing (it may be yesterday's date after
        # 00:00 UTC: QA #10 19 - the screen looked at the next date and said
        # "no live match" while games were being played).
        from app.modules.players.nba_night import live_night

        today = await live_night() or await _nba_today()

        # The lineup that is PLAYING that night: the selection stamped with its
        # date, else the one of the current match day.
        from app.modules.lineups.compat_model import FlutterPlayerSelection

        sel = await FlutterPlayerSelection.find_one(
            FlutterPlayerSelection.user_id == user.id,
            FlutterPlayerSelection.league_auto_id == league.auto_id,
            FlutterPlayerSelection.nba_date == today,
        ) or await _get_selection(user.id, league, league.current_match_day)

        if not sel:
            return LiveGlobalScore(
                league_id=league.id,
                league_name=league.name,
                total_score=0.0,
                players=[],
                has_live_games=await _showing_night(today),
                is_stale=False,
                refreshed_at=datetime.now(timezone.utc),
            )

        players, total, substitute, substitution = await _live_lineup(
            sel, today, user.id, flag_did_not_play=True
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
            substitute=substitute,
            substitution=substitution,
            has_live_games=await _showing_night(today),
            is_stale=await _is_stale_for_date(today),
            refreshed_at=datetime.now(timezone.utc),
        )

    async def grant_premium(self, user: User, days: int) -> User:
        """Admin: extend premium_until by N days."""
        now = datetime.now(timezone.utc)
        existing = user.premium_until
        if existing is not None and existing.tzinfo is None:  # naive after Mongo round-trip
            existing = existing.replace(tzinfo=timezone.utc)
        base = max(existing or now, now)
        user.premium_until = base + timedelta(days=days)
        await user.save()
        await sync_live_scoring(user)  # Shop shows the same expiry
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


async def _live_lineup(sel, nba_date: date, user_id=None, flag_did_not_play: bool = False):
    """Live players, total, substitute and substitution state of one lineup.
    The substitute only comes in once every game of the lineup is final.
    flag_did_not_play: every starter who played no minute once his own game is
    final is flagged absent too (Global League and duels)."""
    substitute_player = getattr(sel, "substitute_player", None)
    result = None
    if substitute_player is not None:
        result = await resolve_substitution(
            sel.selected_players, substitute_player, nba_date, closing=False, user_id=user_id
        )
    players, total, substitute = await _build_live_players(
        sel.selected_players, sel.sixth_man_player, nba_date, substitute_player, result
    )
    if flag_did_not_play:
        starters = [p for p in players if p.slot == "STARTER"]
        gone = await did_not_play_ids(
            [{"id": str(p.player_id)} for p in starters], nba_date, closing=False
        )
        for p in starters:
            if str(p.player_id) in gone:
                p.is_absent = True
    return players, total, substitute, describe(result) if result is not None else None


async def _get_live_players_for_user(
    user_id: PydanticObjectId,
    league: League | None,
    match_day: int,
    nba_date: date,
    show_chef_curry: bool = True,
    show_substitute: bool = True,
) -> tuple[list[LivePlayerScore], float, LivePlayerScore | None, dict | None]:
    """A duel-league participant's live players + bonus-aware total, read
    from FlutterPlayerSelection — the store the team builder actually saves
    to (LineupSubmission/LineupSlot is a separate, unused system; reading
    from there meant this endpoint always returned an empty lineup)."""
    if league is None:
        return [], 0.0, None, None

    sel = await _get_selection(user_id, league, match_day)
    if not sel:
        return [], 0.0, None, None  # forfeit — no lineup submitted (spec §4.1)

    players, total, substitute, substitution = await _live_lineup(
        sel, nba_date, user_id, flag_did_not_play=True
    )
    if sel.chef_curry and show_chef_curry:
        total += 3
    if not show_substitute:
        substitute = substitution = None
    return players, total, substitute, substitution


async def _build_live_players(
    selected_players: list[dict],
    sixth_man_player: dict | None,
    nba_date: date,
    substitute_player: dict | None = None,
    substitution=None,
) -> tuple[list[LivePlayerScore], float, LivePlayerScore | None]:
    """Build live per-player scores; if a 6th Man is present, mark the top 5
    of 6 as counted (spec §4.4) and sum only those into the total.

    With a substitute that has come in (``substitution`` ENTERED), the replaced
    starter stays listed but absent and uncounted, and the substitute's score
    takes his place before the 6th Man rule keeps the best 5 of 6. The
    substitute is returned apart, so the list keeps its usual five or six."""
    all_players = list(selected_players)
    sixth_index = None
    if sixth_man_player is not None:
        sixth_index = len(all_players)
        all_players = all_players + [sixth_man_player]

    async def _entry(idx: int, p: dict, slot: str) -> dict | None:
        raw_id = p.get("id")
        try:
            player_id = PydanticObjectId(str(raw_id))
        except Exception:
            return None

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

        return {
            "player_id": player_id,
            "full_name": p.get("name") or (player_doc.full_name if player_doc else ""),
            "position": p.get("position") or (player_doc.position if player_doc else None),
            "team_name": player_doc.team_name if player_doc else None,
            "slot": slot,
            "points": stat.points if stat else 0,
            "rebounds": stat.rebounds if stat else 0,
            "assists": stat.assists if stat else 0,
            "steals": stat.steals if stat else 0,
            "blocks": stat.blocks if stat else 0,
            "turnovers": stat.turnovers if stat else 0,
            "minutes_played": stat.minutes_played if stat else 0,
            "fantasy_score_live": round(live_score, 2),
            "is_finalized": is_final,
        }

    entries: list[dict] = []
    for idx, p in enumerate(all_players):
        entry = await _entry(idx, p, "SIXTH_MAN" if idx == sixth_index else "STARTER")
        if entry is not None:
            entries.append(entry)

    sub_entry = (
        await _entry(len(all_players), substitute_player, "SUBSTITUTE")
        if substitute_player is not None else None
    )

    # score each slot counts with: the replaced starter's slot takes the
    # substitute's score once he has come in
    scores = [e["fantasy_score_live"] for e in entries]
    replaced_idx = None
    if substitution is not None and substitution.status == ENTERED and sub_entry is not None:
        gone = str(substitution.replaced.get("id", ""))
        for i, e in enumerate(entries):
            if e["slot"] == "STARTER" and str(e["player_id"]) == gone:
                replaced_idx = i
                scores[i] = sub_entry["fantasy_score_live"]
                break

    if sixth_index is not None and len(entries) == 6:
        counted = {i for i, kept in enumerate(best_five_flags(scores)) if kept}
    else:
        counted = set(range(len(entries)))

    total = 0.0
    result: list[LivePlayerScore] = []
    for i, e in enumerate(entries):
        is_counted = i in counted and i != replaced_idx
        if i in counted:
            total += scores[i]
        result.append(LivePlayerScore(is_counted=is_counted, is_absent=i == replaced_idx, **e))

    substitute = None
    if sub_entry is not None:
        substitute = LivePlayerScore(
            is_counted=replaced_idx is not None and replaced_idx in counted, **sub_entry
        )
    return result, total, substitute


async def _showing_night(nba_date: date) -> bool:
    """True while Live still has this night to show (until the 09:00 Paris
    publication), not only while a game is on the court."""
    from app.modules.players.nba_night import live_night

    return await live_night() == nba_date


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
