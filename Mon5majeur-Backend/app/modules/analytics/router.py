"""
Admin dashboard — retention endpoints (lean spec, Season 1).

Every endpoint is superuser-only: these are founder-level business figures
(retention, activation, churn), not user-facing data.

`/overview` returns all five blocks in one call — the dashboard's default,
so a page load is one request instead of five. The per-block endpoints exist
for drilling in and for tuning a window without refetching everything.
"""
from fastapi import APIRouter, Depends, Query

from app.modules.analytics.schema import (
    ActivationResponse,
    CohortRetentionResponse,
    LineupVolumeResponse,
    PrivateLeaguePlayersResponse,
    RetentionOverviewResponse,
    TopBarCountersResponse,
)
from app.modules.analytics.service import RetentionAnalyticsService
from app.modules.auth.dependencies import get_current_superuser

router = APIRouter(
    prefix="/analytics/retention",
    tags=["Admin Dashboard — Retention"],
    dependencies=[Depends(get_current_superuser)],
)


def get_service() -> RetentionAnalyticsService:
    return RetentionAnalyticsService()


@router.get(
    "/overview",
    response_model=RetentionOverviewResponse,
    summary="All five dashboard blocks in one call",
)
async def overview(
    service: RetentionAnalyticsService = Depends(get_service),
) -> RetentionOverviewResponse:
    return await service.overview()


@router.get(
    "/counters",
    response_model=TopBarCountersResponse,
    summary="Block 1 — top-bar counters (downloads, DAU, DAU 7d, lineups tonight, deletions)",
)
async def counters(
    service: RetentionAnalyticsService = Depends(get_service),
) -> TopBarCountersResponse:
    return await service.top_bar_counters()


@router.get(
    "/cohorts",
    response_model=CohortRetentionResponse,
    summary="Block 2 — cohort retention grid (signup week x D1/D3/D7/D14/D30/D60/D90)",
)
async def cohorts(
    service: RetentionAnalyticsService = Depends(get_service),
) -> CohortRetentionResponse:
    return await service.cohort_retention()


@router.get(
    "/activation",
    response_model=ActivationResponse,
    summary="Block 3 — activation rate (share of signups who ever validated a lineup)",
)
async def activation(
    service: RetentionAnalyticsService = Depends(get_service),
) -> ActivationResponse:
    return await service.activation()


@router.get(
    "/lineup-volume",
    response_model=LineupVolumeResponse,
    summary="Block 4 — validated lineups per night over the last N match-nights",
)
async def lineup_volume(
    nights: int = Query(30, ge=1, le=120, description="How many match-nights back"),
    service: RetentionAnalyticsService = Depends(get_service),
) -> LineupVolumeResponse:
    return await service.lineup_volume(nights=nights)


@router.get(
    "/private-league-players",
    response_model=PrivateLeaguePlayersResponse,
    summary="Block 5 — headcount of players active in >=1 private league",
)
async def private_league_players(
    nights: int = Query(30, ge=1, le=120, description="How many match-nights back"),
    service: RetentionAnalyticsService = Depends(get_service),
) -> PrivateLeaguePlayersResponse:
    return await service.private_league_players(nights=nights)
