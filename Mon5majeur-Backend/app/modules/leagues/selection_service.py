"""
Player selection service — handles save/load of Flutter Build-Your-Team selections
and builds match result responses for the Result tab.
Stored in `flutter_player_selections` collection keyed by (user_id, league_auto_id, match_day).
"""
from datetime import date, datetime, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import ForbiddenException, NotFoundException
from app.modules.leagues.model import League, LeagueMatch
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.users.model import User


async def _score_one_player(raw_id, nba_date: date) -> float:
    from app.modules.players.model import PlayerGameStats

    if not raw_id:
        return 0.0
    try:
        player_id = PydanticObjectId(str(raw_id))
    except Exception:
        return 0.0
    stat = await PlayerGameStats.find_one(
        PlayerGameStats.player_id == player_id,
        PlayerGameStats.nba_date == nba_date,
        PlayerGameStats.score_computed == True,  # noqa: E712
    )
    return stat.fantasy_score if stat and stat.fantasy_score is not None else 0.0


async def score_selection_for_date(selected_players: list[dict], nba_date: date) -> float:
    """Sum a Flutter selection's real Fantasy Score for `nba_date` from
    PlayerGameStats. Shared by duel scoring (engine.py) and the Result tab
    (get_match_result) so both agree on the same number for the same night."""
    total = 0.0
    for p in selected_players:
        total += await _score_one_player(p.get("id"), nba_date)
    return round(total, 2)


async def score_full_selection(sel: FlutterPlayerSelection, nba_date: date) -> float:
    """Duel score including strategic bonuses (spec §4.4):
    6th Man = top 5 of 6 (starters + the 6th man, best 5 counted);
    Chef Curry = +3 applied after summing the 5 counted scores.
    Luxury Tax doesn't appear here — it only affects the selection budget."""
    scores = [await _score_one_player(p.get("id"), nba_date) for p in sel.selected_players]

    if sel.sixth_man_player is not None:
        scores.append(await _score_one_player(sel.sixth_man_player.get("id"), nba_date))
        scores = sorted(scores, reverse=True)[:5]

    total = sum(scores)
    if sel.chef_curry:
        total += 3
    return round(total, 2)


async def _lock_in_seconds(league_auto_id: int, match_day: int) -> int | None:
    """Seconds until this match day's lock (earliest tip-off for its NBA
    date). None = no scheduled match/game for this day, 0 = already locked,
    >0 = seconds until lock. Same lock rule as the Global League/private
    lineup submission."""
    from app.modules.players.model import NBAGame

    league = await League.find_one(League.auto_id == league_auto_id)
    if not league:
        return None

    match = await LeagueMatch.find_one(
        LeagueMatch.league_id == league.id,
        LeagueMatch.match_day == match_day,
    )
    if not match:
        return None

    earliest_game = await NBAGame.find(
        NBAGame.nba_date == match.nba_date,
        NBAGame.tip_off_time != None,  # noqa: E711
    ).sort(+NBAGame.tip_off_time).first_or_none()
    if not earliest_game or not earliest_game.tip_off_time:
        return None

    now_utc = datetime.now(timezone.utc)
    tip_off = earliest_game.tip_off_time
    if tip_off.tzinfo is None:
        tip_off = tip_off.replace(tzinfo=timezone.utc)
    remaining = (tip_off - now_utc).total_seconds()
    return max(0, int(remaining))


async def get_player_selection(
    league_auto_id: int,
    match_day: int,
    current_user: User,
) -> dict:
    doc = await FlutterPlayerSelection.find_one(
        FlutterPlayerSelection.user_id == current_user.id,
        FlutterPlayerSelection.league_auto_id == league_auto_id,
        FlutterPlayerSelection.match_day == match_day,
    )
    lock_in_seconds = await _lock_in_seconds(league_auto_id, match_day)
    return {
        "selected_players": doc.selected_players if doc else [],
        "lock_in_seconds": lock_in_seconds,
        "luxury_tax": doc.luxury_tax if doc else False,
        "chef_curry": doc.chef_curry if doc else False,
        "sixth_man_player": doc.sixth_man_player if doc else None,
    }


