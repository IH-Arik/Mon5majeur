"""
CRON job definitions.

Schedule (all times are Europe/Paris):
  12:00  sync_today_schedule_job — fetch tonight's NBA games from Goalserve → NBAGame docs
  01:00–09:00 every 20 min — sync_live_games_job — pull box-scores for live/finished games
  09:00  daily_close_job  — score finalize → standings → price recompute
  09:05  weekly_monthly_rewards_job — Mon: Top-8 weekly bonus; 1st: monthly jersey winner
  09:10  cleanup_stale_leagues_job — delete leagues not started within 7 days
  19:00  reminder_job     — push "don't forget your team" to users who haven't submitted
"""
from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# 09:00 Paris — daily close (strict order: scores → standings → prices)
# ---------------------------------------------------------------------------

async def daily_close_job() -> None:
    from app.modules.leagues.engine import run_daily_close
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    today = datetime.now(timezone.utc).date()
    logger.info("CRON daily_close_job: starting for %s", today)

    try:
        # 1. Finalize all slot scores from PlayerGameStats
        from app.modules.lineups.service import LineupService
        from app.modules.bonuses.service import BonusService
        lineup_svc = LineupService(BonusService())

        filled = await lineup_svc.fill_slot_scores_from_stats(today)
        logger.info("CRON: filled %d slot scores", filled)

        finalized = await lineup_svc.finalize_lineup_scores(today)
        logger.info("CRON: finalized %d lineup total scores", finalized)

        # 2. Score matches + update standings + advance match days
        result = await run_daily_close(today)
        logger.info("CRON: league engine done: %s", result)

        # 3. Recompute player prices
        player_svc = PlayerService(PlayerRepository())
        price_count = await player_svc.recompute_all_prices()
        logger.info("CRON: recomputed %d player prices", price_count)

        # 4. Archive last night's Global League scores (feeds Weekly/Monthly rank)
        from app.modules.leagues.global_score_service import archive_daily_scores
        archived = await archive_daily_scores(today)
        logger.info("CRON: archived %d Global League daily scores", archived)

        # 5. Tell everyone the results are out (spec §4.8 notification 2).
        #    Last, and in its own try: results are already published by now,
        #    so a push failure must not fail the close.
        try:
            pushed = await _send_results_pushes(today)
            logger.info("CRON: sent %d results pushes", pushed)
        except Exception as exc:  # noqa: BLE001
            logger.error("CRON: results push failed: %s", exc, exc_info=True)

    except Exception as exc:
        logger.error("CRON daily_close_job failed: %s", exc, exc_info=True)


async def _send_results_pushes(night: date) -> int:
    """One "results are in" push per user for the night just closed.

    Spec §4.8 golden rule — never spoil: the message names the stake (the
    opponent, or that the standings moved) and never the score or who won.
    That is what protects the paid live-score feature.

    Private leagues take priority, and duel_contexts_for_night is keyed by
    user, so nobody receives two pushes for the same night.
    """
    from app.modules.notifications.duel_context import duel_contexts_for_night
    from app.modules.notifications.service import NotificationService

    duels = await duel_contexts_for_night(night)
    if not duels:
        return 0

    svc = NotificationService()
    sent = 0

    for user_id, duel in duels.items():
        if duel.is_private:
            body = f"🏀 Your duel vs {duel.opponent_name} is over — come see the result."
        else:
            body = "🏀 Standings updated — come see where you rank."

        await svc.send_push_to_user(
            user_id=user_id,
            title="Results are in",
            body=body,
            data={"type": "daily_results"},
            notification_type="daily_results",
        )
        sent += 1

    return sent


# ---------------------------------------------------------------------------
# 09:05 Paris — weekly/monthly Global League rewards (spec §4.6.1 / §5.2)
# Runs daily but only acts on the days the reset actually happens, right
# after daily_close_job has archived that night's scores.
# ---------------------------------------------------------------------------

async def weekly_monthly_rewards_job() -> None:
    from app.modules.leagues.global_score_service import (
        grant_monthly_winner_reward,
        grant_weekly_top8_reward,
    )

    today = datetime.now(timezone.utc).date()
    yesterday = today - timedelta(days=1)
    logger.info("CRON weekly_monthly_rewards_job: checking resets for %s", today)

    try:
        if today.weekday() == 0:  # Monday → the week ending yesterday (Sunday) just closed
            granted = await grant_weekly_top8_reward(yesterday)
            logger.info("CRON: granted weekly Top-8 reward to %d users", granted)

        if today.day == 1:  # 1st of month → the month ending yesterday just closed
            granted = await grant_monthly_winner_reward(yesterday)
            logger.info("CRON: recorded monthly winner (%d)", granted)

    except Exception as exc:
        logger.error("CRON weekly_monthly_rewards_job failed: %s", exc, exc_info=True)


