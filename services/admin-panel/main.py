from fastapi import FastAPI
from datetime import datetime, timezone

app = FastAPI(title="admin-panel")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {
        "service": "admin-panel",
        "message": "Admin panel reached successfully.",
        "time": datetime.now(timezone.utc).isoformat(),
    }
