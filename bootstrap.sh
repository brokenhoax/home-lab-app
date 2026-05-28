#!/usr/bin/env bash
# Bootstrap home-lab-app: Docker (if needed), compose stack, ingestion.
# Run from a terminal:  cd ~/path/to/home-lab-app && ./bootstrap.sh
# Windows: use WSL — see docs/windows.md or run .\bootstrap.ps1 from PowerShell.
# Logs are written to bootstrap.log in this directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/platform.sh
source "${SCRIPT_DIR}/scripts/platform.sh"

PLATFORM="$(platform_name)"
LOG_FILE="${SCRIPT_DIR}/bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local line=$1 code=$?
  echo ""
  echo "=== Bootstrap FAILED (exit ${code}) at line ${line} ==="
  echo "Full log: ${LOG_FILE}"
  if [[ -t 0 && -t 1 ]]; then
    read -r -p "Press Enter to close this window..."
  fi
  exit "${code}"
}
trap 'on_error ${LINENO}' ERR

echo "=== Home Lab App bootstrap ==="
echo "Started: $(date)"
echo "Platform: ${PLATFORM}"
echo "Working directory: ${SCRIPT_DIR}"

docker_ok() {
  docker info &>/dev/null
}

compose() {
  docker compose "$@"
}

ensure_docker_access() {
  if docker_ok; then
    return 0
  fi

  if [[ "${PLATFORM}" == "linux-wsl" ]]; then
    echo "ERROR: Cannot reach Docker in WSL."
    echo "  - Install/start Docker Engine in WSL:  sudo systemctl start docker"
    echo "  - Confirm:  docker info"
    echo "  - Run from inside WSL (not CMD alone):  ./bootstrap.sh"
    echo "  - Guide: ${SCRIPT_DIR}/docs/windows.md"
    exit 1
  fi

  if uses_docker_desktop; then
    echo "ERROR: Cannot reach Docker."
    echo "  - Start Docker Desktop for Mac and wait until it is Running."
    echo "  - Guide: ${SCRIPT_DIR}/docs/macos.md"
    exit 1
  fi

  if command -v sg &>/dev/null && sg docker -c "docker info" &>/dev/null 2>&1; then
    echo "Re-running with docker group privileges (user: ${USER})..."
    exec sg docker -c "cd $(printf '%q' "$SCRIPT_DIR") && exec $(printf '%q' "${SCRIPT_DIR}/$(basename "$0")")"
  fi

  if sudo -n docker info &>/dev/null 2>&1; then
    echo "Using sudo for Docker commands."
    compose() { sudo docker compose "$@"; }
    return 0
  fi

  if command -v docker &>/dev/null && sudo docker info &>/dev/null; then
    echo "Using sudo for Docker commands."
    compose() { sudo docker compose "$@"; }
    return 0
  fi

  echo "ERROR: Cannot talk to the Docker daemon."
  case "${PLATFORM}" in
    linux-wsl)
      echo "  - Install/start Docker Engine in WSL — see ${SCRIPT_DIR}/docs/windows.md"
      echo "  - sudo usermod -aG docker ${USER}, then wsl --shutdown and reopen Ubuntu"
      ;;
    *)
      echo "  - If Docker is installed, run:  sudo usermod -aG docker ${USER}"
      echo "  - Then log out and back in (or: newgrp docker), and re-run this script."
      echo "  - Guide: ${SCRIPT_DIR}/docs/linux-rhel.md"
      ;;
  esac
  exit 1
}

