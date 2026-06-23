from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
import os
import jwt
import bcrypt
from datetime import datetime, timedelta

router = APIRouter()

JWT_SECRET = os.getenv("JWT_SECRET")  # loaded from SSM Parameter Store via ECS task def
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# Demo in-memory user store — replace with DynamoDB in production
DEMO_USERS = {
    "demo@example.com": bcrypt.hashpw(b"demo1234", bcrypt.gensalt()).decode()
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
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRY_HOURS),
        "iat": datetime.utcnow(),
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return TokenResponse(access_token=token)
