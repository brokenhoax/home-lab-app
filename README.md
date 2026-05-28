# Home Lab App — Deployment Guide

This project runs:

- Frontend (Next.js)
- Backend (Node.js)
- ChromaDB (vector database)
- NGINX reverse proxy
- Ingestion job

**Ollama does not run in Docker.** It runs on the host (or in WSL on Windows) because the Ollama image is not compatible with all CPUs.

---

## Prerequisites (before bootstrap)

Install everything in your OS guide **before** running bootstrap. Summary:

| Prerequisite | RHEL / Linux | Windows (WSL) | macOS |
|--------------|:------------:|:-------------:|:-----:|
| **Docker** | Installed by `./bootstrap.sh` (Docker CE) | Docker Engine in WSL — see [windows.md](docs/windows.md) | [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) — **required** |
| **Ollama** | You install ([linux-rhel.md](docs/linux-rhel.md)) | You install in WSL (recommended) or on Windows — [windows.md](docs/windows.md) | You install ([macos.md](docs/macos.md)) |
| **WSL 2 + Ubuntu** | — | Required | — |
| **bash, curl, git** | Included / `yum` | In WSL distro | Included |
| **Ports 80, 8000, 9001** | Free on host | Free (forwarded via Docker) | Free on host |
| **sudo** (first Docker install on Linux) | Yes | For Ollama systemd config in WSL | — |

### Why Docker Desktop on macOS, but not on RHEL?

Docker runs **Linux containers**, which need a Linux kernel (namespaces, cgroups, etc.).

| Platform | Host OS | How Docker gets a Linux kernel |
|----------|---------|--------------------------------|
| **RHEL / Rocky / Alma** | Linux | Native — `bootstrap.sh` installs **Docker Engine** (`dockerd` on the host). No Desktop product. |
| **Windows + WSL** | Windows | Your **WSL 2 distro is real Linux**. Install **Docker Engine inside WSL** (like RHEL). Docker Desktop is optional, not required. |
| **macOS** | Darwin (not Linux) | **No Linux kernel on the Mac.** Docker Desktop runs a hidden Linux VM and exposes `docker` to macOS. Alternatives (Colima, Lima) do the same class of thing; this project documents Docker Desktop. |

So: **macOS is not Linux** (Docker Desktop required). **RHEL is Linux** (Docker Engine on the host). **Windows + WSL** is Linux *inside the distro* — install Docker Engine there; no Desktop product needed. macOS has no equivalent native Linux environment.

---

## Choose your platform

| Platform | Guide | Bootstrap |
|----------|--------|-----------|
| **Linux (RHEL / CentOS / Rocky / Alma)** | [docs/linux-rhel.md](docs/linux-rhel.md) | `./bootstrap.sh` |
| **Windows 11 + WSL 2** | [docs/windows.md](docs/windows.md) | `.\bootstrap.ps1` or `./bootstrap.sh` in WSL |
| **macOS** | [docs/macos.md](docs/macos.md) | `./bootstrap.sh` |

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

**Publish images** (from a machine with Docker + `docker login`): `./scripts/publish-images.sh` — builds from sibling `blog` and `blog-backend` repos by default.

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
| `permission denied` on `docker.sock` | RHEL / WSL: add user to `docker` group — see your OS guide; macOS uses Docker Desktop |
