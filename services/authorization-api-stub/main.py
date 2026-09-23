from fastapi import FastAPI, Response

app = FastAPI(title="authorization-api-stub")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/authorize")
def authorize():
    # PLACEHOLDER ONLY: always allows.
    # Person 2's real OPA-backed authorization-api replaces this — see docs/service-contract.md.
    return Response(status_code=200)