install_docker_if_missing() {
  if command -v docker &>/dev/null; then
    echo "=== Docker already installed ($(docker --version 2>/dev/null || echo unknown)) ==="
    case "${PLATFORM}" in
      linux-rhel)
        if command -v systemctl &>/dev/null && ! systemctl is-active --quiet docker 2>/dev/null; then
          echo "Starting Docker service (sudo required)..."
          sudo systemctl enable --now docker
        fi
        if ! id -nG "${USER}" | grep -qw docker; then
          echo "Adding ${USER} to the docker group (sudo required)..."
          sudo usermod -aG docker "${USER}" || true
          echo "You may need to log out and back in for group membership to apply."
        fi
        ;;
      linux-wsl)
        if command -v systemctl &>/dev/null && ! systemctl is-active --quiet docker 2>/dev/null; then
          echo "Starting Docker service in WSL (sudo required)..."
          sudo systemctl enable --now docker
        fi
        if ! id -nG "${USER}" | grep -qw docker; then
          echo "Adding ${USER} to the docker group (sudo required)..."
          sudo usermod -aG docker "${USER}" || true
          echo "Restart WSL (wsl --shutdown) or run: newgrp docker"
        fi
        ;;
      darwin)
        echo "Using Docker Desktop — ensure it is running before continuing."
        ;;
      linux)
        echo "Ensure the Docker daemon is running on this host."
        ;;
    esac
    return 0
  fi

  case "${PLATFORM}" in
    linux-rhel)
      echo "=== Installing Docker (RHEL/CentOS) — sudo required ==="
      sudo yum remove -y docker docker-client docker-client-latest docker-common \
        docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
      sudo yum install -y yum-utils device-mapper-persistent-data lvm2
      sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl enable --now docker
      sudo usermod -aG docker "${USER}" || true
      ;;
    linux-wsl)
      echo "ERROR: Docker CLI not found inside WSL."
      echo "  Install Docker Engine in WSL (docker-ce) — see ${SCRIPT_DIR}/docs/windows.md"
      exit 1
      ;;
    darwin)
      echo "ERROR: Docker not found. Install Docker Desktop for Mac."
      echo "  Guide: ${SCRIPT_DIR}/docs/macos.md"
      exit 1
      ;;
    *)
      echo "ERROR: Docker is not installed. Install Docker for your OS, then re-run."
      exit 1
      ;;
  esac
}

ollama_has_model() {
  local name="$1"
  command -v ollama &>/dev/null || return 1
  ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -q "^${name}"
}

ensure_ollama_models() {
  local modelfile="${SCRIPT_DIR}/ollama/Modelfile"
  local -a base_models=( "llama3.1:8b" "nomic-embed-text:v1.5" "llama-guard3:8b" )

  if ! command -v ollama &>/dev/null; then
    echo "WARNING: ollama CLI not found; skipping model pull/create."
    if [[ "${PLATFORM}" == "linux-wsl" ]]; then
      echo "  Install Ollama inside WSL:  curl -fsSL https://ollama.com/install.sh | sh"
      echo "  Or see docs/windows.md if Ollama runs on Windows instead."
    fi
    return 0
  fi
  if ! curl -sf --max-time 3 http://127.0.0.1:11434/api/tags &>/dev/null; then
    return 0
  fi
  if [[ ! -f "${modelfile}" ]]; then
    echo "WARNING: missing ${modelfile}; cannot create kraus-cloud-llama."
    return 0
  fi

  echo "=== Ensuring Ollama models (chat uses kraus-cloud-llama) ==="
  for model in "${base_models[@]}"; do
    if ollama_has_model "${model}"; then
      echo "  ${model} — present"
    else
      echo "  Pulling ${model}..."
      ollama pull "${model}"
    fi
  done

  if ollama_has_model "kraus-cloud-llama"; then
    echo "  kraus-cloud-llama — present"
  else
    echo "  Creating kraus-cloud-llama from ollama/Modelfile..."
    ollama create kraus-cloud-llama -f "${modelfile}"
    echo "  kraus-cloud-llama — created"
  fi
}

install_docker_if_missing
ensure_docker_access

