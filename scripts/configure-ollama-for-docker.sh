#!/usr/bin/env bash
# Make Ollama reachable from Docker containers on Linux (RHEL, etc.).
# Ollama ignores /etc/ollama/config.yaml for the listen address; use OLLAMA_HOST via systemd.
set -euo pipefail

DROP_IN="/etc/systemd/system/ollama.service.d/environment.conf"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-run with sudo:  sudo $0"
  exit 1
fi

mkdir -p /etc/systemd/system/ollama.service.d
cat >"$DROP_IN" <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

systemctl daemon-reload
systemctl restart ollama

echo "Waiting for Ollama..."
for _ in {1..15}; do
  if curl -sf --max-time 2 http://127.0.0.1:11434/api/tags &>/dev/null; then
    break
  fi
  sleep 1
done

BRIDGE_IP=""
if ip -4 addr show docker0 &>/dev/null; then
  BRIDGE_IP=$(ip -4 addr show docker0 | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
fi
BRIDGE_IP="${BRIDGE_IP:-172.17.0.1}"

echo ""
echo "Listen addresses:"
ss -tlnp | grep 11434 || true

if curl -sf --max-time 3 "http://${BRIDGE_IP}:11434/api/tags" &>/dev/null; then
  echo ""
  echo "OK: Ollama is reachable at http://${BRIDGE_IP}:11434 (Docker host-gateway)."
  echo "Re-run ./bootstrap.sh if ingestion failed earlier."
else
  echo ""
  echo "WARNING: Ollama still not reachable at http://${BRIDGE_IP}:11434"
  echo "  Check: ss -tlnp | grep 11434"
  echo "  If firewalld blocks docker0, allow the port or trust the docker zone."
  exit 1
fi
