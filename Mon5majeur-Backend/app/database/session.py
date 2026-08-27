from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import settings

_client: AsyncIOMotorClient | None = None


def get_motor_client() -> AsyncIOMotorClient:
    global _client
    if _client is None:
        _client = AsyncIOMotorClient(settings.MONGODB_URI)
    return _client


async def init_db() -> None:
    from app.modules.analytics.model import AccountDeletionLog
    from app.modules.auth.model import OTPToken, RefreshToken
    from app.modules.bonuses.model import BonusOffer, UserBonusInventory, UserBonusQuota
    from app.modules.competitions.model import Competition, CompetitionEntry
    from app.modules.content.model import ContentPageDoc, FaqEntryDoc
    from app.modules.fantasy_teams.model import FantasyTeam
    from app.modules.files.model import UploadedFile
    from app.modules.leagues.global_score_model import GlobalLeagueDailyScore
    from app.modules.leagues.model import League, LeagueMembership, LeagueMatch
    from app.modules.leagues.playoff_model import PlayoffSeries
    from app.modules.leagues.reward_model import GlobalLeagueReward
    from app.modules.lineups.compat_model import FlutterPlayerSelection
    from app.modules.lineups.model import LineupSlot, LineupSubmission
    from app.modules.notifications.model import Notification
    from app.modules.permissions.model import Permission
    from app.modules.players.model import NBAGame, Player, PlayerGameStats
    from app.modules.roles.model import Role
    from app.modules.tokens.model import TokenPack, TokenTransaction, TokenWallet
    from app.modules.users.model import User

    client = get_motor_client()
    await init_beanie(
        database=client[settings.MONGODB_DB_NAME],
        document_models=[
            User,
            OTPToken,
            RefreshToken,
            Role,
            Permission,
            Player,
            PlayerGameStats,
            NBAGame,
            FantasyTeam,
            Competition,
            CompetitionEntry,
            Notification,
            UploadedFile,
            League,
            LeagueMembership,
            LeagueMatch,
            PlayoffSeries,
            LineupSlot,
            LineupSubmission,
            FlutterPlayerSelection,
            GlobalLeagueDailyScore,
            GlobalLeagueReward,
            UserBonusQuota,
            UserBonusInventory,
            BonusOffer,
            TokenWallet,
            TokenTransaction,
            TokenPack,
            AccountDeletionLog,
            ContentPageDoc,
            FaqEntryDoc,
        ],
    )


async def close_db() -> None:
    global _client
    if _client:
        _client.close()
        _client = None
