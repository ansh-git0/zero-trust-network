#!/usr/bin/env bash
# Attack scenario tests for the Zero-Trust Network Security Platform.
# Run from the repo root: ./attack-scenarios/run-attacks.sh
# Some scenarios depend on Person 1/2's real services and are correctly
# reported as BLOCKED until those exist -- this is expected, not a bug.

set -u
PASS=0; BLOCKED=0; GAP=0

pass()    { echo "  [PASS] $1"; PASS=$((PASS+1)); }
blocked() { echo "  [BLOCKED - dependency pending] $1"; BLOCKED=$((BLOCKED+1)); }
gap()     { echo "  [GAP FOUND] $1"; GAP=$((GAP+1)); }

echo "=== Scenario 1: Employee -> Admin Panel access ==="
echo "Expected: policy denial based on role."
blocked "authorization-api-stub has no role logic yet (always allows). Needs Person 2's real OPA-backed authorization-api."

echo ""
echo "=== Scenario 2: Developer -> restricted DB/SSH access ==="
echo "Expected: denial."
blocked "No real authorization-api with DB/SSH policy exists yet (currently busybox stub)."

echo ""
echo "=== Scenario 3: Simulated compromised device (posture change) ==="
echo "Expected: increased risk, changed access."
blocked "risk-engine is still a busybox stub with no posture logic (Person 2)."

echo ""
echo "=== Scenario 4: Lateral movement between isolated services ==="
echo "Expected: network-level blocking."
R1=$(docker compose exec -T employee-portal python3 -c "import socket; s=socket.socket(); s.settimeout(2); print(s.connect_ex(('admin-panel',8003)))" 2>&1)
if echo "$R1" | grep -q "gaierror\|refused\|timed out"; then
  pass "employee-portal cannot reach admin-panel (network-level block, not app-level): $R1"
else
  gap "employee-portal reached admin-panel unexpectedly: $R1"
fi

echo ""
echo "=== Scenario 5: Valid credentials from untrusted/high-risk device ==="
echo "Expected: step-up MFA or denial."
blocked "device-registry is still a busybox stub with no device-trust logic (Person 2)."

echo ""
echo "=== Scenario 6: Privilege escalation via resource outside role ==="
echo "Expected: OPA denial."
blocked "No real OPA policy exists yet -- authorization-api-stub always allows regardless of resource."

echo ""
echo "=== Scenario 7: Malformed / replayed / expired tokens ==="
echo "Expected: authentication failure."
R2=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer not-a-real-jwt-garbage" http://localhost/employee/health)
R3=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/employee/health)
if [ "$R2" = "200" ] && [ "$R3" = "200" ]; then
  gap "Gateway accepts requests with a garbage/malformed token AND with no token at all (both returned 200). Token validation is not yet enforced -- this will be closed once Keycloak (Person 1) issues real JWTs and authorization-api validates them."
else
  pass "Malformed token was rejected (HTTP $R2)"
fi

echo ""
echo "=== Summary: $PASS passed, $BLOCKED blocked on teammate dependencies, $GAP real gaps found ==="
