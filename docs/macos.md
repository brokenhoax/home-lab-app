# Home Lab App

Thanks for checking out the Home Lab App!

Before proceeding, please ensure you have read the main "README.md" file in this repository as there are some critical prerequisites that must be completed before Home Lab App will function correctly. Once those prerequisites are met, the following instructions will help you through deploying the Home Lab App in a few simple commands.

Let's get started!

```
🍎 This particular set of instructions is for macOS environments.
```

## macOS — Docker Desktop required

Run `./bootstrap.sh` in **Terminal** (bash). **Docker Desktop is mandatory on macOS** — there is no supported path to install Docker Engine directly on Darwin.

### Why Docker Desktop on Mac but not on RHEL?

macOS is **not Linux**. Containers need a Linux kernel; Docker Desktop runs a small Linux VM (via Apple’s hypervisor) and exposes `docker` / `docker compose` to your Mac. On RHEL, Docker Engine runs natively on the host kernel. On Windows, WSL 2 gives you a real Linux environment where Engine can run without the Desktop app; macOS has no equivalent.

## Prerequisites (install before `./bootstrap.sh`)

| Item                                                                          | Required?  | Notes                                                                                         |
| ----------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------- |
| macOS 12+ (Apple Silicon or Intel)                                            | Yes        |                                                                                               |
| **[Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)** | **Yes**    | Install, open, wait until status is **Running** — bootstrap will fail without it              |
| **[Ollama for Mac](https://ollama.com/download/mac)**                         | **Yes**    | **Host only** — not in Docker (Apple GPU unavailable in containers); API on `127.0.0.1:11434` |
| bash, curl                                                                    | Yes        | Included with macOS                                                                           |
| Ports **80**, **8000**, **9001**                                              | Yes        | Free on localhost                                                                             |
| `configure-ollama-for-docker.sh`                                              | Usually no | `host.docker.internal` works with Desktop                                                     |
| Docker Hub login                                                              | No         | Public images                                                                                 |

**Checklist:** install Docker Desktop → install **native** Ollama (not the Docker image) → start both → `./bootstrap.sh`.

On macOS, Ollama stays on the **host** so Apple Silicon can use the GPU. Linux/WSL use a container instead — see [windows.md](windows.md) and [linux-rhel.md](linux-rhel.md).

## Quick start

```bash
git clone <repo-url> ~/home-lab-app
cd ~/home-lab-app
chmod +x bootstrap.sh
./bootstrap.sh
```

Install Docker Desktop and Ollama **before** bootstrap if possible. Start Docker Desktop until it reports **Running**.

After a successful bootstrap on any platform:

- App: [http://localhost/](http://localhost/)
- Backend: [http://localhost:8000](http://localhost:8000)
- Chroma (host port): [http://localhost:9001](http://localhost:9001)

Logs: `bootstrap.log` in the repo root.

## Install Ollama

Download from [https://ollama.com/download/mac](https://ollama.com/download/mac) or:

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

### Verify

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

| Symptom                             | Fix                                                                                  |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| `Docker not found`                  | Install and start Docker Desktop                                                     |
| `Cannot reach Docker`               | Wait for Docker Desktop to finish starting                                           |
| Ollama warnings but app works       | Bridge-IP checks are Linux-oriented; trust `host.docker.internal` if ingest succeeds |
| Ingestion / chat errors             | Start Ollama.app; ensure models exist (`ollama list`)                                |
| Chat **504 Gateway Timeout**        | `docker compose restart nginx`                                                       |
| Permission denied on `bootstrap.sh` | `chmod +x bootstrap.sh`                                                              |
