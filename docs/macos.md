# Home Lab App

Thanks for checking out the Home Lab App!

Before proceeding, please ensure you have read the main "README.md" file in this repository as there are some critical prerequisites that must be completed before Home Lab App will function correctly. Once those prerequisites are met, the following instructions will help you through deploying the Home Lab App in a few simple commands.

Let's get started!

```
🍎 This particular set of instructions is for macOS environments.
```

## Prerequisites

| Item                                                                          | Required? | Notes                                                                                         |
| ----------------------------------------------------------------------------- | --------- | --------------------------------------------------------------------------------------------- |
| macOS 12+ (Apple Silicon or Intel)                                            | Yes       |                                                                                               |
| **[Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)** | **Yes**   | Install, open, wait until status is **Running** — bootstrap will fail without it              |
| **[Ollama for Mac](https://ollama.com/download/mac)**                         | **Yes**   | **Host only** — not in Docker (Apple GPU unavailable in containers); API on `127.0.0.1:11434` |
| Ports **80**, **8000**, **9001**                                              | Yes       | Free on localhost                                                                             |

---

## Step 1 — Install Docker Desktop for macOS

macOS is **not Linux**. Containers need a Linux kernel. Docker Desktop runs a small Linux VM (via Apple’s hypervisor) and exposes `docker` / `docker compose` to your Mac. On RHEL, Docker Engine runs natively on the host kernel. On Windows, WSL 2 gives you a real Linux environment where Engine can run without the Desktop app. macOS has no equivalent.

Therefore, you'll need to install Docker Desktop for macOS before installing the Home Lab App:

[https://docs.docker.com/desktop/setup/install/mac-install/](https://docs.docker.com/desktop/setup/install/mac-install/)

Once installed, start Docker Desktop until it reports **Running**.

## Step 2 — Install Ollama

On macOS, Ollama stays on the **host** so Apple Silicon can use the GPU.

Linux/WSL use a container instead — see [windows.md](windows.md) and [linux-rhel.md](linux-rhel.md).

So, you'll need to download Ollama from [https://ollama.com/download/mac](https://ollama.com/download/mac) or:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Next, open the Ollama app (menu bar) so the API is listening on `127.0.0.1:11434`.

`bootstrap.sh` pulls models and creates `kraus-cloud-llama` when the CLI is available. You shouldn't have to execute these steps manually, but if you're curious then here's the manual equivalent:

```bash
ollama pull llama3.1:8b
ollama pull nomic-embed-text:v1.5
ollama pull llama-guard3:8b
ollama create kraus-cloud-llama -f ollama/Modelfile
```

To list all Ollama models donwloaded, you can run the following command:

```bash
ollama list
```

## Step 3 — Run Ollama and Docker Desktop

Once installed, ensure both Ollama and Docker Desktop are running.

As a reminder, we need Ollama to run outside of Docker so that it can leverage your Mac's GPU. As for Docker Desktop, Docker requires a **Linux kernel** (specifically features like namespaces and cgroups) to function. Because macOS runs on its own Darwin kernel, it cannot run Linux containers natively.

Both Docker Desktop and Ollama should be visibile in your system tray (i.e., menu bar on Mac) if they are running, but if you're not sure or you prefer using the command line then you can use the following command to verify that Ollama is running:

```
curl http://localhost:11434/api/tags
```

And you can use the following command to verify that Docker Desktop is running:

```
docker info
```

## Step 4 — Bootstrap the Home Lab App

```bash
cd ~/Documents/dev
git clone https://github.com/brokenhoax/home-lab-app.git ~/home-lab-app
cd ~/home-lab-app
chmod +x bootstrap.sh
./bootstrap.sh
```

After a successful bootstrap on any platform:

- App: [http://localhost/](http://localhost/)
- Backend: [http://localhost:8000](http://localhost:8000)
- Chroma (host port): [http://localhost:9001](http://localhost:9001)

Logs: `bootstrap.log` in the repo root.

---

## Miscellaneous

### Ollama and Docker Networking

The backend uses `http://host.docker.internal:11434` (`extra_hosts: host-gateway` in `docker-compose.yml`). On macOS, Docker Desktop usually resolves this to the host without extra configuration.

Bootstrap verifies reachability with a one-off container curl to `host.docker.internal` when the Linux bridge IP check fails.

If chat or ingestion still fail:

1. Confirm Ollama is running (`ollama list` works).
2. Restart Docker Desktop.
3. Re-run `./bootstrap.sh`.

You typically **do not** need the Linux `configure-ollama-for-docker.sh` script on macOS.

### Troubleshooting

| Symptom                             | Fix                                                                                  |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| `Docker not found`                  | Install and start Docker Desktop                                                     |
| `Cannot reach Docker`               | Wait for Docker Desktop to finish starting                                           |
| Ollama warnings but app works       | Bridge-IP checks are Linux-oriented; trust `host.docker.internal` if ingest succeeds |
| Ingestion / chat errors             | Start Ollama.app; ensure models exist (`ollama list`)                                |
| Chat **504 Gateway Timeout**        | `docker compose restart nginx`                                                       |
| Permission denied on `bootstrap.sh` | `chmod +x bootstrap.sh`                                                              |
