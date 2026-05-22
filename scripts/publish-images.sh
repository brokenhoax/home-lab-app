#!/usr/bin/env bash
# Build and push lab-app images to Docker Hub (brokenhoax/lab-app-*:latest).
# Requires: docker login, repos at ../blog and ../blog-backend (or set FRONTEND_DIR / BACKEND_DIR).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${FRONTEND_DIR:-$(cd "${REPO_ROOT}/../blog" 2>/dev/null && pwd || true)}"
BACKEND_DIR="${BACKEND_DIR:-$(cd "${REPO_ROOT}/../blog-backend" 2>/dev/null && pwd || true)}"

FRONTEND_IMAGE="${FRONTEND_IMAGE:-brokenhoax/lab-app-frontend:latest}"
BACKEND_IMAGE="${BACKEND_IMAGE:-brokenhoax/lab-app-backend:latest}"
NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-http://localhost}"

if [[ -z "${FRONTEND_DIR}" || ! -f "${FRONTEND_DIR}/Dockerfile" ]]; then
  echo "ERROR: Set FRONTEND_DIR to the blog (frontend) repo with a Dockerfile."
  exit 1
fi
if [[ -z "${BACKEND_DIR}" || ! -f "${BACKEND_DIR}/Dockerfile" ]]; then
  echo "ERROR: Set BACKEND_DIR to the blog-backend repo with a Dockerfile."
  exit 1
fi

echo "=== Building ${FRONTEND_IMAGE} ==="
docker build -t "${FRONTEND_IMAGE}" \
  --build-arg "NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}" \
  "${FRONTEND_DIR}"

echo "=== Building ${BACKEND_IMAGE} ==="
docker build -t "${BACKEND_IMAGE}" "${BACKEND_DIR}"

echo "=== Pushing images ==="
docker push "${FRONTEND_IMAGE}"
docker push "${BACKEND_IMAGE}"

echo "Done: ${FRONTEND_IMAGE} ${BACKEND_IMAGE}"
