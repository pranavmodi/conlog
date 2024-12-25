from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy import Column, Integer, String, DateTime, JSON
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Botpress Conversation Logger",
    description="API for collecting and storing Botpress conversation logs",
    version="1.0.0"
)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://user:password@localhost/botpress_logs")
engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

# Database models
class ConversationLog(Base):
    __tablename__ = "conversation_logs"

    id = Column(Integer, primary_key=True)
    conversation_id = Column(String, index=True, nullable=False)
    user_id = Column(String, index=True, nullable=False)
    message = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
    metadata = Column(JSON, nullable=True)

# Pydantic models for request/response
class MessageLog(BaseModel):
    conversation_id: str
    user_id: str
    message: str
    metadata: Optional[dict] = None

class MessageLogResponse(MessageLog):
    id: int
    timestamp: datetime

    class Config:
        orm_mode = True

# Dependency for database session
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

# API routes
@app.post("/api/conversations", response_model=MessageLogResponse)
async def create_conversation_log(message_log: MessageLog, db: AsyncSession = Depends(get_db)):
    try:
        db_log = ConversationLog(
            conversation_id=message_log.conversation_id,
            user_id=message_log.user_id,
            message=message_log.message,
            metadata=message_log.metadata
        )
        db.add(db_log)
        await db.commit()
        await db.refresh(db_log)
        return db_log
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/conversations", response_model=List[MessageLogResponse])
async def get_conversation_logs(
    conversation_id: Optional[str] = None,
    user_id: Optional[str] = None,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    query = select(ConversationLog)
    if conversation_id:
        query = query.where(ConversationLog.conversation_id == conversation_id)
    if user_id:
        query = query.where(ConversationLog.user_id == user_id)
    query = query.order_by(ConversationLog.timestamp.desc()).limit(limit)
    
    try:
        result = await db.execute(query)
        logs = result.scalars().all()
        return logs
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Create database tables
@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
