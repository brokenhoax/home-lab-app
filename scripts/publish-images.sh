#!/usr/bin/env bash
# Build and push multi-arch lab-app images to Docker Hub (brokenhoax/lab-app-*:latest).
# Requires: docker login, buildx, repos at ../blog and ../blog-backend (or FRONTEND_DIR / BACKEND_DIR).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${FRONTEND_DIR:-$(cd "${REPO_ROOT}/../blog" 2>/dev/null && pwd || true)}"
BACKEND_DIR="${BACKEND_DIR:-$(cd "${REPO_ROOT}/../blog-backend" 2>/dev/null && pwd || true)}"

FRONTEND_IMAGE="${FRONTEND_IMAGE:-brokenhoax/lab-app-frontend:latest}"
BACKEND_IMAGE="${BACKEND_IMAGE:-brokenhoax/lab-app-backend:latest}"
NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-http://localhost}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER="${BUILDER:-lab-app-multiarch}"

if [[ -z "${FRONTEND_DIR}" || ! -f "${FRONTEND_DIR}/Dockerfile" ]]; then
  echo "ERROR: Set FRONTEND_DIR to the blog (frontend) repo with a Dockerfile."
  exit 1
fi
if [[ -z "${BACKEND_DIR}" || ! -f "${BACKEND_DIR}/Dockerfile" ]]; then
  echo "ERROR: Set BACKEND_DIR to the blog-backend repo with a Dockerfile."
  exit 1
fi

ensure_buildx() {
  if ! docker buildx version &>/dev/null; then
    echo "ERROR: docker buildx is required. Install the Docker Buildx plugin and re-run."
    exit 1
  fi

  if docker buildx inspect "${BUILDER}" &>/dev/null; then
    docker buildx use "${BUILDER}"
  else
    echo "Creating buildx builder '${BUILDER}' (docker-container driver for multi-arch)..."
    docker buildx create --name "${BUILDER}" --driver docker-container --use
  fi

  docker buildx inspect --bootstrap >/dev/null
}

build_and_push() {
  local image="$1"
  local context="$2"
  shift 2

  echo "=== Building and pushing ${image} (${PLATFORMS}) ==="
  docker buildx build \
    --platform "${PLATFORMS}" \
    --tag "${image}" \
    --push \
    --provenance=false \
    --sbom=false \
    "$@" \
    "${context}"
}

ensure_buildx

build_and_push "${FRONTEND_IMAGE}" "${FRONTEND_DIR}" \
  --build-arg "NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}"

build_and_push "${BACKEND_IMAGE}" "${BACKEND_DIR}"

echo "Done: ${FRONTEND_IMAGE} ${BACKEND_IMAGE} (${PLATFORMS})"
