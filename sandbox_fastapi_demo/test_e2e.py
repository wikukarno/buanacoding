import asyncio
import json

import httpx

from app.main import app


async def main():
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # health
        r = await client.get("/healthz")
        print("health:", r.status_code, r.json())

        # register
        r = await client.post(
            "/users",
            json={"username": "alice", "password": "S3curePass!"},
        )
        print("register:", r.status_code, r.json())

        # token
        r = await client.post(
            "/token",
            data={"username": "alice", "password": "S3curePass!"},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        print("token:", r.status_code, r.json())
        token = r.json()["access_token"]

        # me
        r = await client.get("/me", headers={"Authorization": f"Bearer {token}"})
        print("me:", r.status_code, r.json())


if __name__ == "__main__":
    asyncio.run(main())
