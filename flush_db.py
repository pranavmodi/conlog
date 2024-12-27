import asyncio
from main import AsyncSessionLocal, ConversationLog

async def flush_database():
    """Utility function to flush all records from the conversation_logs table.
    This function should only be called from scripts, not exposed via API.
    """
    async with AsyncSessionLocal() as db:
        try:
            await db.execute(ConversationLog.__table__.delete())
            await db.commit()
            print("Database flushed successfully")
        except Exception as e:
            await db.rollback()
            print(f"Error flushing database: {str(e)}")
            raise e

async def main():
    await flush_database()

if __name__ == "__main__":
    asyncio.run(main())