_BACKCOURT = {"PG", "SG", "G"}
_WING = {"SF", "PF", "F"}


async def _validate_selection(selected_players: list[dict], nba_date: date | None) -> None:
    """Spec §4.1 validation rules 1-4 (budget/lock are handled separately by
    the caller). Rejects with ForbiddenException on the first violation."""
    from app.modules.players.model import NBAGame, Player

    if len(selected_players) != 5:
        raise ForbiddenException(f"Exactly 5 players required — got {len(selected_players)}")

    raw_ids = [p.get("id") for p in selected_players]
    if any(not rid for rid in raw_ids):
        raise ForbiddenException("Each selected player must have an id")
    if len(set(raw_ids)) != 5:
        raise ForbiddenException("A player can only be selected once")

    players: list[Player] = []
    for rid in raw_ids:
        try:
            player = await Player.get(PydanticObjectId(str(rid)))
        except Exception:
            player = None
        if not player:
            raise ForbiddenException(f"Player {rid} not found")
        players.append(player)

    # 2 backcourt (PG/SG) + 2 wings (SF/PF) + 1 center — order-independent,
    # since the Flutter payload doesn't carry explicit slot names.
    backcourt = sum(1 for p in players if p.position in _BACKCOURT)
    wing = sum(1 for p in players if p.position in _WING)
    center = sum(1 for p in players if p.position == "C")
    if (backcourt, wing, center) != (2, 2, 1):
        raise ForbiddenException(
            "Lineup must be 2 backcourt (PG/SG) + 2 wings (SF/PF) + 1 center"
        )

    if nba_date is not None:
        games_tonight = await NBAGame.find(NBAGame.nba_date == nba_date).to_list()
        team_ids_playing = {g.home_team_id for g in games_tonight} | {
            g.away_team_id for g in games_tonight
        }
        for p in players:
            if p.team_goalserve_id not in team_ids_playing:
                raise ForbiddenException(f"{p.full_name} does not play tonight")
            if p.is_out:
                raise ForbiddenException(f"{p.full_name} is OUT and cannot be selected")


async def get_bonus_availability(league_auto_id: int, current_user: User) -> dict:
    """Combined free-quota + purchased-charge count per bonus for the
    team-builder UI (spec §4.4). The free quota (1-3 uses, sized by league
    size) is otherwise invisible to the app — it only ever showed purchased
    charges from /api/bonuses/my-inventory/, so a user with free uses left
    but zero purchased charges saw "0" and the UI silently refused to even
    try activating the bonus."""
    from app.modules.bonuses.service import BonusService

    league = await League.find_one(League.auto_id == league_auto_id)
    if not league:
        raise NotFoundException(f"League {league_auto_id} not found")

    status = await BonusService().get_status(current_user.id, league.id)
    return {
        bonus: data["free_remaining"] + data["purchased_charges"]
        for bonus, data in status.items()
    }


async def _sync_bonus(
    current_user: User,
    league_id,
    bonus: str,
    was_active: bool,
    now_active: bool,
) -> None:
    """Consume on False→True, refund on True→False. No-op if unchanged.
    Duel leagues only — the Global League never passes bonus flags."""
    from app.modules.bonuses.service import BonusService

    if was_active == now_active:
        return

    svc = BonusService()
    if now_active:
        if not await svc.can_use(current_user.id, league_id, bonus):
            raise ForbiddenException(
                f"No {bonus.replace('_', ' ')} uses left (free quota and purchased charges both exhausted)"
            )
        await svc.consume(current_user.id, league_id, bonus)
    else:
        await svc.refund(current_user.id, league_id, bonus)


