---
title: "FastAPI JWT Auth with OAuth2 Password Flow (Pydantic v2 + SQLAlchemy 2.0)"
date: 2025-08-20T07:00:00+07:00
publishDate: 2025-08-20T07:00:00+07:00
draft: false
url: /2025/08/fastapi-jwt-auth-oauth2-password-flow-pydantic-v2-sqlalchemy-2.html
tags:
  - Python
  - FastAPI
  - Security
  - JWT
  - OAuth2
  - SQLAlchemy
description: "A pragmatic guide to building username/password login in FastAPI using OAuth2 Password flow with JWTs, powered by Pydantic v2 and SQLAlchemy 2.0. Includes hashing, token creation, protected routes, and testing."
keywords: ["fastapi", "jwt", "oauth2 password flow", "pydantic v2", "sqlalchemy 2", "python", "auth", "password hashing"]
---

Looking to add login to your FastAPI app without pulling in a full auth service? Here’s a small, production‑friendly setup. We’ll build username/password authentication with the OAuth2 Password flow and JSON Web Tokens (JWTs) for stateless access. It uses Pydantic v2 for validation and SQLAlchemy 2.0 for persistence. You’ll hash passwords properly, create/verify tokens, protect routes, and test everything end‑to‑end.

If you’re deploying the finished app on Ubuntu with HTTPS, check the deployment guide: [Deploy FastAPI on Ubuntu 24.04: Gunicorn + Nginx + Certbot]({{< relref "blog/python/deploy-fastapi-ubuntu-24-04-gunicorn-nginx-certbot.md" >}}).

What you’ll build
-----------------
- A minimal user model backed by SQLAlchemy 2.0
- Password hashing using `passlib[bcrypt]`
- JWT access token creation and verification with `python-jose`
- OAuth2 Password flow login endpoint (`/token`)
- Protected routes using `OAuth2PasswordBearer`
- A simple current‑user dependency that decodes JWTs

Prerequisites
-------------
- Python 3.10+
- Basic FastAPI experience
- SQLite for demo (swap with PostgreSQL/MySQL in production)

1) Best‑practice project structure
---------------------------------
Use a small but clear layout so your imports stay tidy as the app grows:

```
app/
  main.py
  core/
    security.py
  db/
    base.py
    session.py
  models/
    user.py
  schemas/
    user.py
  api/
    deps.py
    routes/
      auth.py
      users.py
      health.py
```

2) Install dependencies
-----------------------
Create and activate a virtual environment, then install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn sqlalchemy pydantic passlib[bcrypt] python-jose[cryptography] python-dotenv python-multipart
```

Optional but recommended: manage secrets via a `.env` file during development.

Create a `.env` file in your project root:

```bash
cat > .env <<'ENV'
SECRET_KEY=$(openssl rand -hex 32)
ACCESS_TOKEN_EXPIRE_MINUTES=30
ENV
```

Where should `.env` live?
-------------------------
- Put `.env` in the project root (same level as `app/`).
- Run the app from the root so `load_dotenv()` finds it:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Add `.env` to `.gitignore` so it doesn’t get committed:

```gitignore
.env
```

If you sometimes run the app from a different working directory, you can load `.env` with an explicit path:

```python
# app/core/security.py (alternative)
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[2] / ".env")
```

`.env.example` and `requirements.txt` placement
----------------------------------------------
Keep both files at the project root for clarity and portability:

```
.
├─ .env                # not committed
├─ .env.example        # committed, template for teammates/CI
├─ requirements.txt    # pinned or curated dependencies
└─ app/
   ├─ core/
   ├─ db/
   ├─ models/
   ├─ schemas/
   ├─ api/
   └─ main.py