# ---------------------------------------------------------------------------
# 19:00 Paris — reminder push
# ---------------------------------------------------------------------------

async def reminder_push_job() -> None:
    logger.info("CRON reminder_push_job: starting")
    try:
        await _send_reminder_pushes()
    except Exception as exc:
        logger.error("CRON reminder_push_job failed: %s", exc, exc_info=True)


async def _send_reminder_pushes() -> None:
    from app.modules.leagues.model import League, LeagueMembership
    from app.modules.lineups.compat_model import FlutterPlayerSelection
    from app.modules.notifications.duel_context import duel_contexts_for_night

    # NOTE: the team builder actually saves to FlutterPlayerSelection (the
    # Django-compat store keyed by league_auto_id + match_day), not
    # LineupSubmission — checking LineupSubmission here meant this reminder
    # fired for every user every night regardless of whether they'd already
    # set their team. See engine.py::score_match_day for the same root cause.
    active_leagues = await League.find(
        {"status": {"$in": ["regular_season", "playoffs"]}}  # "waiting" = no night to remind about yet
    ).to_list()

    # Opponent names for tonight, private leagues preferred (spec §4.8).
    night = await _nba_night_for_today()
    duels = await duel_contexts_for_night(night) if night else {}

    notified: set = set()

    for league in active_leagues:
        if league.auto_id is None:
            continue

        memberships = await LeagueMembership.find(
            LeagueMembership.league_id == league.id
        ).to_list()

        for m in memberships:
            if m.user_id in notified:
                continue

            already_submitted = await FlutterPlayerSelection.find_one(
                FlutterPlayerSelection.user_id == m.user_id,
                FlutterPlayerSelection.league_auto_id == league.auto_id,
                FlutterPlayerSelection.match_day == league.current_match_day,
            )

            if not already_submitted:
                await _send_fcm_reminder(m.user_id, duels.get(m.user_id))
                notified.add(m.user_id)


async def _nba_night_for_today():
    """Tonight's NBA date — the one the lock and the duels are keyed on.

    Grouped by Goalserve's own date rather than the Paris calendar day
    (spec §4.1): at 19:00 Paris the night's games are still ahead, and a
    naive `date.today()` would drift onto the wrong slate.
    """
    from app.modules.players.model import NBAGame

    game = await NBAGame.find().sort(-NBAGame.nba_date).first_or_none()
    if game is None:
        return None

    today = datetime.now(timezone.utc).date()
    # Only remind about a slate that has not been played yet.
    return game.nba_date if game.nba_date >= today else None


async def _send_fcm_reminder(user_id, duel=None) -> None:
    """Spec §4.8 notification 3 — the 19:00 composition reminder.

    Naming the opponent is the point: the tension is what makes the user
    open the app. It reveals no score, so the "never spoil" rule holds.
    """
    from app.modules.notifications.service import NotificationService

    if duel is not None and duel.is_private:
        title = "Don't forget your team!"
        body = (
            f"Tonight you face {duel.opponent_name}. "
            "Don't let them trash-talk you — set your lineup 🔥"
        )
    elif duel is not None:
        title = "Don't forget your team!"
        body = f"Tonight you face {duel.opponent_name} — set your lineup 🏀"
    else:
        # Global-League-only user: no duel to name.
        body = "Don't forget your lineup tonight 🏀"
        title = "Don't forget your team!"

    await NotificationService().send_push_to_user(
        user_id=user_id,
        title=title,
        body=body,
        data={"type": "team_reminder"},
    )


# ---------------------------------------------------------------------------
# 06:00 Paris — sync NBA player roster (daily, catches trades & signings)
# ---------------------------------------------------------------------------

async def cleanup_stale_leagues_job() -> None:
    """Delete private/public leagues the creator never started within 7 days
    (spec §4.6.2). Runs once a day, well clear of the scoring/close jobs."""
    from app.modules.leagues.engine import delete_stale_waiting_leagues

    logger.info("CRON cleanup_stale_leagues_job: checking for stale waiting leagues")
    try:
        deleted = await delete_stale_waiting_leagues()
        logger.info("CRON: deleted %d stale waiting league(s)", deleted)
    except Exception as exc:
        logger.error("CRON cleanup_stale_leagues_job failed: %s", exc, exc_info=True)


