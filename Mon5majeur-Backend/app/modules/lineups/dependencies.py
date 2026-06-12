from fastapi import Depends

from app.modules.bonuses.service import BonusService
from app.modules.lineups.service import LineupService


def get_bonus_service() -> BonusService:
    return BonusService()


def get_lineup_service(
    bonus_service: BonusService = Depends(get_bonus_service),
) -> LineupService:
    return LineupService(bonus_service)
