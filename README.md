# Botpress Conversation Logger

A FastAPI backend service for collecting and storing conversation logs from Botpress chatbots.

## Features
- RESTful API endpoints for receiving conversation logs
- PostgreSQL storage for conversation history
- Async database operations
- Input validation using Pydantic models
- Error handling and logging

## Technical Stack
- FastAPI
- PostgreSQL
- SQLAlchemy (async)
- Pydantic
- Python 3.9+
- Developed on a macbook air, and hosted on a centos linux server

## API Endpoints
- POST /api/conversations - Store new conversation logs
- GET /api/conversations - Retrieve conversation history

## Database Analytics
The project includes a database analytics script (`db_analytics.py`) that provides useful insights into your conversation logs.

### Running the Analytics Script
```bash
python db_analytics.py
```

### Available Functions

1. `print_all_rows()`
   - Displays all conversation logs in the database
   - Shows ID, conversation ID, user ID, transcript, timestamp, and metadata
   - Ordered by most recent first

2. `print_last_conversation()`
   - Shows details of the most recent conversation
   - Useful for quick verification of new entries

3. `print_weekly_conversation_count()`
   - Displays a table of conversation counts for the past 7 days
   - Shows daily breakdown and total count
   - Formatted in an easy-to-read table

### Example Usage

To use specific functions, modify the `main()` function in `db_analytics.py`:

```python
async def main():
    # Print all conversations in the database
    await print_all_rows()
    
    # Print only the most recent conversation
    await print_last_conversation()
    
    # Show weekly statistics
    await print_weekly_conversation_count()

# Run all analytics
if __name__ == "__main__":
    asyncio.run(main())
```

Sample output for weekly conversation count:
```
Conversation Count - Last 7 Days:
----------------------------------------
Date                     Count
----------------------------------------
2023-11-15                  45
2023-11-14                  38
2023-11-13                  52
2023-11-12                  30
2023-11-11                  25
2023-11-10                  41
2023-11-09                  33
----------------------------------------
Total                      264
```

