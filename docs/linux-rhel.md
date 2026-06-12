# Home Lab App

Thanks for checking out the Home Lab App!

Before proceeding, please ensure you have read the main "README.md" file in this repository as there are some critical prerequisites that must be completed before Home Lab App will function correctly. Once those prerequisites are met, the following instructions will help you through deploying the Home Lab App in a few simple commands.

```
🐧This particular set of instructions is for Linux environments (RHEL, CENTOS, ROCK, Alma).
```

Let's get started!

## Requirements

- RHEL 8+, CentOS Stream, Rocky, Alma, or compatible (`yum` / `dnf`)
- `sudo` for first-time Docker install and `docker` group
- curl, bash
- Ports **80**, **8000**, **9001**, **11434** available
- Enough RAM/disk for Docker images plus Ollama models (~several GB for `llama3.1:8b`)

**Ollama runs in Docker** on Linux — bootstrap pulls models automatically. No separate Ollama install or host networking setup.

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
6. Start the **Ollama container** (`docker-compose.linux.yml`), pull models, and create `kraus-cloud-llama`.
7. `docker compose pull`, `up -d`, and run the ingest profile.

**Teammate checklist:** clone → `cd` → `./bootstrap.sh` → sudo if asked. No Docker Hub login required for public images.

## Ollama models

`bootstrap.sh` pulls these automatically into the Ollama container:

| Model                   | Purpose                        |
| ----------------------- | ------------------------------ |
| `llama3.1:8b`           | Base for `kraus-cloud-llama`   |
| `nomic-embed-text:v1.5` | Embeddings / RAG               |
| `llama-guard3:8b`       | Safety filter                  |
| `kraus-cloud-llama`     | Chat (from `ollama/Modelfile`) |

After a successful bootstrap on any platform:

- App: [http://localhost/](http://localhost/)
- Backend: [http://localhost:8000](http://localhost:8000)
- Chroma (host port): [http://localhost:9001](http://localhost:9001)

Logs: `bootstrap.log` in the repo root.

## Verify

```bash
docker compose -f docker-compose.yml -f docker-compose.linux.yml exec ollama ollama list
```

Manual pull (if bootstrap was interrupted):

```bash
docker compose -f docker-compose.yml -f docker-compose.linux.yml exec ollama ollama pull llama3.1:8b
docker compose -f docker-compose.yml -f docker-compose.linux.yml exec ollama ollama create kraus-cloud-llama -f /ollama-config/Modelfile
```

## Troubleshooting

| Symptom                                              | Fix                                                                                                                          |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `sudo: a password is required` during Docker install | Docker already installed; script skips reinstall                                                                             |
| `permission denied` on `docker.sock`                 | `sudo usermod -aG docker $USER`, log out/in or `newgrp docker`                                                               |
| Ingestion / chat errors                              | `docker compose -f docker-compose.yml -f docker-compose.linux.yml logs ollama`; confirm `kraus-cloud-llama` in `ollama list` |
| Ollama container won't start                         | Check RAM; older CPUs may struggle with the `ollama/ollama` image — see README for host-Ollama fallback                      |
| Chat **504 Gateway Timeout**                         | `docker compose restart nginx`                                                                                               |

## Optional: host Ollama instead of container

If the Ollama container fails on your hardware, you can run Ollama on the host and use the base `docker-compose.yml` only (macOS-style):

```bash
curl -fsSL https://ollama.com/install.sh | sh
sudo ./scripts/configure-ollama-for-docker.sh
# Run compose without docker-compose.linux.yml and pull models with host ollama CLI
```
