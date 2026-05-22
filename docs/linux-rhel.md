# Linux (RHEL / CentOS / Rocky / Alma)

Native Linux deployment with optional Docker CE install via `bootstrap.sh`.

## Requirements

- RHEL 8+, CentOS Stream, Rocky, Alma, or compatible (`yum` / `dnf`)
- `sudo` for first-time Docker install and `docker` group
- curl, bash
- Ports **80**, **8000**, **9001** available

## Quick start

```bash
git clone <repo-url> ~/home-lab-app
cd ~/home-lab-app
./bootstrap.sh
```

Read `bootstrap.log` if anything fails.

## What `bootstrap.sh` does

Uses `$USER` (not a hardcoded account). For RHEL-like hosts it will:

1. Install Docker CE via `yum` if the `docker` CLI is missing (one `sudo` password prompt).
2. Start and enable the `docker` systemd unit.
3. Run `sudo usermod -aG docker "$USER"` when needed.
4. Re-run under `sg docker` so the same terminal works without logging out.
5. Fall back to `sudo docker compose` if group access is not ready yet.
6. Pull Ollama models when the CLI and daemon are available.
7. `docker compose pull`, `up -d`, and run the ingest profile.

**Teammate checklist:** clone → `cd` → `./bootstrap.sh` → sudo if asked → install Ollama (below). No Docker Hub login required for public images.

## Public images vs. the `docker` group

| | What it controls |
|---|------------------|
| **Public images** (`brokenhoax/lab-app-*`) | Who can **download** images from Docker Hub |
| **Local `docker` group** | Who on **this machine** may use `/var/run/docker.sock` |

Publishing images does not grant Docker permission on someone else's host.

## Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Models are pulled automatically by `./bootstrap.sh`, or manually:

```bash
ollama pull llama3.1:8b
ollama pull nomic-embed-text:v1.5
ollama pull llama-guard3:8b
ollama create kraus-cloud-llama -f ollama/Modelfile
```

Verify:

```bash
ollama list
ollama ps
```

## Expose Ollama to Docker (required for chat / ingestion)

Containers call `http://host.docker.internal:11434` (mapped to the host gateway, often `172.17.0.1`). Ollama’s default bind is **127.0.0.1 only**, so chat/ingest fail until the listen address is widened.

`/etc/ollama/config.yaml` does **not** set the listen address on current Ollama builds. Use systemd:

```bash
cd ~/home-lab-app
sudo ./scripts/configure-ollama-for-docker.sh
```

Or manually:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '%s\n' '[Service]' 'Environment="OLLAMA_HOST=0.0.0.0:11434"' | sudo tee /etc/systemd/system/ollama.service.d/environment.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify:

```bash
curl -s http://127.0.0.1:11434/api/tags
curl -s http://172.17.0.1:11434/api/tags
```

Then re-run `./bootstrap.sh` if ingestion failed earlier.

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `sudo: a password is required` during Docker install | Docker already installed; script skips reinstall |
| `permission denied` on `docker.sock` | `sudo usermod -aG docker $USER`, log out/in or `newgrp docker` |
| Ingestion / chat errors | Ollama exposed to Docker (above); `kraus-cloud-llama` in `ollama list` |
| Chat **504 Gateway Timeout** | `docker compose restart nginx` |
