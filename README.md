# Home Lab App — Deployment Guide

This project runs:

- Frontend (Next.js)
- Backend (Node.js)
- ChromaDB (vector database)
- NGINX reverse proxy
- Ingestion job

**Ollama does NOT run in Docker.**  
It runs natively on the host because the Docker image is not compatible with all CPUs.

---

## Quick start (production stack)

Open a terminal (do not double-click the script — the window will close on exit):

```bash
cd ~/Documents/dev/home-lab-app
./bootstrap.sh
```

If anything fails, read `bootstrap.log` in the same directory.

### Public Docker images vs. the `docker` group

These are unrelated:

| | What it controls |
|---|------------------|
| **Public images on Docker Hub** (`brokenhoax/lab-app-*`) | Anyone can **download** your app images without a registry login. No change to your repo or image visibility is required. |
| **Local `docker` group on each machine** | Who on **that Linux box** may **start/stop** containers by talking to the Docker daemon (`/var/run/docker.sock`). |

Publishing images does not grant permission to run Docker on someone’s laptop or VM. Every teammate still needs Docker installed on their host and permission to use it—same as on your machine.

**Why Linux uses a group:** Docker is equivalent to root on the host. By default only `root` may use the socket; distros add a `docker` group so trusted users can run containers without typing `sudo` every time. This is standard Docker-on-Linux behavior, not something specific to your project.

**What `bootstrap.sh` does for any username:** It uses `$USER` (whoever ran the script—`brokenhoax`, `alice`, etc.). It does not hardcode your name. For each person it will:

1. Install Docker if missing (one `sudo` password prompt on RHEL).
2. Run `sudo usermod -aG docker "$USER"` so **that** account is in the group.
3. Re-run the script under `sg docker` so it works in the same terminal without logging out.
4. Fall back to `sudo docker compose` if group access is not available yet.

**Teammate checklist:** Git clone → `cd` into repo → `./bootstrap.sh` → enter sudo password if asked → install Ollama (below). No Docker Hub account required for public images.

**Common fixes:**

| Symptom | Fix |
|--------|-----|
| Terminal closes immediately | Run from an existing terminal with the commands above |
| `sudo: a password is required` during Docker install | Docker is already installed; the updated script skips reinstall |
| `permission denied` on `docker.sock` | `sudo usermod -aG docker $USER`, then log out and back in (or run `newgrp docker`) |
| Ingestion / chat errors | Ollama reachable from Docker (below); `kraus-cloud-llama` must exist (`ollama list`) |
| Chat **504 Gateway Timeout** | Nginx timed out before the backend responded; restart nginx after pull (`docker compose restart nginx`). First reply on a miniserver can take several minutes. |

After a successful run:

- App: http://localhost/
- Backend: http://localhost:8000
- Chroma (host port): http://localhost:9001

---

## 1. Install Ollama on the host

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

## 2. Ollama models (bootstrap does this automatically)

`./bootstrap.sh` pulls base models and builds the custom chat model from `ollama/Modelfile`:

| Model | Purpose |
|-------|---------|
| `llama3.1:8b` | Base for `kraus-cloud-llama` |
| `nomic-embed-text:v1.5` | Embeddings / RAG |
| `llama-guard3:8b` | Safety filter |
| `kraus-cloud-llama` | Chat (created via `ollama create` from Modelfile) |

Manual equivalent:

```bash
ollama pull llama3.1:8b
ollama pull nomic-embed-text:v1.5
ollama pull llama-guard3:8b
ollama create kraus-cloud-llama -f ollama/Modelfile
```

## 3. Verify your work

```bash
ollama list
ollama ps
```

You should see `kraus-cloud-llama` in `ollama list`.

## 4. Expose Ollama to Docker (Linux only — required for chat / ingestion)

The backend runs in Docker and talks to Ollama at `http://host.docker.internal:11434` (the host gateway, usually `172.17.0.1`). Ollama’s default bind is **127.0.0.1 only**, so the stack works on Mac but chat fails on RHEL until you widen the listen address.

**`/etc/ollama/config.yaml` does not set the listen address** on current Ollama builds. Use systemd instead:

```bash
cd ~/Documents/dev/home-lab-app
sudo ./scripts/configure-ollama-for-docker.sh
```

Or manually:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '%s\n' '[Service]' 'Environment="OLLAMA_HOST=0.0.0.0:11434"' | sudo tee /etc/systemd/system/ollama.service.d/environment.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify (both should succeed):

```bash
curl -s http://127.0.0.1:11434/api/tags
curl -s http://172.17.0.1:11434/api/tags
```

Then re-run `./bootstrap.sh` if ingestion failed earlier.
