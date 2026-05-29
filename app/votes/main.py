from fastapi import FastAPI, HTTPException
import redis
import os

app = FastAPI()

REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

@app.post("/vote")
def vote(option: dict):
    if option.get("option") not in ("a", "b"):
        raise HTTPException(status_code=400, detail="Invalid option. Use 'a' or 'b'.")
    r.hincrby("votes", option["option"], 1)
    return {"status": "ok", "option": option["option"]}

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.get("/ready")
def ready():
    try:
        r.ping()
        return {"status": "ready"}
    except redis.ConnectionError:
        raise HTTPException(status_code=503, detail="Redis not ready")