import asyncio
from sqlalchemy import select
from main import AsyncSessionLocal, ConversationLog

async def print_all_rows():
    """Print all rows from the conversation_logs table."""
    async with AsyncSessionLocal() as db:
        try:
            query = select(ConversationLog).order_by(ConversationLog.timestamp.desc())
            result = await db.execute(query)
            logs = result.scalars().all()
            
            if not logs:
                print("No records found in the database.")
                return
            
            for log in logs:
                print(f"\nID: {log.id}")
                print(f"Conversation ID: {log.conversation_id}")
                print(f"User ID: {log.user_id}")
                print(f"Message: {log.message}")
                print(f"Timestamp: {log.timestamp}")
                print(f"Metadata: {log.message_metadata}")
                print("-" * 50)
                
            print(f"\nTotal records: {len(logs)}")
            
        except Exception as e:
            print(f"Error fetching records: {str(e)}")

async def main():
    await print_all_rows()

if __name__ == "__main__":
    asyncio.run(main())