async def save_player_selection(
    league_auto_id: int,
    match_day: int,
    selected_players: list[dict],
    current_user: User,
    luxury_tax: bool = False,
    chef_curry: bool = False,
    sixth_man_player: dict | None = None,
) -> dict:
    league = await League.find_one(League.auto_id == league_auto_id)
    if not league:
        raise NotFoundException(f"League {league_auto_id} not found")

    lock_in_seconds = await _lock_in_seconds(league_auto_id, match_day)
    if lock_in_seconds == 0:
        raise ForbiddenException(
            "Night is locked — the first game has already tipped off"
        )

    match = await LeagueMatch.find_one(
        LeagueMatch.league_id == league.id,
        LeagueMatch.match_day == match_day,
    )
    await _validate_selection(selected_players, match.nba_date if match else None)

    if sixth_man_player is not None:
        try:
            sixth_man_price = _parse_price(sixth_man_player.get("price", "0"))
        except Exception:
            sixth_man_price = 0.0
        if sixth_man_price > 8:
            raise ForbiddenException(
                f"6th Man player costs {sixth_man_price}M — must be ≤ 8M"
            )

    now = datetime.now(timezone.utc)

    existing = await FlutterPlayerSelection.find_one(
        FlutterPlayerSelection.user_id == current_user.id,
        FlutterPlayerSelection.league_auto_id == league_auto_id,
        FlutterPlayerSelection.match_day == match_day,
    )

    # Only the Global League's own endpoint calls this without bonus support
    # (private/public leagues only) — this module is duel-leagues-only, so
    # bonus quota is always checked/consumed here.
    await _sync_bonus(current_user, league.id, "luxury_tax", existing.luxury_tax if existing else False, luxury_tax)
    await _sync_bonus(current_user, league.id, "chef_curry", existing.chef_curry if existing else False, chef_curry)
    await _sync_bonus(
        current_user, league.id, "sixth_man",
        existing.sixth_man_player is not None if existing else False,
        sixth_man_player is not None,
    )

    # Budget check (spec §4.1/§4.4): Luxury Tax adds +5M before validating.
    effective_budget = float(league.budget) + (5.0 if luxury_tax else 0.0)
    used = sum(_parse_price(p.get("price", "0")) for p in selected_players)
    if used > effective_budget:
        raise ForbiddenException(
            f"Total price {used}M exceeds budget {effective_budget}M"
        )

    if existing:
        existing.selected_players = selected_players
        existing.submitted_at = now
        existing.luxury_tax = luxury_tax
        existing.chef_curry = chef_curry
        existing.sixth_man_player = sixth_man_player
        await existing.save()
    else:
        await FlutterPlayerSelection(
            user_id=current_user.id,
            league_id=league.id,
            league_auto_id=league_auto_id,
            match_day=match_day,
            selected_players=selected_players,
            submitted_at=now,
            luxury_tax=luxury_tax,
            chef_curry=chef_curry,
            sixth_man_player=sixth_man_player,
        ).insert()

    match_id = (match.auto_id or 0) if match else 0

    remaining = max(0.0, effective_budget - used)

    return {
        "match_id": match_id,
        "total_points": 0.0,
        "current_balance": round(remaining, 2),
        "lock_in_seconds": lock_in_seconds,
    }


def _parse_price(price_raw) -> float:
    try:
        return float(str(price_raw).replace("M", "").strip())
    except (ValueError, TypeError):
        return 0.0


# ── Match Result ──────────────────────────────────────────────────────────────

_STATUS_MAP = {"upcoming": "scheduled", "live": "live", "completed": "completed"}


