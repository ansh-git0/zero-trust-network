# Service Contract (DRAFT v0.1)

Single source of truth for service names, ports and networks. Compose connects
services **by name**, so a name change breaks other people's modules.
Change this file only via agreement or a PR. Rows marked (?) must be confirmed by the owner.

## Services

| Service (DNS name) | Owner | Container port | Networks | Health check | Host-published? |
|---|---|---|---|---|---|
| nginx-gateway | P3 | 80 | gateway, app, backend | GET /health | Yes (80/443) |
| employee-portal | P3 | 8001 | app, monitoring | GET /health | No |
| developer-api | P3 | 8002 | app, monitoring | GET /health | No |
| admin-panel | P3 | 8003 | app, monitoring | GET /health | No |
| postgres | P3 | 5432 | database | pg_isready | No |
| wazuh (manager/indexer/dashboard) | P3 | 1514, 1515, 55000, 9200, 443 | monitoring | per Wazuh image | Dashboard only |
| keycloak | P1 (?) | 8080 | identity | /health/ready | Yes (8080, for login) |
| authorization-api | P2 (?) | 8000 | backend, identity, database, monitoring | GET /health | No |
| opa | P2 (?) | 8181 | backend | GET /health | No |
| device-registry | P2 (?) | 8004 (?) | backend, database, monitoring | GET /health | No |
| risk-engine | P2 (?) | 8005 (?) | backend, database, monitoring | GET /health | No |

## Allowed flows

| From | To | Why |
|---|---|---|
| client (host) | nginx-gateway | only public entry point |
| nginx-gateway | authorization-api | auth_request decision |
| nginx-gateway | employee-portal / developer-api / admin-panel | proxy after allow |
| authorization-api | opa | policy decision |
| authorization-api | keycloak | token validation (JWKS) |
| authorization-api | device-registry, risk-engine | posture / risk inputs |
| authorization-api, device-registry, risk-engine | postgres | persistence |
| all log-producing services | wazuh | log collection |

## Prohibited flows (tested in step 7)

| From | To | Expected result |
|---|---|---|
| nginx-gateway | postgres | no network path |
| employee-portal / developer-api / admin-panel | postgres | no network path |
| employee-portal | admin-panel | no network path |
| any service | host LAN / internet (internal networks) | blocked |

## Conventions

- Service-to-service URLs use the DNS names above, never localhost or LAN IPs.
- Every service exposes `GET /health` (HTTP 200 when ready).
- JSON everywhere; errors use `{"error":"...","code":"..."}`; timestamps ISO-8601 UTC.
- Every request carries `X-Request-ID`.
- Config comes from environment variables (see `.env.example`).

## Open questions for teammates

1. Are the owners, service names and ports above correct?
2. Does Keycloak use its own database, or the shared `postgres`?
3. Does authorization-api need to reach Keycloak directly, or only OPA?
