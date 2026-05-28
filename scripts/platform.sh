#!/usr/bin/env bash
# Shared platform detection and helpers (source from bootstrap / configure scripts).
# shellcheck shell=bash

platform_name() {
  case "$(uname -s)" in
    Linux)
      if is_wsl; then
        echo "linux-wsl"
      elif is_rhel_like; then
        echo "linux-rhel"
      else
        echo "linux"
      fi
      ;;
    Darwin) echo "darwin" ;;
    *) echo "unknown" ;;
  esac
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
    linux-rhel|linux)
      echo "  Fix (Linux):  sudo ${SCRIPT_DIR:-.}/scripts/configure-ollama-for-docker.sh"
      echo "  Or:   sudo systemctl edit ollama.service  →  Environment=\"OLLAMA_HOST=0.0.0.0:11434\""
      ;;
    linux-wsl)
      echo "  Fix (Ollama in WSL):  sudo ${SCRIPT_DIR:-.}/scripts/configure-ollama-for-docker.sh"
      echo "  Fix (Ollama on Windows):  powershell -File ${SCRIPT_DIR:-.}/scripts/configure-ollama-windows.ps1"
      echo "  See:  docs/windows.md"
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
