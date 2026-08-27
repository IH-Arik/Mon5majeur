from __future__ import annotations

from beanie import PydanticObjectId

from app.core.logging import get_logger
from app.exceptions.errors import BadRequestException, NotFoundException
from app.modules.bonuses import catalog as bonus_catalog
from app.modules.tokens.model import TokenTransaction, TokenWallet

logger = get_logger(__name__)


class TokenService:

    async def get_wallet(self, user_id: PydanticObjectId) -> TokenWallet:
        wallet = await TokenWallet.find_one(TokenWallet.user_id == user_id)
        if not wallet:
            wallet = TokenWallet(user_id=user_id)
            await wallet.insert()
        return wallet

    async def get_balance(self, user_id: PydanticObjectId) -> int:
        wallet = await self.get_wallet(user_id)
        return wallet.balance

    async def credit(
        self,
        user_id: PydanticObjectId,
        amount: int,
        tx_type: str,
        reference_id: str | None = None,
        note: str | None = None,
    ) -> TokenWallet:
        wallet = await self.get_wallet(user_id)
        wallet.balance += amount
        await wallet.save()
        await TokenTransaction(
            user_id=user_id,
            amount=amount,
            balance_after=wallet.balance,
            type=tx_type,
            reference_id=reference_id,
            note=note,
        ).insert()
        logger.info("Credited %d tokens to user %s (type=%s)", amount, user_id, tx_type)
        return wallet

    async def debit(
        self,
        user_id: PydanticObjectId,
        amount: int,
        tx_type: str,
        reference_id: str | None = None,
        note: str | None = None,
    ) -> TokenWallet:
        wallet = await self.get_wallet(user_id)
        if wallet.balance < amount:
            raise BadRequestException(
                f"Insufficient tokens: have {wallet.balance}, need {amount}"
            )
        wallet.balance -= amount
        await wallet.save()
        await TokenTransaction(
            user_id=user_id,
            amount=-amount,
            balance_after=wallet.balance,
            type=tx_type,
            reference_id=reference_id,
            note=note,
        ).insert()
        logger.info("Debited %d tokens from user %s (type=%s)", amount, user_id, tx_type)
        return wallet

    async def spend_for_bonus(
        self, user_id: PydanticObjectId, bonus_slug: str
    ) -> TokenWallet:
        cost = await bonus_catalog.get_active_cost(bonus_slug)
        if cost is None:
            raise BadRequestException(f"Bonus '{bonus_slug}' is currently unavailable")
        return await self.debit(
            user_id,
            cost,
            tx_type="bonus_activation",
            reference_id=bonus_slug,
            note=f"Activated {bonus_slug} bonus",
        )

    async def process_iap(
        self,
        user_id: PydanticObjectId,
        tokens: int,
        transaction_id: str,
        platform: str,
    ) -> TokenWallet:
        # Idempotency: skip if transaction already processed
        existing = await TokenTransaction.find_one(
            TokenTransaction.reference_id == transaction_id
        )
        if existing:
            logger.info("IAP %s already processed — skipping", transaction_id)
            return await self.get_wallet(user_id)

        return await self.credit(
            user_id,
            tokens,
            tx_type="purchase",
            reference_id=transaction_id,
            note=f"IAP via {platform}",
        )

    async def get_history(
        self, user_id: PydanticObjectId, offset: int = 0, limit: int = 20
    ) -> list[TokenTransaction]:
        return (
            await TokenTransaction.find(TokenTransaction.user_id == user_id)
            .sort(-TokenTransaction.created_at)
            .skip(offset)
            .limit(limit)
            .to_list()
        )
