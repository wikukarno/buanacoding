from fastapi import FastAPI

from app.db.base import Base
from app.db.session import engine
from app.api.routes import auth, users, health

app = FastAPI()

# Create tables
Base.metadata.create_all(bind=engine)

# Mount routers
app.include_router(auth.router, tags=["auth"])
app.include_router(users.router, tags=["users"])
app.include_router(health.router, tags=["health"])

