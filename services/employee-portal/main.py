from fastapi import FastAPI
from datetime import datetime, timezone

app = FastAPI(title="employee-portal")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {
        "service": "employee-portal",
        "message": "Employee portal reached successfully.",
        "time": datetime.now(timezone.utc).isoformat(),
    }
