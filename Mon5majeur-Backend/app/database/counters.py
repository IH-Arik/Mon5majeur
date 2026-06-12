from pymongo import ReturnDocument


async def next_seq(name: str) -> int:
    """
    Atomic auto-increment counter backed by the `counters` MongoDB collection.
    Returns the next integer value for the named sequence.
    """
    from app.modules.leagues.model import League  # lazy import to avoid circular deps

    db = League.get_motor_collection().database
    result = await db.counters.find_one_and_update(
        {"_id": name},
        {"$inc": {"seq": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    return int(result["seq"])
