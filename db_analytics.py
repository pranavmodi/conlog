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
                print(f"Transcript: {log.transcript}")
                print(f"Timestamp: {log.timestamp}")
                print(f"Metadata: {log.message_metadata}")
                print("-" * 50)
                
            print(f"\nTotal records: {len(logs)}")
            
        except Exception as e:
            print(f"Error fetching records: {str(e)}")

async def print_last_conversation():
    """Print the most recent conversation from the conversation_logs table."""
    async with AsyncSessionLocal() as db:
        try:
            query = select(ConversationLog).order_by(ConversationLog.timestamp.desc()).limit(1)
            result = await db.execute(query)
            log = result.scalar_one_or_none()
            
            if not log:
                print("No records found in the database.")
                return
            
            print("\nMost Recent Conversation:")
            print(f"ID: {log.id}")
            print(f"Conversation ID: {log.conversation_id}")
            print(f"User ID: {log.user_id}")
            print(f"Transcript: {log.transcript}")
            print(f"Timestamp: {log.timestamp}")
            print(f"Metadata: {log.message_metadata}")
            print("-" * 50)
            
        except Exception as e:
            print(f"Error fetching last conversation: {str(e)}")

async def main():
    # await print_all_rows()
    await print_last_conversation()

if __name__ == "__main__":
    asyncio.run(main())