async def get_match_result(league_auto_id: int, match_day: int) -> dict:
    from app.modules.players.model import PlayerGameStats

    league = await League.find_one(League.auto_id == league_auto_id)
    if not league:
        raise NotFoundException(f"League {league_auto_id} not found")

    matches = await LeagueMatch.find(
        LeagueMatch.league_id == league.id,
        LeagueMatch.match_day == match_day,
    ).to_list()
    if not matches:
        raise NotFoundException(f"No matches for league {league_auto_id} match day {match_day}")

    # Overall status
    raw_statuses = {m.status for m in matches}
    if "live" in raw_statuses:
        overall_status = "live"
    elif all(s == "completed" for s in raw_statuses):
        overall_status = "completed"
    else:
        overall_status = "scheduled"

    nba_date = matches[0].nba_date

    # Collect all participant user ObjectIds
    all_user_oids = set()
    for m in matches:
        all_user_oids.add(m.home_user_id)
        all_user_oids.add(m.away_user_id)

    users = await User.find({"_id": {"$in": list(all_user_oids)}}).to_list()
    user_map = {u.id: u for u in users}

    # Build per-user score data
    user_totals: dict = {}       # user ObjectId → total points (int)
    player_scores: list[dict] = []

    for user_oid in all_user_oids:
        user = user_map.get(user_oid)
        if not user:
            continue

        sel_doc = await FlutterPlayerSelection.find_one(
            FlutterPlayerSelection.user_id == user_oid,
            FlutterPlayerSelection.league_auto_id == league_auto_id,
            FlutterPlayerSelection.match_day == match_day,
        )

        selection_items: list[dict] = []
        total = 0

        if sel_doc:
            all_players = list(sel_doc.selected_players)
            if sel_doc.sixth_man_player is not None:
                all_players.append(sel_doc.sixth_man_player)

            for p in all_players:
                fscore = 0
                pid_str = p.get("id", "")
                try:
                    player_oid = PydanticObjectId(pid_str)
                    stats = await PlayerGameStats.find_one(
                        PlayerGameStats.player_id == player_oid,
                        PlayerGameStats.nba_date == nba_date,
                        PlayerGameStats.score_computed == True,  # noqa: E712
                    )
                    if stats and stats.fantasy_score is not None:
                        fscore = int(round(stats.fantasy_score))
                except Exception:
                    pass
                selection_items.append({
                    "id": pid_str,
                    "name": p.get("name", ""),
                    "position": p.get("position", ""),
                    "score": fscore,
                })

            # Authoritative total: same bonus-aware calculation that decides
            # the duel (score_full_selection) — top-5-of-6 + Chef Curry, not
            # a plain sum of the list above (which may include a dropped 6th
            # Man score, shown for transparency but not counted).
            total = int(round(await score_full_selection(sel_doc, nba_date)))

        user_totals[user_oid] = total
        display_name = user.team_name or (user.email.split("@")[0] if user.email else "Unknown")
        player_scores.append({
            "player_id": user.auto_id or 0,
            "team_name": display_name,
            "username": user.full_name or display_name,
            "total_points": total,
            "selection": selection_items,
        })

    # Build pairs from each LeagueMatch
    pairs: list[dict] = []
    for m in matches:
        hu = user_map.get(m.home_user_id)
        au = user_map.get(m.away_user_id)
        h_name = (hu.team_name if hu else None) or (hu.email.split("@")[0] if hu and hu.email else "Team A")
        a_name = (au.team_name if au else None) or (au.email.split("@")[0] if au and au.email else "Team B")

        score_a = user_totals.get(m.home_user_id, int(m.home_score or 0))
        score_b = user_totals.get(m.away_user_id, int(m.away_score or 0))

        pairs.append({
            "player_a_id": hu.auto_id or 0 if hu else 0,
            "player_a_name": h_name,
            "player_b_id": au.auto_id or 0 if au else 0,
            "player_b_name": a_name,
            "score_a": score_a,
            "score_b": score_b,
            "match_object_id": str(m.id),
        })

    first = matches[0]
    return {
        "id": first.auto_id or 0,
        "league_id": league_auto_id,
        "league_name": league.name,
        "match_day": match_day,
        "match_type": "head_to_head",
        "match_date": str(nba_date),
        "status": overall_status,
        "player_scores": player_scores,
        "pairs": pairs,
        "created_at": first.created_at.isoformat(),
    }