async def sync_player_roster_job() -> None:
    """
    Pull the full NBA playerIndex from NBA CDN and upsert into Player collection.
    Runs once a day at 06:00 Paris so roster changes (trades, signings, injuries)
    are reflected before the 12:00 schedule sync and evening games.
    """
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    logger.info("CRON sync_player_roster_job: fetching NBA CDN playerIndex")
    try:
        svc = PlayerService(PlayerRepository())
        count = await svc.sync_from_goalserve("nba")
        logger.info("CRON: synced %d players from NBA CDN playerIndex", count)
    except Exception as exc:
        logger.error("CRON sync_player_roster_job failed: %s", exc, exc_info=True)


# ---------------------------------------------------------------------------
# 12:00 Paris — sync today's NBA schedule from Goalserve
# ---------------------------------------------------------------------------

async def sync_today_schedule_job() -> None:
    """
    Fetch tonight's NBA game schedule from Goalserve (pre-game — games that
    haven't tipped off yet only show up in the schedule feed, not the scores
    feed sync_live_games_job uses later).
    """
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    logger.info("CRON sync_today_schedule_job: fetching today's NBA schedule")
    try:
        svc = PlayerService(PlayerRepository())
        count = await svc.sync_schedule(None)  # None → today (UTC)
        logger.info("CRON: synced %d games from Goalserve schedule", count)
    except Exception as exc:
        logger.error("CRON sync_today_schedule_job failed: %s", exc, exc_info=True)


# ---------------------------------------------------------------------------
# Every 20 min (01:00–09:00 Paris) — pull box-scores for live/finished games
# ---------------------------------------------------------------------------

async def sync_live_games_job() -> None:
    """
    Poll Goalserve for today's live/finished games (one call gets scores +
    full box score for every game on the date — see goalserve_client.py).
    For each finished game: compute fantasy scores.
    This feeds PlayerGameStats so that daily_close_job at 09:00 finds data ready.
    """
    from app.modules.players.model import NBAGame
    from app.modules.players.service import PlayerService
    from app.modules.players.repository import PlayerRepository

    today = datetime.now(timezone.utc).date()

    try:
        games = await NBAGame.find(NBAGame.nba_date == today).to_list()
        if not games:
            logger.debug("CRON sync_live_games_job: no games today, skipping")
            return

        # This job runs every minute (spec §4.5: premium live score refreshes
        # each minute), but Goalserve must only be called while a game is
        # actually in progress — "LIVE games only". A game is worth polling
        # when it is already live, or when it is scheduled and its tip-off
        # has passed (that is the call that flips it to live). Once every
        # game is final there is nothing left to learn until tomorrow.
        now = datetime.now(timezone.utc)

        def _worth_polling(g: NBAGame) -> bool:
            if g.status == "live":
                return True
            if g.status != "scheduled":
                return False
            # No tip-off time recorded → poll rather than risk missing the
            # start; a missing timestamp must not freeze the live score.
            if g.tip_off_time is None:
                return True
            tip = g.tip_off_time
            if tip.tzinfo is None:      # Mongo round-trips datetimes as naive UTC
                tip = tip.replace(tzinfo=timezone.utc)
            return now >= tip

        if not any(_worth_polling(g) for g in games):
            logger.debug(
                "CRON sync_live_games_job: no game in progress for %s, skipping poll", today
            )
            return

        logger.info("CRON sync_live_games_job: polling live games for %s", today)
        svc = PlayerService(PlayerRepository())

        # Scores + box score for every one of today's games that has
        # started — also updates each NBAGame's status/score in the process.
        synced = await svc.sync_scores_for_date(today)
        logger.info("CRON: synced %d player-stat rows for %s", synced, today)

        # Re-read: the sync above just advanced statuses (scheduled → live →
        # final), so the pre-poll copies are stale for the loop below.
        games = await NBAGame.find(NBAGame.nba_date == today).to_list()

        # Flip tonight's matches from upcoming -> live (feeds Night's Results
        # LIVE badge + Live Score; only the 09:00 close ever marks "completed")
        from app.modules.leagues.engine import sync_match_live_status
        flipped = await sync_match_live_status(today)
        if flipped:
            logger.info("CRON: marked %d matches live", flipped)

        for game in games:
            if game.status != "final":
                continue

            # Compute fantasy scores for this game's stats (idempotent)
            scored = await svc.finalize_game_scores(game.goalserve_id)
            if scored:
                logger.info(
                    "CRON: computed %d fantasy scores for finished game %s",
                    scored, game.goalserve_id,
                )

    except Exception as exc:
        logger.error("CRON sync_live_games_job failed: %s", exc, exc_info=True)
