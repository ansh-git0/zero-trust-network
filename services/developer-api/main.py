from fastapi import FastAPI
from datetime import datetime, timezone

app = FastAPI(title="developer-api")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {
        "service": "developer-api",
        "message": "Developer API reached successfully.",
        "time": datetime.now(timezone.utc).isoformat(),
    }
