#!/usr/bin/env bash
# Make Ollama reachable from Docker containers on Linux (RHEL, WSL with Ollama in WSL, etc.).
# Ollama ignores /etc/ollama/config.yaml for the listen address; use OLLAMA_HOST via systemd.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=platform.sh
source "${SCRIPT_DIR}/platform.sh"

DROP_IN="/etc/systemd/system/ollama.service.d/environment.conf"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-run with sudo:  sudo $0"
  exit 1
fi

if ! command -v systemctl &>/dev/null; then
  echo "ERROR: systemd not available in this environment."
  if is_wsl; then
    echo "  If Ollama runs on Windows (not WSL), use:"
    echo "    powershell -File ${REPO_ROOT}/scripts/configure-ollama-windows.ps1"
    echo "  See: ${REPO_ROOT}/docs/windows.md"
  fi
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

BRIDGE_IP="$(docker_bridge_ip)"

echo ""
echo "Listen addresses:"
if command -v ss &>/dev/null; then
  ss -tlnp | grep 11434 || true
else
  echo "  (ss not installed; skipping socket listing)"
fi

if check_ollama_for_docker "${BRIDGE_IP}"; then
  echo ""
  if uses_docker_desktop; then
    echo "OK: Ollama is reachable from Docker (host.docker.internal / bridge)."
  else
    echo "OK: Ollama is reachable at http://${BRIDGE_IP}:11434 (Docker host-gateway)."
  fi
  echo "Re-run ./bootstrap.sh if ingestion failed earlier."
else
  echo ""
  echo "WARNING: Ollama still not reachable from Docker containers."
  if is_wsl; then
    echo "  If Ollama runs on Windows, use configure-ollama-windows.ps1 instead."
    echo "  See: ${REPO_ROOT}/docs/windows.md"
  else
    echo "  Check: ss -tlnp | grep 11434"
    echo "  If firewalld blocks docker0, allow the port or trust the docker zone."
  fi
  exit 1
fi