echo "=== Checking Ollama on host (required for embeddings / chat) ==="
if ! curl -sf --max-time 3 http://127.0.0.1:11434/api/tags &>/dev/null; then
  echo "WARNING: Ollama is not reachable at http://127.0.0.1:11434"
  case "${PLATFORM}" in
    linux-wsl)
      echo "  Install in WSL (recommended):  curl -fsSL https://ollama.com/install.sh | sh"
      echo "  Or install Ollama for Windows — see docs/windows.md"
      ;;
    darwin)
      echo "  Install: https://ollama.com/download/mac"
      ;;
    *)
      echo "  Install: curl -fsSL https://ollama.com/install.sh | sh"
      ;;
  esac
  echo "  Models:  ollama pull llama3.1:8b && ollama pull nomic-embed-text:v1.5"
else
  echo "Ollama is reachable at http://127.0.0.1:11434"
  BRIDGE_IP="$(docker_bridge_ip)"
  if check_ollama_for_docker "${BRIDGE_IP}"; then
    if uses_docker_desktop; then
      echo "Ollama is reachable from Docker (host.docker.internal)"
    else
      echo "Ollama is reachable from Docker at http://${BRIDGE_IP}:11434"
    fi
  else
    echo "WARNING: Ollama is NOT reachable from Docker containers."
    echo "  (Backend uses http://host.docker.internal:11434)"
    ollama_fix_hint
  fi
  ensure_ollama_models
fi

echo "=== Ensuring config files exist ==="
mkdir -p infra/nginx
if [[ ! -f backend.env ]]; then
  if [[ -f backend.env.example ]]; then
    cp backend.env.example backend.env
    echo "Created backend.env from backend.env.example — edit API keys and overrides before relying on them."
  else
    echo "WARNING: missing backend.env and backend.env.example — create backend.env for API keys (see README)."
  fi
fi
if [[ ! -f infra/nginx/nginx.conf ]]; then
  echo "ERROR: missing infra/nginx/nginx.conf — restore from the repo and re-run."
  exit 1
fi
if [[ ! -f docker-compose.yml ]]; then
  echo "ERROR: missing docker-compose.yml — restore from the repo and re-run."
  exit 1
fi
if [[ ! -f data/dmvData.json ]]; then
  echo "WARNING: missing data/dmvData.json — ingestion may fail."
fi

echo "=== Pulling images ==="
compose pull

echo "=== Starting stack ==="
compose up -d

BRIDGE_IP="$(docker_bridge_ip)"
if curl -sf --max-time 3 http://127.0.0.1:11434/api/tags &>/dev/null \
  && ! check_ollama_for_docker "${BRIDGE_IP}"; then
  echo ""
  echo "ERROR: Ollama is up on localhost but not reachable from Docker."
  echo "  Chat and ingestion will fail until Ollama is exposed to containers."
  ollama_fix_hint
  echo ""
fi

echo "=== Waiting for Chroma ==="
for i in {1..30}; do
  if curl -sf --max-time 2 http://127.0.0.1:9001/api/v1/heartbeat &>/dev/null \
    || curl -sf --max-time 2 http://127.0.0.1:9001/api/v2/heartbeat &>/dev/null; then
    echo "Chroma is up."
    break
  fi
  if [[ "$i" -eq 30 ]]; then
    echo "WARNING: Chroma heartbeat not confirmed on :9001; continuing anyway."
  fi
  sleep 2
done

echo "=== Running ingestion ==="
if compose --profile ingest run --rm ingest; then
  echo "Ingestion finished."
else
  echo "WARNING: Ingestion failed (stack may still run; check: docker compose logs)"
fi

echo ""
echo "=== Deployment complete ==="
echo "  App (via nginx):  http://localhost/"
echo "  Backend direct:   http://localhost:8000"
echo "  Chroma UI port:   http://localhost:9001"
echo "  Log file:         ${LOG_FILE}"
echo ""

if [[ -t 0 && -t 1 ]]; then
  read -r -p "Press Enter to close this window..."
fi
