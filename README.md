# Home Lab App — Deployment Guide

This project runs:

- Frontend (Next.js)
- Backend (Node.js)
- ChromaDB (vector database)
- NGINX reverse proxy
- Ingestion job

**Ollama does not run in Docker.** It runs on the host (or in WSL on Windows) because the Ollama image is not compatible with all CPUs.

---

## Choose your platform

| Platform | Guide | Bootstrap |
|----------|--------|-----------|
| **Linux (RHEL / CentOS / Rocky / Alma)** | [docs/linux-rhel.md](docs/linux-rhel.md) | `./bootstrap.sh` |
| **Windows 11 + WSL 2 + Docker Desktop** | [docs/windows.md](docs/windows.md) | `.\bootstrap.ps1` or `./bootstrap.sh` in WSL |
| **macOS + Docker Desktop** | [docs/macos.md](docs/macos.md) | `./bootstrap.sh` |

After a successful bootstrap on any platform:

- App: http://localhost/
- Backend: http://localhost:8000
- Chroma (host port): http://localhost:9001

Logs: `bootstrap.log` in the repo root.

---

## Stack overview

| Component | Where it runs |
|-----------|----------------|
| frontend, backend, chroma, nginx, ingest | Docker (`docker compose`) |
| Ollama (LLM + embeddings) | Host — same environment you use for `ollama` CLI (WSL on Windows) |

Public images on Docker Hub (`brokenhoax/lab-app-*`) only control **who can pull** images. Each machine still needs Docker installed and permission to run it locally.

---

## Ollama models (all platforms)

`bootstrap.sh` pulls base models and builds the custom chat model from `ollama/Modelfile`:

| Model | Purpose |
|-------|---------|
| `llama3.1:8b` | Base for `kraus-cloud-llama` |
| `nomic-embed-text:v1.5` | Embeddings / RAG |
| `llama-guard3:8b` | Safety filter |
| `kraus-cloud-llama` | Chat (from `ollama/Modelfile`) |

Verify: `ollama list` should include `kraus-cloud-llama`.

---

## Common issues (all platforms)

| Symptom | What to check |
|--------|----------------|
| Terminal closes immediately | Run from an existing terminal; do not double-click scripts |
| Ingestion / chat errors | Ollama reachable from containers — see your OS guide |
| Chat **504 Gateway Timeout** | `docker compose restart nginx`; first reply can take several minutes on slow hardware |
| `permission denied` on `docker.sock` | Linux RHEL guide (`docker` group); not applicable to Docker Desktop on Mac/Windows |
