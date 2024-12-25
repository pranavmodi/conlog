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

