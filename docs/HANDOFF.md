# Handoff Notes -- Infrastructure, Gateway & Monitoring (Ansh / Person 3)

For Khushi (Person 1 -- Identity, Authentication & Authorization) and
Saksham (Person 2 -- Device Trust, Posture & Risk Engine). This explains
what's built, what's safe to change, what will break things if you're not
careful, and exactly how your real services plug in.

## Getting the code without touching my working copy

Don't push directly to `master` -- clone it and work on your own branch,
then open a Pull Request so I (or any of us) can review before it merges.

```bash
git clone https://github.com/ansh-git0/zero-trust-network.git
cd zero-trust-network
git checkout -b khushi/authorization-api        # or saksham/risk-engine, etc.

# ...do your work...

git add <only the files you actually changed>
git commit -m "..."
git push -u origin khushi/authorization-api
```

Then open a PR on GitHub from your branch into `master`. This means:

- Your in-progress work never touches my tested `master` branch until
  it's reviewed
- If something breaks, `git diff master...your-branch` shows exactly
  what changed
- I still have edit access on the repo (you were added as a
  collaborator), so nobody's blocked waiting on anyone else -- this is
  just about keeping history clean, not about permissions

**Stick to your own folders** (`identity/`, `authorization/` for Khushi;
`device-trust/`, `risk-engine/` for Saksham -- see the repo layout in
`README.md`) and the specific stub blocks in `docker-compose.yml` that
are yours per Rule #3 below. If you need to touch something outside your
area (shared config, `docs/service-contract.md`, `gateway/nginx.conf`),
flag it in the PR description so it gets a second look before merging.

## What's already built and tested (don't rebuild these)

- Docker network segmentation -- 6 networks, each protected app isolated
  from the others, database unreachable except from services that need it
- NGINX gateway with routing + an `auth_request` authorization gate
- Employee/Developer/Admin test services
- PostgreSQL with an `access_log` schema
- Wazuh SIEM, receiving real logs from the gateway, with two working
  detection rules (single 403, repeated 403s)
- An attack-scenario test script that reports exactly what's working
  vs. blocked on your services (`./attack-scenarios/run-attacks.sh`)

Every claim above has a saved, timestamped result in `docs/evidence/` --
if you want proof something works, that folder has it, not just this doc.

## READ THIS FIRST: a real integration gap between our two designs

My `nginx.conf` currently gates every protected route with:

```nginx
location = /_authz {
    internal;
    proxy_pass http://authorization-api-stub:8006/authorize;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URI $request_uri;
    proxy_set_header X-Request-ID $req_id;
}
```

This sends an empty request with no body to `/authorize` and reads only
the HTTP status code back (2xx = allow, else deny). That's all
`auth_request` needs for a simple allow/deny gate.

**Khushi's contract** (from her doc) expects `POST /authorize` with a full
JSON body: `user_id`, `roles`, `device_id`, `resource`, `action`,
`posture_score`, `risk_score`, `resource_sensitivity`. NGINX's
`auth_request` module can't assemble that payload on its own -- it doesn't
know a user's roles or a device's posture score.

**This needs a team decision before the real integration happens.** Two
realistic options:
1. `authorization-api` looks up everything itself once it gets a
   `user_id` + `resource` from the gateway (calls Keycloak for roles,
   calls Saksham's device-registry/risk-engine for posture/risk, then
   decides). The gateway stays simple.
2. Something in front of the gateway (or a small enrichment step) builds
   the full JSON body before calling `authorize`.

I'd lean toward option 1 -- it matches "Person 3 will route requests
through NGINX... keep the authorization API reachable by a stable Docker
service name" from Khushi's own doc, and keeps the gateway dumb, which is
the right place for it. But this is worth a 10-minute conversation between
the three of us before anyone builds against an assumption.

## Rule #1: don't touch `docs/service-contract.md` names/ports without asking

Everything -- compose file, NGINX config, network membership -- is wired
using the exact service names in that file: `keycloak`, `opa`,
`authorization-api`, `device-registry`, `risk-engine`. Rename or report a
different port without updating the contract and things silently stop
connecting. Update the contract in the same PR as your change.

## Rule #2: don't add your service to a network it doesn't need

Each network blocks something specific:

- `employee-network` / `developer-network` / `admin-network` exist ONLY
  so nginx-gateway can reach each app. Putting two services on the same
  one re-opens the lateral-movement hole fixed in commit `0033193` --
  see `docs/evidence/full-segmentation-evidence.txt`.
- `database-network` is `internal: true` on purpose. If your service
  (Saksham -- device-registry/risk-engine, or Khushi -- authorization-api)
  needs Postgres, it's already scoped to reach it via `database-network`
  in the current compose stubs. Don't widen Postgres's reachability to
  solve a connectivity problem -- add your service to the specific
  network it needs instead.

## Rule #3: replacing a stub is additive, not destructive

`keycloak`, `opa`, `device-registry`, `risk-engine`, and
`authorization-api` are currently `busybox` stubs in `docker-compose.yml`.
To replace yours:

1. Build your service with its own `Dockerfile` under its own folder
   (pattern: `services/employee-portal/` -- `main.py`, `Dockerfile`,
   `requirements.txt`).
2. Find your stub block, e.g.:
```yaml
     risk-engine:
       <<: *stub
       networks: [backend-network, database-network, monitoring-network]
```
3. Replace ONLY `<<: *stub` with `build: ./path/to/your/service`. Leave
   `networks:` as-is unless the contract says otherwise.
4. `docker compose config > /dev/null && echo OK` must print `OK` before
   you commit.
5. Give your service `GET /health` returning HTTP 200 -- every other
   service here has one, and the test scripts assume it (both of your
   docs already require this too).

Editing `docker-compose.yml` by hand (Notepad, copy-paste) is exactly
where I broke things twice while building this -- bad indentation, or a
line landing in the wrong place. **Always run the `docker compose config`
check immediately after any edit, before starting containers.**

## For Khushi specifically (authorization-api, Keycloak, OPA)

- Your `POST /authorize` contract (request/response shapes) is solid and
  matches the ISO-8601/request_id/JSON-error conventions already used
  everywhere in this repo -- no changes needed there.
- Read the integration gap section above before wiring the gateway to
  your real service.
- Once it's ready: update `gateway/nginx.conf`'s `location = /_authz`
  block to point at `authorization-api:<your-port>` instead of
  `authorization-api-stub:8006`, then re-run the reproducible allow/deny
  test in `docs/evidence/auth-request-gate-test-1.txt` against your real
  service before calling it done.
- Your doc says "reject malformed, expired, or invalid-signature JWTs" --
  `attack-scenarios/run-attacks.sh` scenario 7 already tests exactly
  this against the gateway and currently reports a GAP (garbage tokens
  currently pass through untouched, since nothing validates them yet).
  Re-run it once your service is live; that GAP should close.

## For Saksham specifically (device-registry, risk-engine)

- Your `POST /risk/evaluate` and device posture payload shapes are
  already reflected in the service contract's field-naming conventions
  (`device_id`, `request_id`) -- nothing to reconcile there.
- `device-registry` and `risk-engine` stubs already sit on
  `backend-network`, `database-network`, and `monitoring-network` in
  `docker-compose.yml` -- your Postgres and log-shipping access is
  pre-wired, just replace the stub per Rule #3.
- Scenario 3 (compromised device / posture change) and scenario 5
  (untrusted device, valid creds) in `attack-scenarios/run-attacks.sh`
  are currently BLOCKED specifically waiting on your service -- they'll
  become real tests the moment `risk-engine` and `device-registry` exist
  with working endpoints.

## How to verify you haven't broken anything

Run these three after any change:

```bash
docker compose config > /dev/null && echo "compose file OK"
docker compose exec -T nginx-gateway nc -zv -w2 postgres 5432   # must still FAIL
./attack-scenarios/run-attacks.sh                                # scenario 4 must still PASS
```

If the Postgres check succeeds (instead of failing) or scenario 4 flips
to a GAP, something broke network isolation -- stop and ask before
committing.

## Where things live

- `docs/service-contract.md` -- names, ports, networks (source of truth)
- `docs/evidence/` -- every test's actual saved output, timestamped
- `README.md` -- setup and architecture overview
- `attack-scenarios/run-attacks.sh` -- run this often, it's cheap and
  tells you exactly where things stand, scenario by scenario

## If something looks broken and you're not sure why

`git log --oneline` -- every change so far is one commit, one clear
message. `git log -p <commit>` shows exactly what changed and why.
Nothing here has been force-pushed or rewritten.