```

Suggested `.env.example`:

```dotenv
# .env.example
# Copy this file to .env and change the values as needed.
SECRET_KEY=change-me-to-a-strong-random-value
ACCESS_TOKEN_EXPIRE_MINUTES=30
# DATABASE_URL is optional here because the demo uses SQLite via app/db/session.py
# For Postgres, uncomment and use your DSN:
# DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/mydb
```

Pin dependencies with a `requirements.txt` (recommended):

Option A — write a curated `requirements.txt` with compatible ranges:

```txt
fastapi>=0.110,<1
uvicorn[standard]>=0.29,<1
sqlalchemy>=2.0,<3
pydantic>=2.5,<3
passlib[bcrypt]>=1.7,<2
python-jose[cryptography]>=3.3,<4
python-dotenv>=1.0,<2
python-multipart>=0.0.9,<1
```

Option B — pin exact versions from your current env:

```bash
pip freeze > requirements.txt
```

Later, reproduce the env with:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

3) Database setup (SQLAlchemy 2.0)
----------------------------------
Create two files for database plumbing.

```python
# app/db/base.py
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass
```

```python
# app/db/session.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

SQLALCHEMY_DATABASE_URL = "sqlite:///./app.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

4) Models and schemas
---------------------
We’ll store users with `username` and a hashed password (never store plain passwords).

```python
# app/models/user.py
from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    username: Mapped[str] = mapped_column(String, unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String)
```

Pydantic v2 schemas for reading/creating users:

```python
# app/schemas/user.py
from pydantic import BaseModel

class UserCreate(BaseModel):
    username: str
    password: str

class UserRead(BaseModel):
    id: int
    username: str

    model_config = {
        "from_attributes": True
    }

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
```

5) Security helpers: hashing and JWT
------------------------------------

```python
# app/core/security.py
import os
from datetime import datetime, timedelta, timezone
from typing import Optional
from jose import jwt
from passlib.context import CryptContext
from dotenv import load_dotenv

load_dotenv()  # load variables from .env if present

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = os.getenv("SECRET_KEY", "change-this-in-env")  # override in production
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(subject: str, expires_delta: Optional[timedelta] = None) -> str:
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode = {"sub": subject, "exp": expire}
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> dict:
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
```

6) API dependencies and routes
------------------------------
Dependencies (current user) and small helper functions:

```python
# app/api/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from jose import JWTError

from app.db.session import get_db
from app.models.user import User
from app.core.security import verify_password, decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_user_by_username(db: Session, username: str) -> User | None:
    return db.query(User).filter(User.username == username).first()

def authenticate_user(db: Session, username: str, password: str) -> User | None:
    user = get_user_by_username(db, username)
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    try:
        payload = decode_token(token)
        username: str | None = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token payload")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = get_user_by_username(db, username)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
```

Auth and user routes:

```python
# app/api/routes/auth.py
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import authenticate_user
from app.db.session import get_db
from app.schemas.user import Token
from app.core.security import create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES

router = APIRouter()

@router.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    token = create_access_token(subject=user.username, expires_delta=access_token_expires)
    return {"access_token": token, "token_type": "bearer"}
```

```python
# app/api/routes/users.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_user_by_username
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserRead
from app.core.security import hash_password

router = APIRouter()

@router.post("/users", response_model=UserRead, status_code=201)
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    exists = get_user_by_username(db, payload.username)
    if exists:
        raise HTTPException(status_code=400, detail="Username already taken")
    user = User(username=payload.username, hashed_password=hash_password(payload.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

@router.get("/me", response_model=UserRead)
def read_me(current_user: User = Depends(get_current_user)):
    return current_user
```

```python
# app/api/routes/health.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/healthz")
def healthz():
    return {"status": "ok"}
```

7) FastAPI application entrypoint
---------------------------------

```python
# app/main.py
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
```

8) Try it out
--------------

Run the app (from the project root):

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Option A — Swagger UI (easiest)
- Open http://127.0.0.1:8000/docs
- POST /users to register a user (username + password)
- POST /token to get an access token
- Click “Authorize”, paste `Bearer <the_token>`
- GET /me to verify it returns your user

