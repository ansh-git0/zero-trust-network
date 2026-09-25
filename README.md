# Zero-Trust Network Security Platform

Infrastructure, gateway, monitoring, and security-testing module (Person 3's
part of a 3-person team project) for a Zero-Trust Network Security Platform.

Builds the execution environment the other modules run in: Docker network
segmentation, an NGINX gateway with an authorization gate, protected test
services, PostgreSQL, a Wazuh SIEM pipeline with real detection rules, and
attack-scenario tests.

## Prerequisites

- Ubuntu 22.04+ (or similar Linux), Docker + Docker Compose v2
- `vm.max_map_count=262144` (required for the Wazuh indexer)
- At least 8 GB RAM (Wazuh's indexer/manager/dashboard are memory-heavy;
  see `infrastructure/check-prereqs.sh`)

Run the prerequisite check first:

./infrastructure/check-prereqs.sh


## Quick start

cp .env.example .env # first time only -- edit passwords if you like
docker compose up -d
docker compose ps # everything should show "Up"


Verify the gateway and its protected routes:

curl http://localhost/health
curl http://localhost/employee/health
curl http://localhost/developer/health
curl http://localhost/admin/health


## Starting Wazuh (monitoring)

Wazuh runs as its own Docker Compose project (it manages its own certs and
volumes) and is memory-heavy -- start it after the main platform is up.

cd monitoring/wazuh-docker/single-node
docker compose up -d
docker compose ps


Dashboard: `https://<this-machine's-IP>:443` (login `admin` / `SecretPassword`
-- change this for anything beyond local testing).

To actually receive logs from the gateway, a Wazuh agent must run on the
host and be pointed at `gateway/logs/access.log` (see
`docs/evidence/wazuh-detection-test.txt` for the exact setup and a working
example of the resulting detections).

## Architecture

Six Docker networks isolate every tier from the others (see
`docs/service-contract.md` for the full table):

- `gateway-network` -- the only network reachable from the host
- `employee-network` / `developer-network` / `admin-network` -- each protected
  app shares a network only with `nginx-gateway`, not with each other
  (this stops lateral movement -- see `docs/evidence/full-segmentation-evidence.txt`)
- `backend-network` -- gateway to authorization services
- `database-network` -- internal only, no host route, Postgres lives here

Every request to `/employee`, `/developer`, or `/admin` passes through
NGINX's auth_request directive, which calls `authorization-api-stub`
before proxying. Client-supplied role headers are stripped, never trusted.

## Repository layout

zero-trust-network/
docker-compose.yml main platform
.env.example config template (copy to .env, never commit .env)
infrastructure/ prereq check, postgres init SQL
gateway/ nginx.conf, gateway/logs/ (git-ignored)
services/ employee-portal, developer-api, admin-panel,
authorization-api-stub (each: main.py,
Dockerfile, requirements.txt)
monitoring/wazuh-docker/ official Wazuh single-node deployment (cloned,
git-ignored)
attack-scenarios/ run-attacks.sh
docs/
service-contract.md service names/ports/networks -- shared with team
evidence/ every test's actual output, timestamped
tests/


## Running the tests
Micro-segmentation: 6 prohibited flows blocked, 4 allowed flows work

docker compose exec -T nginx-gateway nc -zv -w2 postgres 5432 # should fail

Attack scenarios: what's provably working vs. blocked on teammates

./attack-scenarios/run-attacks.sh


All evidence from every test run so far is saved under `docs/evidence/`,
timestamped, and committed to this repo -- nothing here is asserted without
a saved result backing it up.

## Current status and known gaps

Steps done (infrastructure, gateway, test services, Postgres, full
micro-segmentation proof, Wazuh deployed with a working detection pipeline)
are documented with evidence in `docs/evidence/`.

Known gap: `authorization-api-stub` always allows every request and does
not validate tokens -- this is intentional, a placeholder until Person 2
delivers the real OPA-backed `authorization-api`. `attack-scenarios/run-attacks.sh`
documents exactly which scenarios are blocked by this and why. Real tokens
from Keycloak (Person 1) are similarly still pending.

## Team integration

- `docs/service-contract.md` is the single source of truth for service
  names, ports, and networks -- change it only by agreement.
- Don't modify another person's module directly; open a PR or raise the
  interface change in the contract doc.
- Before merging: `docker compose config` must validate, and all health
  endpoints must return 200.
