import asyncio
import argparse
from sqlalchemy import select, func
from main import AsyncSessionLocal, ConversationLog
from datetime import datetime, timedelta

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

async def print_weekly_conversation_count():
    """Print a table showing the number of conversations in the past 7 days."""
    async with AsyncSessionLocal() as db:
        try:
            # Calculate the date 7 days ago
            seven_days_ago = datetime.now() - timedelta(days=7)
            
            # Query to count conversations per day in the last 7 days
            query = select(
                func.date(ConversationLog.timestamp).label('date'),
                func.count().label('count')
            ).where(
                ConversationLog.timestamp >= seven_days_ago
            ).group_by(
                func.date(ConversationLog.timestamp)
            ).order_by(
                func.date(ConversationLog.timestamp).desc()
            )
            
            result = await db.execute(query)
            daily_counts = result.all()
            
            if not daily_counts:
                print("\nNo conversations found in the past 7 days.")
                return
            
            print("\nConversation Count - Last 7 Days:")
            print("-" * 40)
            print(f"{'Date':<20} {'Count':>10}")
            print("-" * 40)
            
            total_count = 0
            for date, count in daily_counts:
                print(f"{date.strftime('%Y-%m-%d'):<20} {count:>10}")
                total_count += count
            
            print("-" * 40)
            print(f"{'Total':<20} {total_count:>10}")
            
        except Exception as e:
            print(f"Error fetching weekly conversation count: {str(e)}")

async def main():
    parser = argparse.ArgumentParser(description='Database analytics tool for conversation logs')
    parser.add_argument('mode', choices=['all', 'last', 'weekly'],
                       help='Select analysis mode: all (print all rows), last (print last conversation), weekly (print weekly stats)')
    
    args = parser.parse_args()
    
    if args.mode == 'all':
        await print_all_rows()
    elif args.mode == 'last':
        await print_last_conversation()
    elif args.mode == 'weekly':
        await print_weekly_conversation_count()

if __name__ == "__main__":
    asyncio.run(main())
