from fastapi import FastAPI, HTTPException
import redis
import os

app = FastAPI()

REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

@app.get("/results")
def results():
    votes = r.hgetall("votes")
    return {
        "a": int(votes.get("a", 0)),
        "b": int(votes.get("b", 0))
    }

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
