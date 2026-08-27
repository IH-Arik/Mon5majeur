from datetime import datetime, timedelta, timezone

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, Query

from app.exceptions.errors import BadRequestException
from app.modules.auth.dependencies import get_current_superuser, get_current_user
from app.modules.bonuses import catalog as bonus_catalog
from app.modules.tokens import catalog as token_pack_catalog
from app.modules.tokens.model import DAILY_VIDEO_REWARD, TokenWallet
from app.modules.tokens.schema import (
    AdminGrantRequest,
    IAPWebhookPayload,
    MockPurchaseRequest,
    TransactionResponse,
    WalletResponse,
)
from app.modules.tokens.service import TokenService
from app.modules.users.model import User

router = APIRouter(prefix="/tokens", tags=["Tokens"])

# Token rewards for game events
MATCH_WIN_REWARD = 10
LEAGUE_WIN_REWARD = 50


def get_token_service() -> TokenService:
    return TokenService()


@router.get("/wallet", response_model=WalletResponse, summary="Get my token balance")
async def my_wallet(
    user: User = Depends(get_current_user),
    service: TokenService = Depends(get_token_service),
) -> TokenWallet:
    return await service.get_wallet(user.id)


@router.get(
    "/history",
    response_model=list[TransactionResponse],
    summary="My token transaction history",
)
async def transaction_history(
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    service: TokenService = Depends(get_token_service),
) -> list:
    return await service.get_history(user.id, offset=offset, limit=limit)


@router.get(
    "/bonus-costs",
    summary="Token costs for each bonus (only active bonuses are included)",
)
async def bonus_costs(_=Depends(get_current_user)) -> dict:
    offers = await bonus_catalog.list_offers()
    return {o.slug: o.token_cost for o in offers if o.is_active}


@router.post(
    "/iap/webhook",
    summary="In-app purchase webhook (called by App Store / Play Store server)",
)
async def iap_webhook(
    payload: IAPWebhookPayload,
    service: TokenService = Depends(get_token_service),
) -> WalletResponse:
    wallet = await service.process_iap(
        PydanticObjectId(payload.user_id),
        payload.tokens_to_credit,
        payload.transaction_id,
        payload.platform,
    )
    return WalletResponse(user_id=wallet.user_id, balance=wallet.balance)


@router.post(
    "/mock-purchase/",
    response_model=WalletResponse,
    summary="TEMPORARY: instantly grant a token pack, no real payment (replace with IAP before launch)",
)
async def mock_purchase(
    payload: MockPurchaseRequest,
    user: User = Depends(get_current_user),
    service: TokenService = Depends(get_token_service),
) -> WalletResponse:
    tokens = await token_pack_catalog.get_active_token_amount(payload.pack)
    if tokens is None:
        raise BadRequestException(f"Token pack '{payload.pack}' is currently unavailable")

    wallet = await service.credit(
        user.id,
        tokens,
        tx_type="purchase",
        note=f"Mock purchase — {payload.pack} pack (no real payment taken)",
    )
    return WalletResponse(user_id=wallet.user_id, balance=wallet.balance)


@router.post(
    "/earn/daily-video/",
    response_model=WalletResponse,
    summary="Earn tokens by watching a rewarded ad (once per 24 h)",
)
async def earn_daily_video(
    user: User = Depends(get_current_user),
    service: TokenService = Depends(get_token_service),
) -> WalletResponse:
    now = datetime.now(timezone.utc)
    if user.last_daily_video_claim is not None:
        next_claim = user.last_daily_video_claim + timedelta(hours=24)
        if now < next_claim:
            seconds_left = int((next_claim - now).total_seconds())
            raise BadRequestException(
                f"Daily video already claimed. Try again in {seconds_left // 3600}h "
                f"{(seconds_left % 3600) // 60}m."
            )

    wallet = await service.credit(
        user.id,
        DAILY_VIDEO_REWARD,
        tx_type="earn_daily_video",
        note="Rewarded ad video",
    )
    await user.save_updated(last_daily_video_claim=now)
    return WalletResponse(user_id=wallet.user_id, balance=wallet.balance)


@router.post(
    "/admin/grant",
    summary="Admin: grant tokens to a user",
    dependencies=[Depends(get_current_superuser)],
)
async def admin_grant(
    payload: AdminGrantRequest,
    service: TokenService = Depends(get_token_service),
) -> WalletResponse:
    wallet = await service.credit(
        PydanticObjectId(payload.user_id),
        payload.tokens,
        tx_type="admin_grant",
        note=payload.note,
    )
    return WalletResponse(user_id=wallet.user_id, balance=wallet.balance)
