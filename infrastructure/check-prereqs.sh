#!/usr/bin/env bash
# check-prereqs.sh - verifies a VM can run the Zero-Trust Network Security Platform.
# Usage: ./infrastructure/check-prereqs.sh   (run as a normal user, NOT with sudo)

PASS=0; FAIL=0; WARN=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

echo "== 1. Required tools =="
for tool in git python3 docker curl wget jq openssl nc; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool found"; else bad "$tool missing"; fi
done

echo "== 2. Docker Compose plugin =="
if docker compose version >/dev/null 2>&1; then
  ok "$(docker compose version)"
else
  bad "'docker compose' plugin missing (v2 syntax is required)"
fi

echo "== 3. Docker without sudo =="
if [ "$(id -u)" -eq 0 ]; then
  warn "running as root; re-run as a normal user to test this properly"
elif docker ps >/dev/null 2>&1; then
  ok "current user can talk to the Docker daemon"
else
  bad "cannot run docker as $USER -> sudo usermod -aG docker \$USER, then log out/in"
fi

echo "== 4. Resources =="
RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
DISK_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
[ "$RAM_GB" -ge 7 ]  && ok "RAM ${RAM_GB} GB"  || bad "RAM ${RAM_GB} GB (need >= 7)"
[ "$RAM_GB" -ge 12 ] || warn "Wazuh + full stack is tight under 12 GB"
[ "$DISK_GB" -ge 30 ] && ok "free disk ${DISK_GB} GB" || warn "free disk ${DISK_GB} GB (Wazuh + images need ~30 GB)"

echo "== 5. Kernel setting for Wazuh indexer =="
MAP=$(sysctl -n vm.max_map_count 2>/dev/null)
if [ "${MAP:-0}" -ge 262144 ]; then ok "vm.max_map_count=$MAP"
else warn "vm.max_map_count=${MAP:-unknown} (need 262144) -> sudo sysctl -w vm.max_map_count=262144"; fi

echo "== 6. Ports free on the host =="
# 80/443 gateway, 8080 Keycloak, 8181 OPA, 5432 Postgres, 55000/1514/1515 Wazuh, 9200 indexer
for p in 80 443 8080 8181 5432 55000 1514 1515 9200; do
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}$"; then
    warn "port $p already in use"
  else
    ok "port $p free"
  fi
done

echo
echo "Summary: $PASS passed, $WARN warnings, $FAIL failed"
[ "$FAIL" -eq 0 ]