Option B — curl (robust, copy‑paste safe)
To avoid shell quoting/wrapping issues, send JSON from a file and use urlencoded helpers:

```bash
# 1) Register user
echo '{"username":"alice","password":"S3curePass!"}' > user.json
curl -sS -i -X POST http://127.0.0.1:8000/users \
  -H 'Content-Type: application/json' \
  --data-binary @user.json

# 2) Get token (form-url-encoded)
TOKEN=$(curl -sS -X POST http://127.0.0.1:8000/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'username=alice' \
  --data-urlencode 'password=S3curePass!' \
  | jq -r .access_token)

# 3) Call protected route
curl -sS -i http://127.0.0.1:8000/me -H "Authorization: Bearer $TOKEN"
```

Notes
- If you see “Invalid HTTP request received”, your curl command likely broke across lines or used smart quotes. Use the file + `--data-binary` approach above.
- If username is taken, register a different one (e.g., `alice2`).
- If you don’t have `jq`, you can copy the token manually from the JSON response, or extract it with Python: `python -c "import sys,json;print(json.load(sys.stdin)['access_token'])"`.
- Make sure `python-multipart` is installed; it’s required for the `/token` form endpoint.

Option C — Postman (GUI)
- Register (POST /users):
  - Body: raw → JSON
  - Content-Type: application/json
  - Payload: `{ "username": "alice", "password": "S3curePass!" }`
- Login (POST /token):
  - Body: x-www-form-urlencoded (not raw JSON)
  - Keys: `username=alice`, `password=S3curePass!`
- Protected (GET /me):
  - Authorization tab → Type: Bearer Token → paste the token (no quotes)

Optional: import the Postman collection and use it directly: `/postman/fastapi-jwt-auth.postman_collection.json`.

Option D — HTTPie (nice DX)
```bash
# Register
http POST :8000/users username=alice password=S3curePass!

# Login
http -f POST :8000/token username=alice password=S3curePass! | jq

# Me
TOKEN=$(http -f POST :8000/token username=alice password=S3curePass! | jq -r .access_token)
http GET :8000/me "Authorization:Bearer $TOKEN"
```

9) Production notes
-------------------
- Secrets: Never hardcode `SECRET_KEY`. Read it from environment variables or a secret manager.
- Token lifetime: Adjust `ACCESS_TOKEN_EXPIRE_MINUTES` based on risk. Consider short‑lived access tokens with refresh tokens.
- HTTPS and reverse proxy: Put FastAPI behind Nginx/Traefik and enforce HTTPS. See the deployment guide: {{< relref "blog/python/deploy-fastapi-ubuntu-24-04-gunicorn-nginx-certbot.md" >}}.
- Password policy: Enforce minimum length and complexity. Consider rate‑limiting login attempts.
- Database: For PostgreSQL, change the `SQLALCHEMY_DATABASE_URL` (e.g., `postgresql+psycopg://user:pass@host/db`). Use Alembic for migrations.
- CORS/SPA: If used from a browser SPA, configure CORS properly and store tokens securely. For cookie‑based auth, consider `OAuth2PasswordBearer` alternatives with `httponly` cookies and CSRF protection.
- Scopes/roles: FastAPI supports OAuth2 scopes; add them to tokens and check in dependencies.
- Testing: Use `httpx.AsyncClient` and `pytest` to cover login and protected routes.

Systemd tip (prod): set env vars in the unit file instead of `.env`:

```ini
[Service]
Environment="SECRET_KEY=your-strong-secret"
Environment="ACCESS_TOKEN_EXPIRE_MINUTES=30"
```

Wrap‑up
-------
You now have a working JWT‑based login using the OAuth2 Password flow in FastAPI with Pydantic v2 and SQLAlchemy 2.0. The example is deliberately small but production‑leaning: it hashes passwords, issues signed tokens, and protects endpoints with a simple dependency. From here, add what you need—refresh tokens, roles/scopes, social logins, and migrations—then deploy behind Nginx with HTTPS.
