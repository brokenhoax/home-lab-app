# macOS — Docker Desktop

Run `./bootstrap.sh` in **Terminal** (bash). Docker Desktop provides the engine; Ollama runs natively on the Mac.

## Requirements

- macOS 12+ (Apple Silicon or Intel)
- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
- [Ollama for Mac](https://ollama.com/download/mac)
- bash, curl (included with macOS)
- Ports **80**, **8000**, **9001** free

## Quick start

```bash
git clone <repo-url> ~/home-lab-app
cd ~/home-lab-app
chmod +x bootstrap.sh
./bootstrap.sh
```

Install Docker Desktop and Ollama **before** bootstrap if possible. Start Docker Desktop until it reports **Running**.

Logs: `bootstrap.log` in the repo root.

## Install Ollama

Download from https://ollama.com/download/mac or:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Open the Ollama app (menu bar) so the API is listening on `127.0.0.1:11434`.

`bootstrap.sh` pulls models and creates `kraus-cloud-llama` when the CLI is available.

Manual equivalent:

```bash
ollama pull llama3.1:8b
ollama pull nomic-embed-text:v1.5
ollama pull llama-guard3:8b
ollama create kraus-cloud-llama -f ollama/Modelfile
```

Verify:

```bash
ollama list
```

## Ollama and Docker networking

The backend uses `http://host.docker.internal:11434` (`extra_hosts: host-gateway` in `docker-compose.yml`). On macOS, Docker Desktop usually resolves this to the host without extra configuration.

Bootstrap verifies reachability with a one-off container curl to `host.docker.internal` when the Linux bridge IP check fails.

If chat or ingestion still fail:

1. Confirm Ollama is running (`ollama list` works).
2. Restart Docker Desktop.
3. Re-run `./bootstrap.sh`.

You typically **do not** need the Linux `configure-ollama-for-docker.sh` script on macOS.

## What `bootstrap.sh` does on macOS

- Does **not** install Docker via `yum` or manage a `docker` group.
- Expects `docker` / `docker compose` from Docker Desktop.
- Skips RHEL-specific `systemctl` / `usermod` paths.
- Uses Docker Desktop–aware Ollama connectivity checks.

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `Docker not found` | Install and start Docker Desktop |
| `Cannot reach Docker` | Wait for Docker Desktop to finish starting |
| Ollama warnings but app works | Bridge-IP checks are Linux-oriented; trust `host.docker.internal` if ingest succeeds |
| Ingestion / chat errors | Start Ollama.app; ensure models exist (`ollama list`) |
| Chat **504 Gateway Timeout** | `docker compose restart nginx` |
| Permission denied on `bootstrap.sh` | `chmod +x bootstrap.sh` |

## URLs after deploy

- App: http://localhost/
- Backend: http://localhost:8000
- Chroma: http://localhost:9001
