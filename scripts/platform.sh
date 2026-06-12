#!/usr/bin/env bash
# Shared platform detection and helpers (source from bootstrap / configure scripts).
# shellcheck shell=bash

platform_name() {
  local p
  case "$(uname -s)" in
    Linux)
      if is_wsl; then
        p="linux-wsl"
      elif is_rhel_like; then
        p="linux-rhel"
      else
        p="linux"
      fi
      ;;
    Darwin) p="darwin" ;;
    *) p="unknown" ;;
  esac
  # Strip CR from Windows checkouts (avoids linux-wsl^M breaking case matches).
  echo "${p//$'\r'/}"
}

is_wsl() {
  grep -qiE '(microsoft|WSL)' /proc/version 2>/dev/null \
    || [[ -n "${WSL_DISTRO_NAME:-}" ]]
}

is_rhel_like() {
  [[ -f /etc/redhat-release ]] \
    || { [[ -f /etc/os-release ]] \
      && grep -qiE '^(ID|ID_LIKE)=.*(rhel|centos|fedora|rocky|alma|ol)' /etc/os-release; }
}

uses_docker_desktop() {
  [[ "$(platform_name)" == "darwin" ]]
}

# Container Ollama on Linux (WSL/RHEL/native); host Ollama on macOS for Apple GPU performance.
# Optional arg: precomputed platform (bootstrap passes sanitized PLATFORM).
uses_container_ollama() {
  local p="${1:-$(platform_name)}"
  p="${p//$'\r'/}"
  case "$p" in
    linux-wsl|linux-rhel|linux) return 0 ;;
    *) return 1 ;;
  esac
}

docker_bridge_ip() {
  if ip -4 addr show docker0 &>/dev/null 2>&1; then
    ip -4 addr show docker0 | awk '/inet / {print $2}' | cut -d/ -f1 | head -1
    return 0
  fi
  echo "172.17.0.1"
}

# True if containers can reach Ollama (bridge IP on native Linux, host.docker.internal via host-gateway).
check_ollama_for_docker() {
  local bridge_ip="${1:-$(docker_bridge_ip)}"

  if curl -sf --max-time 3 "http://${bridge_ip}:11434/api/tags" &>/dev/null; then
    return 0
  fi

  if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:8.5.0 \
      -sf --max-time 8 "http://host.docker.internal:11434/api/tags" &>/dev/null
    return $?
  fi

  return 1
}

ollama_fix_hint() {
  local p
  p="$(platform_name)"
  case "$p" in
    linux-rhel|linux|linux-wsl)
      echo "  Bootstrap runs Ollama in Docker on Linux — check:  docker compose -f docker-compose.yml -f docker-compose.linux.yml ps ollama"
      echo "  Logs:  docker compose -f docker-compose.yml -f docker-compose.linux.yml logs ollama"
      echo "  For host Ollama instead, skip docker-compose.linux.yml and use configure-ollama-for-docker.sh"
      ;;
    darwin)
      echo "  On macOS, host.docker.internal usually works if Ollama is running."
      echo "  Ensure Ollama.app is started; see docs/macos.md"
      ;;
    *)
      echo "  See docs/ for your OS."
      ;;
  esac
}
