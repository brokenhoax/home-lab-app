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

## Configuration (`backend.env`)

For the Docker stack deployed from this repo, **`backend.env` is the one file you edit** for secrets and environment-specific overrides. Bootstrap creates it from `backend.env.example` on first run if it is missing.

```bash
cp backend.env.example backend.env   # if you create it manually
# edit backend.env — then restart services:
docker compose up -d
```

| Variable | Required? | Typical home-lab value | When to change |
|----------|-----------|------------------------|----------------|
| `AI_GUARD_KEY` | No | empty (guard disabled) | Enable Zscaler AI Guard |
| `XAI_API_KEY` | No | empty | Use xAI as a chat provider |
| `DEV_ENV_IP_ADDR` | No | empty | Dev bind address (see `blog-backend`) |
| `PROD_ENV_IP_ADDR` | No | empty | Documented in backend templates; prod compose listens on all interfaces via `PORT` |
| `CERT_KEY_PATH` / `CERT_CERT_PATH` | No | empty | Host HTTPS outside the default compose/nginx setup |
| `CHROMA_URL` | No* | `http://chroma:8000` in compose | Custom Chroma host |
| `OLLAMA_HOST` | No* | `http://host.docker.internal:11434` in compose | Ollama on another machine |

\*Leave commented out in `backend.env` to use compose defaults. Values in `docker-compose.yml` `environment:` override `env_file` for the same key.

**Not in `backend.env`:**

| Setting | Where to configure |
|---------|-------------------|
| **Ollama listen address** (`0.0.0.0:11434` on the host) | OS guide — `configure-ollama-for-docker.sh` or `OLLAMA_HOST` on the Ollama *daemon* |
| **Frontend API URL** (`NEXT_PUBLIC_API_URL`) | `docker-compose.yml` → `frontend` service (change if users reach the app by hostname/IP other than `http://localhost`) |
| **Chat / embedding model names** | Hardcoded in `blog-backend` today; bootstrap pulls Ollama models listed in README |
| **CORS allowed origins** | `blog-backend/server.ts` (change if frontend is served from another origin) |

Developers working in the **`blog-backend` repo** directly use that repo’s `.env` / `.env.production.local` (see `blog-backend/.env.example`). The home-lab deploy path uses **`home-lab-app/backend.env`** only.

`docker-compose.dev.yml` also loads `./backend.env` for local dev stacks.

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
