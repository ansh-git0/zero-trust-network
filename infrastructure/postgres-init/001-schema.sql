-- Minimal schema for the ZT platform.
-- access_log holds one row per authorization decision, written by authorization-api.

CREATE TABLE IF NOT EXISTS access_log (
    id            BIGSERIAL PRIMARY KEY,
    request_id    TEXT NOT NULL,
    user_id       TEXT,
    device_id     TEXT,
    resource      TEXT NOT NULL,
    decision      TEXT NOT NULL CHECK (decision IN ('allow', 'deny')),
    reason        TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_access_log_created_at ON access_log (created_at);
CREATE INDEX IF NOT EXISTS idx_access_log_decision ON access_log (decision);

-- A row so we can prove the table works end-to-end.
INSERT INTO access_log (request_id, user_id, device_id, resource, decision, reason)
VALUES ('seed-0001', 'system', 'system', '/health', 'allow', 'schema initialization check');
