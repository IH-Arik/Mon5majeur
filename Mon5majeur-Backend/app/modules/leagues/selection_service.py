"""
Player selection service — handles save/load of Flutter Build-Your-Team selections
and builds match result responses for the Result tab.
Stored in `flutter_player_selections` collection keyed by (user_id, league_auto_id, match_day).
"""
from datetime import datetime, timezone

from beanie import PydanticObjectId

from app.exceptions.errors import NotFoundException
from app.modules.leagues.model import League, LeagueMatch
from app.modules.lineups.compat_model import FlutterPlayerSelection
from app.modules.users.model import User


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
    return {"selected_players": doc.selected_players if doc else []}


async def save_player_selection(
    league_auto_id: int,
    match_day: int,
    selected_players: list[dict],
    current_user: User,
) -> dict:
    league = await League.find_one(League.auto_id == league_auto_id)
    if not league:
        raise NotFoundException(f"League {league_auto_id} not found")

    now = datetime.now(timezone.utc)

    existing = await FlutterPlayerSelection.find_one(
        FlutterPlayerSelection.user_id == current_user.id,
        FlutterPlayerSelection.league_auto_id == league_auto_id,
        FlutterPlayerSelection.match_day == match_day,
    )
    if existing:
        existing.selected_players = selected_players
        existing.submitted_at = now
        await existing.save()
    else:
        await FlutterPlayerSelection(
            user_id=current_user.id,
            league_id=league.id,
            league_auto_id=league_auto_id,
            match_day=match_day,
            selected_players=selected_players,
            submitted_at=now,
        ).insert()

    match = await LeagueMatch.find_one(
        LeagueMatch.league_id == league.id,
        LeagueMatch.match_day == match_day,
    )
    match_id = (match.auto_id or 0) if match else 0

    used = sum(_parse_price(p.get("price", "0")) for p in selected_players)
    remaining = max(0.0, float(league.budget) - used)

    return {
        "match_id": match_id,
        "total_points": 0.0,
        "current_balance": round(remaining, 2),
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
            for p in sel_doc.selected_players:
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
                total += fscore
                selection_items.append({
                    "id": pid_str,
                    "name": p.get("name", ""),
                    "position": p.get("position", ""),
                    "score": fscore,
                })

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
