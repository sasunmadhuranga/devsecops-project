from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
import os
import jwt
import bcrypt
from datetime import datetime, timedelta, timezone


router = APIRouter()

JWT_SECRET = os.getenv("JWT_SECRET") 
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24
DEMO_PASSWORD = os.getenv("DEMO_PASSWORD")

now = datetime.now(timezone.utc)

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

DEMO_USERS = {
    "demo@example.com": bcrypt.hashpw(DEMO_PASSWORD.encode(), bcrypt.gensalt()).decode()
}


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    user_hash = DEMO_USERS.get(request.email)
    if not user_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    if not bcrypt.checkpw(request.password.encode(), user_hash.encode()):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    payload = {
        "sub": request.email,
        "exp": now + timedelta(hours=JWT_EXPIRY_HOURS),
        "iat": now,
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return TokenResponse(access_token=token)
